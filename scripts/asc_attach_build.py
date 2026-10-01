#!/usr/bin/env python3
"""Attach one processed TestFlight build to a beta group through the App Store Connect API.

Usage: scripts/asc_attach_build.py <build-id> <beta-group-id>

Credentials come from the environment, never from the repository:
ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY_PATH (the same three that `asc`
reads). Needs `pip install pyjwt cryptography` for the ES256 token.

Prints `group attach <status>` and exits 0 on success. ASC also answers 409 for
a build that is in an invalid state or missing export compliance, so a 409 is
never trusted: the group's builds are listed and the call succeeds only if the
build id is in that list (already attached). Otherwise the error body is printed
and the exit status is non-zero.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"
TOKEN_LIFETIME_SECONDS = 600
TIMEOUT_SECONDS = 30


def _require_env(name):
    value = os.environ.get(name, "")
    if not value:
        sys.exit(f"{name} is not set")
    return value


def _token(key_id, issuer_id, key_path):
    with open(os.path.expanduser(key_path), encoding="utf-8") as handle:
        private_key = handle.read()
    now = int(time.time())
    claims = {"iss": issuer_id, "iat": now, "exp": now + TOKEN_LIFETIME_SECONDS,
              "aud": "appstoreconnect-v1"}
    return jwt.encode(claims, private_key, algorithm="ES256", headers={"kid": key_id})


def _request(url, token, method="GET", body=None):
    request = urllib.request.Request(
        url, method=method, data=body,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()[:300]


def attach(build_id, group_id, token):
    body = json.dumps({"data": [{"type": "builds", "id": build_id}]}).encode()
    return _request(f"{API}/betaGroups/{group_id}/relationships/builds", token, "POST", body)


def group_contains(build_id, group_id, token):
    """True only if the build id is in the group's builds, following pagination."""
    url = f"{API}/betaGroups/{group_id}/builds?limit=200"
    while url:
        status, payload = _request(url, token)
        if status != 200:
            return False
        page = json.loads(payload)
        if any(item.get("id") == build_id for item in page.get("data", [])):
            return True
        url = page.get("links", {}).get("next")
    return False


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__)
    build_id, group_id = argv[1], argv[2]
    token = _token(_require_env("ASC_KEY_ID"), _require_env("ASC_ISSUER_ID"),
                   _require_env("ASC_PRIVATE_KEY_PATH"))
    status, payload = attach(build_id, group_id, token)
    if status in (200, 204):
        print(f"group attach {status}")
        return 0
    if status == 409 and group_contains(build_id, group_id, token):
        print("group attach 409 (build already in the group)")
        return 0
    print(f"group attach {status} {payload.decode('utf-8', 'replace')}".rstrip())
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
