"""Model backends: a scripted fake, the isolated `claude -p` CLI and the Anthropic API."""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path
from dataclasses import dataclass, field
from typing import Any, Callable, Protocol

from .models import Completion

DEFAULT_MAX_TOKENS = 2048


class Backend(Protocol):
    def complete(self, system: str, prompt: str, model: str,
                 timeout_s: float) -> Completion: ...

    def describe(self) -> dict[str, Any]: ...


class IsolationUnavailable(RuntimeError):
    """The installed CLI cannot guarantee the model sees no ambient context."""


@dataclass
class FakeBackend:
    """Deterministic backend for tests. `script` maps a request to text or a Completion."""

    script: Callable[[str, str, str], "str | Completion"]
    calls: list[dict[str, str]] = field(default_factory=list)

    def complete(self, system: str, prompt: str, model: str,
                 timeout_s: float = 0.0) -> Completion:
        self.calls.append({"system": system, "prompt": prompt, "model": model})
        reply = self.script(system, prompt, model)
        if isinstance(reply, Completion):
            return reply
        return Completion(text=reply, usage={"input_tokens": (len(system) + len(prompt)) // 4,
                                             "output_tokens": len(reply) // 4})

    def describe(self) -> dict[str, Any]:
        return {"backend": "fake"}


# Flags that, together, remove every ambient context source from `claude -p`.
# --safe-mode disables CLAUDE.md files, memory, skills, plugins, hooks and MCP servers, but
# measurably NOT the user settings file: its `language` setting still reached the model.
# An empty --setting-sources removes the user, project and local settings as well.
ISOLATION_FLAGS = ("--safe-mode", "--setting-sources", "--tools", "--strict-mcp-config",
                   "--system-prompt", "--disable-slash-commands", "--no-session-persistence")


class ClaudeCliBackend:
    """`claude -p` in an empty temporary directory with every customisation disabled."""

    def __init__(self, allow_ambient: bool = False,
                 runner: Callable[..., Any] = subprocess.run, executable: str = "claude",
                 workdir_files: dict[str, str] | None = None,
                 home_files: dict[str, str] | None = None):
        """`workdir_files` and `home_files` plant canary files for the isolation check only.

        Home files go into a throwaway HOME, so the real home is never touched.
        """
        self.workdir_files = workdir_files or {}
        self.home_files = home_files or {}
        self.allow_ambient = allow_ambient
        self._run = runner
        self.executable = executable
        self._flags: tuple[str, ...] | None = None

    def _supported(self) -> set[str]:
        result = self._run([self.executable, "--help"], capture_output=True, text=True,
                           timeout=60, check=False)
        return {flag for flag in ISOLATION_FLAGS if flag in (result.stdout or "")}

    def isolation_flags(self) -> tuple[str, ...]:
        """The isolation flags to pass; refuse if any is missing and ambient is not allowed."""
        if self._flags is None:
            supported = self._supported()
            missing = [flag for flag in ISOLATION_FLAGS if flag not in supported]
            if missing and not self.allow_ambient:
                raise IsolationUnavailable(
                    f"the installed claude CLI lacks {missing}; refusing to run with ambient "
                    "context. Pass --allow-ambient-context to accept CLAUDE.md, memory and "
                    "hooks leaking into the model under test.")
            self._flags = tuple(flag for flag in ISOLATION_FLAGS if flag in supported)
        return self._flags

    def build_command(self, system: str, model: str) -> list[str]:
        command = [self.executable, "-p", "--output-format", "json", "--model", model]
        flags = self.isolation_flags()
        if "--safe-mode" in flags:
            command.append("--safe-mode")
        for flag in ("--setting-sources", "--tools"):
            if flag in flags:
                command += [flag, ""]
        if "--strict-mcp-config" in flags:
            command.append("--strict-mcp-config")
        for flag in ("--disable-slash-commands", "--no-session-persistence"):
            if flag in flags:
                command.append(flag)
        if "--system-prompt" in flags:
            command += ["--system-prompt", system]
        return command

    def describe(self) -> dict[str, Any]:
        return {"backend": "claude-cli", "isolation": "safe-mode" if self._isolated() else "ambient",
                "allow_ambient": self.allow_ambient,
                "flags": [flag for flag in self.build_command("<surface>", "<model>")[1:]]}

    def _isolated(self) -> bool:
        return set(ISOLATION_FLAGS) <= set(self.isolation_flags())

    def complete(self, system: str, prompt: str, model: str, timeout_s: float) -> Completion:
        command = self.build_command(system, model)
        with tempfile.TemporaryDirectory(prefix="agent-evals-") as workdir, \
                tempfile.TemporaryDirectory(prefix="agent-evals-home-") as fake_home:
            _plant(Path(workdir), self.workdir_files)
            _plant(Path(fake_home), self.home_files)
            env = {**os.environ, "HOME": fake_home} if self.home_files else None
            try:
                result = self._run(command, input=prompt, capture_output=True, text=True,
                                   timeout=timeout_s, cwd=workdir, env=env, check=False)
            except subprocess.TimeoutExpired:
                return Completion(error="claude -p timed out", timed_out=True)
            except OSError as error:
                return Completion(error=f"cannot start claude: {error}")
        return parse_cli_output(result.returncode, result.stdout or "", result.stderr or "")


def _plant(root: Path, files: dict[str, str]) -> None:
    for name, content in files.items():
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")


def parse_cli_output(returncode: int, stdout: str, stderr: str) -> Completion:
    """Turn `claude -p --output-format json` output into a Completion."""
    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError:
        return Completion(error=f"claude exited {returncode} with unparseable output: "
                                f"{(stderr or stdout).strip()[:300]}")
    usage = dict(payload.get("usage") or {})
    if payload.get("total_cost_usd") is not None:
        usage["cost_usd"] = payload["total_cost_usd"]
    text = payload.get("result") or ""
    if payload.get("is_error") or returncode != 0:
        return Completion(text=text, error=text.strip()[:300] or f"claude exited {returncode}",
                          usage=usage)
    return Completion(text=text, usage=usage, truncated=payload.get("stop_reason") == "max_tokens")


class AnthropicApiBackend:
    """Optional backend over the anthropic SDK. The API key is read, never logged."""

    def __init__(self, max_tokens: int = DEFAULT_MAX_TOKENS, client: Any = None):
        if client is None:
            if not os.environ.get("ANTHROPIC_API_KEY"):
                raise RuntimeError("ANTHROPIC_API_KEY is not set")
            import anthropic  # deferred so the harness imports without the SDK
            client = anthropic.Anthropic()
        self.client = client
        self.max_tokens = max_tokens
        self._resolved: dict[str, str] = {}

    def resolve(self, alias: str) -> str:
        """Newest model id of a family alias, so no version is ever pinned in this repo."""
        if alias not in self._resolved:
            models = sorted(self.client.models.list(limit=100).data,
                            key=lambda item: item.created_at, reverse=True)
            match = next((item.id for item in models if alias in item.id), None)
            if match is None:
                raise RuntimeError(f"no model matching alias {alias!r}")
            self._resolved[alias] = match
        return self._resolved[alias]

    def describe(self) -> dict[str, Any]:
        return {"backend": "anthropic-api", "max_tokens": self.max_tokens}

    def complete(self, system: str, prompt: str, model: str, timeout_s: float) -> Completion:
        try:
            reply = self.client.messages.create(
                model=self.resolve(model), max_tokens=self.max_tokens, system=system,
                messages=[{"role": "user", "content": prompt}], timeout=timeout_s)
        except Exception as error:  # SDK raises several types; all are infrastructure errors
            kind = type(error).__name__
            return Completion(error=f"{kind}: {str(error)[:200]}",
                              timed_out="Timeout" in kind)
        text = "".join(block.text for block in reply.content if getattr(block, "type", "") == "text")
        usage = {"input_tokens": reply.usage.input_tokens, "output_tokens": reply.usage.output_tokens}
        return Completion(text=text, usage=usage, truncated=reply.stop_reason == "max_tokens")
