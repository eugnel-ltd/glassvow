"""Pinned bytes -> private sysroot. No ldd, shell, package install or engine probe.

The host-authenticated demand owns source/content/runtime closure. We reject
missing ELF interpreters/NEEDED names rather than importing host libraries.
Only copied bytes enter the root; original paths are never mounted in it.
"""
import json
import subprocess
import os
from pathlib import Path, PurePosixPath
import platform
import stat
import struct
import dd1_reservations as r
import dd1_runtime_fit as fit

ABI = "linux-x86_64-lp64-v1"
HELPER_SOURCES = frozenset("res://tools/" + p for p in (
    "dd1_linux/policy.h", "dd1_linux/policy.c", "dd1_linux/isolate.c",
    "dd1_linux/supervisor.c", "dd1_linux_snapshot.py", "dd1_linux_backend.py",
    "dd1_meter_entry.py", "dd1_reservations.py", "dd1_recovery_meter.py",
    "dd1_linux/capabilities.h", "dd1_linux/capabilities.c",
    "dd1_compatibility.py", "dd1_preparation.py", "dd1_preparation_watch.py",
    "dd1_prep_view.py", "dd1_import_semantics.py", "dd1_runtime_fit.py",
    "dd1_kernel_qualification.py"))


BUILD_SOURCES = HELPER_SOURCES | frozenset("res://tools/dd1_linux/" + name for name in (
    "inert.c", "compat2_inert.c", "fit_inert.c", "build_inert.py"))
FIXTURE_NAMES = frozenset(("inert", "inert-dynamic", "compat2-inert", "fit-inert"))


def build_sources(repo):
    return {name: r.digest((repo / name[6:]).read_bytes()) for name in sorted(BUILD_SOURCES)}


def verify_build_sources(repo, sources):
    r.need(isinstance(sources, dict) and set(sources) == BUILD_SOURCES, "build source closure mismatch")
    for name, wanted in sources.items():
        raw = subprocess.run(["git", "-C", str(repo), "show", "HEAD:" + name[6:]],
                             check=True, capture_output=True).stdout
        r.need(r.digest(raw) == wanted == r.digest((repo / name[6:]).read_bytes()),
               "build source differs from git blob: " + name)


def build_manifest(repo):
    """Read provenance from the executing checkout, never a staged caller manifest."""
    path = repo / "tools/dd1_linux/build/BUILD.json"
    r.need(not path.is_symlink(), "linked build manifest")
    manifest = json.loads(path.read_bytes())
    verify_build_sources(repo, manifest.get("sources"))
    return manifest


def fixture_hashes(names=FIXTURE_NAMES):
    repo = Path(__file__).resolve().parents[1]
    path = repo / "tools/dd1_linux/build/BUILD.json"
    if not path.exists():
        return frozenset()
    manifest = build_manifest(repo)
    hashes = set()
    for name in names:
        item = manifest.get("binaries", {}).get(name)
        if item is not None:
            raw = (path.parent / name).read_bytes()
            r.need(r.digest(raw) == item["sha256"] and len(raw) == item["bytes"],
                   "built fixture identity mismatch: " + name)
            hashes.add(item["sha256"])
    return frozenset(hashes)


def validate_helper(helper, declared):
    manifest = build_manifest(Path(__file__).resolve().parents[1])
    item = manifest["binaries"]["supervisor"]
    r.need(r.digest(helper) == declared == item["sha256"] and len(helper) == item["bytes"]
           and elf(helper) == (None, []), "helper must match built static ELF")


def read_regular(root: Path, name: str, maximum: int = 1 << 30) -> bytes:
    parts = PurePosixPath(name).parts
    r.need(len(name.encode()) <= 384 and len(parts) <= 12, "input path bound")
    r.need(parts and not name.startswith("/") and all(x not in (".", "..", "") for x in parts), "unsafe input path")
    r.need(not any(x in (".git", ".ssh", ".env") for x in parts) and parts[-1] != "ACCOUNT.json", "private/account source forbidden")
    fd = os.open(root, os.O_PATH | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for component in parts[:-1]:
            new = os.open(component, os.O_PATH | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd); fd = new
        file = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK, dir_fd=fd)
        with os.fdopen(file, "rb") as stream:
            s = os.fstat(stream.fileno())
            r.need(stat.S_ISREG(s.st_mode) and s.st_nlink == 1 and s.st_size <= maximum, "nonregular/linked/oversized input")
            raw = stream.read(maximum + 1)
            r.need(len(raw) == s.st_size, "input changed while reading")
            return raw
    finally:
        os.close(fd)


def elf(raw: bytes) -> tuple[str | None, list[str]]:
    r.need(len(raw) >= 64 and raw[:6] == b"\x7fELF\x02\x01" and
           struct.unpack_from("<H", raw, 18)[0] == 62, "unsupported executable architecture/ABI")
    phoff = struct.unpack_from("<Q", raw, 32)[0]
    size, count = struct.unpack_from("<HH", raw, 54)
    r.need(size == 56 and 0 < count <= 1024 and phoff + size * count <= len(raw), "malformed ELF headers")
    interp, loads, dynamic = None, [], b""
    for i in range(count):
        kind, flags, offset, addr, _, filesz, _, _ = struct.unpack_from("<IIQQQQQQ", raw, phoff + i * size)
        r.need(offset + filesz <= len(raw), "truncated ELF segment")
        if kind == 1: loads.append((addr, offset, filesz))
        if kind == 3:
            r.need(interp is None and 1 < filesz <= 4096, "ELF interpreter")
            interp = raw[offset:offset + filesz].rstrip(b"\0").decode("utf-8")
        if kind == 2: dynamic = raw[offset:offset + filesz]
    needed, string_addr, string_size = [], None, 0
    for i in range(0, len(dynamic) - 15, 16):
        tag, value = struct.unpack_from("<QQ", dynamic, i)
        if tag == 0: break
        if tag == 1: needed.append(value)
        if tag == 5: string_addr = value
        if tag == 10: string_size = value
    strings = b""
    if needed:
        for addr, offset, size in loads:
            if string_addr is not None and addr <= string_addr and string_addr + string_size <= addr + size:
                strings = raw[offset + string_addr - addr:offset + string_addr - addr + string_size]
        r.need(strings, "ELF string table missing")
    names = []
    for at in needed:
        end = strings.find(b"\0", at)
        r.need(0 <= at < end and end - at <= 4096, "ELF dependency string")
        names.append(strings[at:end].decode("utf-8"))
    return interp, names


def prepare(unit: dict, command: list[str], repo: Path, generated=None) -> dict:
    import dd1_kernel_qualification as kernel_qualification
    host = dict(system=platform.system(), machine=platform.machine(),
                kernel_release=platform.release(), kernel_version=platform.version(),
                pointer_bytes=struct.calcsize("P"), libc=list(platform.libc_ver()))
    kernel_qualification.require(unit, host)
    b = unit.get("linux", {})
    r.need(b.get("abi") == ABI, "missing supported Linux demand")
    r.need(HELPER_SOURCES <= unit["source_files"].keys(), "backend source closure missing")
    fit.limit(unit)
    r.need(11 <= unit["cpu_seconds"] <= 300, "CPU partition requires at least eleven reserved seconds")
    r.need(0 < r.natural(b.get("workload_raw_bytes"), "workload raw") <= unit["raw_bytes"], "invalid workload raw bound")
    source, files = {}, {}
    for name, wanted in unit["source_files"].items():
        raw = read_regular(repo, name[6:])
        r.need(r.digest(raw) == wanted, "actual source bytes differ: " + name)
        if name in HELPER_SOURCES and name.endswith(".py"):
            actual = read_regular(Path(__file__).resolve().parents[1], name[6:])
            r.need(actual == raw, "loaded controller source differs:" + name)
        source[name] = raw; files["/source/" + name[6:]] = (raw, False)
    import dd1_prep_view as view
    sealed = isinstance(generated, view.SealedInputs)
    allowed = generated.seeded_paths if sealed else set()
    if sealed:
        r.need(generated.recipe["view"] == view.describe(source), "sealed runtime source/view drift")
    for name, raw in (generated or {}).items():
        r.need((name not in source or name in allowed) and name.startswith("res://"), "generated source collision")
        files["/source/" + name[6:]] = (raw, False)
    runtime = b.get("runtime")
    r.need(isinstance(runtime, dict) and runtime and len(files) + len(runtime) <= 4096, "runtime closure size")
    for dest, item in runtime.items():
        parts = PurePosixPath(dest).parts
        r.need(len(dest.encode()) <= 384 and len(parts) <= 12 and dest.startswith("/") and str(PurePosixPath(dest)) == dest and
               ".." not in parts and len(parts) > 1 and parts[1] not in ("source", "out", "proc", "sys", "dev") and
               dest not in ("/grant.json", "/launch-receipt.json", "/dd1-preparation.layout") and
               parts[1] != "dd1-originals", "unsafe runtime destination")
        raw = read_regular(repo, item["path"])
        r.need(r.digest(raw) == item["sha256"] and type(item["executable"]) is bool, "runtime identity mismatch")
        files[dest] = (raw, item["executable"])
    r.need(b.get("entry") == command[0] and command[0] in files and files[command[0]][1], "unbound executable/argv")
    elf(files[command[0]][0])
    basenames = {PurePosixPath(x).name for x in files}
    for name, (raw, executable) in files.items():
        if executable or raw.startswith(b"\x7fELF"):
            interp, needed = elf(raw)
            r.need(interp is None or interp in files, "unbound interpreter: " + str(interp))
            r.need(all(n in files if n.startswith("/") else n in basenames for n in needed), "unbound runtime dependency")
    helper = read_regular(repo, b["helper"]["path"])
    validate_helper(helper, b["helper"]["sha256"])
    import dd1_preparation as preparation
    recipe = preparation.validate_recipe(unit, source)
    overrides, archives = view.execution_files(recipe, source)
    if sealed:
        archives = generated.originals
    for name, raw in overrides.items():
        files["/source/" + name[6:]] = (raw, False)
    for name, raw in archives.items():
        files["/dd1-originals/" + name[6:]] = (raw, False)
    r.need(len(files) <= 4096, "projected runtime file count")
    if view.selected(recipe) or sealed:
        actual_view = {"res://"+n[len("/source/"):]: r.digest(v[0])
                       for n,v in files.items() if n.startswith("/source/")}
        r.need(unit.get("execution_files") == actual_view, "actual execution files differ from demand")
    # Payload copies + worst-case path/creation metadata. No compression credit.
    setup_raw = len(helper) + sum(len(raw) + 16384 for raw, _ in files.values()) + 32768
    r.need(setup_raw + b["workload_raw_bytes"] + 524288 < unit["raw_bytes"], "raw cannot fit immutable inputs and workload")
    import dd1_preparation as preparation
    import dd1_compatibility as compatibility
    promotion = preparation.reserve_copy_bytes(recipe, source)
    result = dict(files=files, source=source, helper=helper, setup_raw=setup_raw + promotion,
                  config=b, preparation=recipe, promotion_raw=promotion,
                  kernel_release=host["kernel_release"], kernel_version=host["kernel_version"])
    result["private_modes"], result["mode_projection"] = fit.validate(unit, source, files)
    result["profile"] = compatibility.validate_profile(unit, result)
    r.need(result["setup_raw"] + b["workload_raw_bytes"] + 524288 < unit["raw_bytes"],
           "complete preparation/copy raw envelope")
    return result


def verify_ancestry(bodies, head: str, ancestor: str) -> None:
    """Verify supplied Git commit bytes without spawning Git inside the unit.

    The same H-bound demand carries these immutable object bytes; this checks
    ancestry, not issuer authentication. A path may follow any declared parent.
    """
    import hashlib
    r.need(isinstance(bodies, list) and len(bodies) <= 128, "bounded Git ancestry bytes required")
    current = head
    for index, body in enumerate(bodies):
        r.need(isinstance(body, str) and 0 < len(body.encode()) <= 65536, "invalid Git commit bytes")
        raw = body.encode()
        actual = hashlib.sha1(b"commit " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        r.need(actual == current and current != ancestor, "Git ancestry object mismatch")
        parents = [line[7:] for line in body.split("\n\n", 1)[0].splitlines() if line.startswith("parent ")]
        if index + 1 == len(bodies):
            current = ancestor
        else:
            nxt = bodies[index + 1]
            r.need(isinstance(nxt, str), "invalid next Git commit")
            data = nxt.encode()
            current = hashlib.sha1(b"commit " + str(len(data)).encode() + b"\0" + data).hexdigest()
        r.need(current in parents, "Git ancestry parent mismatch")
    r.need(current == ancestor, "missing Git ancestry chain")