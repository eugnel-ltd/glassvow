"""Host qualification and finite per-case limits for harmless DD1 controls."""
from __future__ import annotations
import json
import platform
import struct
import dd1_reservations as r

SCHEMA = "DD1-KERNEL-QUALIFICATION-1"
OPERATION = "DD1-KERNEL-COMPAT-1"
SELECTION = 5845725453
DISPOSITION_SCHEMA = "DD1-KERNEL-COMPAT-DISPOSITION-1"
PRIMITIVES = frozenset((
    "seccomp_user_notif", "user_namespace", "mount_namespace", "network_namespace",
    "readonly_bind_remount", "subreaper", "pdeathsig", "rlimit_cpu", "cgroup_v2"))
IDENTITY_FIELDS = ("system", "machine", "kernel_release", "kernel_version",
                   "pointer_bytes", "libc")
KEYS = frozenset(("schema", "status", "mode", "host_identity", "primitives"))


def host_facts():
    return dict(system=platform.system(), machine=platform.machine(),
                kernel_release=platform.release(), kernel_version=platform.version(),
                pointer_bytes=struct.calcsize("P"), libc=list(platform.libc_ver()))


def profile():
    return dict(schema=SCHEMA, status="REQUALIFYING", mode="inert_control",
                host_identity=host_facts(), primitives=sorted(PRIMITIVES))


INERT_RESERVATION_POLICY = {
    "operation": "DD1-KERNEL-COMPAT-1",
    "synthetic_only": True,
    "starts_cap": 1,
    "cpu_ns_cap": 30_000_000_000,
    "raw_bytes_cap": 134_217_728,
    "per_invocation_cpu_seconds": 30,
    "executors": 1,
}


def profile_sha256(unit):
    return r.digest(r.encode(unit["kernel_qualification"]))


def require(unit, host_facts):
    r.need(host_facts["system"] == "Linux" and host_facts["machine"] == "x86_64"
           and host_facts["pointer_bytes"] == 8, "unsupported host/ABI; no fallback")
    q = unit.get("kernel_qualification")
    if q is None:
        return
    r.need(isinstance(q, dict), "kernel qualification profile required")
    r.need(set(q) == KEYS, "no extra fields")
    r.need(q["schema"] == SCHEMA, "wrong kernel qualification schema")
    r.need(q["status"] in ("REQUALIFYING", "QUALIFIED"), "wrong kernel qualification status")
    r.need(q["mode"] == unit.get("mode"), "kernel qualification mode mismatch")
    ident = q["host_identity"]
    r.need(isinstance(ident, dict) and set(ident) == set(IDENTITY_FIELDS), "wrong host identity fields")
    for field in IDENTITY_FIELDS:
        r.need(field in host_facts and ident[field] == host_facts[field], "host identity mismatch: " + field)
    prims = q["primitives"]
    r.need(isinstance(prims, list) and all(isinstance(name, str) for name in prims)
           and len(prims) == len(PRIMITIVES) and sorted(prims) == sorted(PRIMITIVES),
           "wrong primitive set")
    if q["status"] == "REQUALIFYING":
        r.need(q["mode"] == "inert_control" and unit.get("mode") == "inert_control",
               "REQUALIFYING is inert-control only")


def native_bindings(unit, expected, context):
    q = unit.get("kernel_qualification")
    if q is None:
        return
    r.need(isinstance(q, dict), "kernel qualification profile required")
    r.need(q.get("status") == "QUALIFIED",
           "REQUALIFYING/incomplete kernel qualification is not native authority")
    role = expected["roles"].get("kernel_qualification_disposition", {})
    raw = context.resolve(role.get("locator"))
    r.need(isinstance(raw, bytes) and r.digest(raw) == role.get("sha256"),
           "missing kernel qualification disposition")
    try:
        d = json.loads(raw)
    except ValueError as exc:
        raise r.ReservationError("malformed kernel qualification disposition") from exc
    r.need(isinstance(d, dict), "malformed kernel qualification disposition")
    r.need(d.get("schema") == DISPOSITION_SCHEMA, "wrong disposition schema")
    r.need(d.get("operation") == OPERATION, "wrong disposition operation")
    r.need(d.get("owner_selection") == SELECTION, "wrong disposition owner selection")
    r.need(d.get("profile_sha256") == profile_sha256(unit), "wrong disposition profile")
    r.need(d.get("source_head") == unit["overlay_head"], "wrong disposition source head")
    r.need(d.get("kernel_identity") == q["host_identity"], "wrong disposition kernel identity")
    r.need(d.get("independent_review") == "APPROVE", "disposition review is not approved")
    r.need(d.get("planner_acceptance") == "ACCEPTED", "disposition is not accepted")
    r.need(d.get("launch_admitted") is True, "disposition launch is not admitted")
    auth = expected.get("receipt_authorities", {}).get("kernel_qualification_disposition", {})
    r.need(isinstance(auth.get("authority"), str) and auth["authority"]
           and not auth["authority"].startswith("synthetic:")
           and auth.get("sha256") == r.digest(raw) and d.get("authority") == auth["authority"]
           and context.receipts.get("kernel_qualification_disposition") == raw,
           "unauthenticated kernel qualification issuer")
    r.need(context.kind == "empirical", "kernel qualification rejects synthetic native authority")


def inert_reservation_policy(unit):
    """Per-case resource bounds; neither calendar expiry nor operation-wide credit."""
    r.need(unit.get("mode") == "inert_control", "kernel reservation policy is inert-control only")
    r.need(unit.get("operation") == OPERATION, "wrong unit operation")
    q = unit.get("kernel_qualification")
    r.need(isinstance(q, dict) and q.get("status") == "REQUALIFYING", "REQUALIFYING required")
    return dict(INERT_RESERVATION_POLICY)
