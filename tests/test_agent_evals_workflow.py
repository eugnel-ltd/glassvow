#!/usr/bin/env python3
"""Keep every agent-eval harness regression in its selected, isolated CI step."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import re
import shlex
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/ci.yml"


def workflow_problems(workflow: str, scripts: set[str]) -> list[str]:
    """Read the repository's explicit step shape without a YAML dependency."""
    steps = re.split(r"(?m)^      - name:", workflow)[1:]
    selected = [step for step in steps if re.search(
        r"(?m)^        if: steps\.scope\.outputs\.run_agent_evals == 'true'\s*$", step)]
    if len(selected) != 1:
        return ["expected one step guarded by run_agent_evals"]
    run = re.search(r"(?m)^        run: \|\n((?:^          .*\n|^\s*\n)*)", selected[0])
    if run is None:
        return ["agent-eval step requires explicit multiline commands"]
    commands = [shlex.split(line, comments=True) for line in run.group(1).splitlines()]
    commands = [command for command in commands if command]
    expected = Counter(("python3", "-B", script) for script in scripts)
    actual = Counter(tuple(command) for command in commands)
    problems = [f"missing isolated invocation: {' '.join(command)}"
                for command in sorted((expected - actual).elements())]
    problems += [f"unexpected or duplicate invocation: {' '.join(command)}"
                 for command in sorted((actual - expected).elements())]
    return problems


class AgentEvalWorkflowTests(unittest.TestCase):
    def test_selected_step_runs_every_present_harness_script_including_this_contract(self) -> None:
        scripts = {str(path.relative_to(ROOT)) for path in
                   (ROOT / "tests").glob("test_agent_evals*.py")}
        self.assertIn("tests/test_agent_evals_decision_gates.py", scripts)
        self.assertIn("tests/test_agent_evals_workflow.py", scripts)
        self.assertEqual([], workflow_problems(WORKFLOW.read_text(), scripts))

    def test_contract_rejects_missing_commented_and_out_of_step_commands(self) -> None:
        scripts = {"tests/test_agent_evals_a.py", "tests/test_agent_evals_b.py"}
        workflow = (
            "      - name: Harness\n"
            "        if: steps.scope.outputs.run_agent_evals == 'true'\n"
            "        run: |\n"
            "          python3 -B tests/test_agent_evals_a.py\n"
            "          python3 -B tests/test_agent_evals_b.py\n"
            "      - name: Other\n"
            "        run: echo other\n")
        self.assertEqual([], workflow_problems(workflow, scripts))
        invocation = "          python3 -B tests/test_agent_evals_b.py\n"
        for replacement in ("", "          # python3 -B tests/test_agent_evals_b.py\n"):
            with self.subTest(replacement=replacement):
                self.assertTrue(workflow_problems(workflow.replace(invocation, replacement), scripts))
        moved = workflow.replace(invocation, "").replace(
            "        run: echo other\n", "        run: |\n" + invocation)
        self.assertTrue(workflow_problems(moved, scripts))
        shared_process = workflow.replace(invocation,
            "          python3 -m unittest discover -s tests -p 'test_agent_evals*.py'\n")
        self.assertTrue(workflow_problems(shared_process, scripts))


if __name__ == "__main__":
    unittest.main()
