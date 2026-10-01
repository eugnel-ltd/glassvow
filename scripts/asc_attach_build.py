#!/usr/bin/env python3
"""Attach one processed TestFlight build to a beta group through the App Store Connect API.

Usage: scripts/asc_attach_build.py <build-id> <beta-group-id>

Credentials come from the environment, never from the repository:
ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY_PATH (the same three that `asc`
reads). Needs `pip install pyjwt cryptography` for the ES256 token.

Prints `group attach <status>` and exits 0 on success. A 409 means the build is
already in the group, which is the outcome we want, so it also exits 0.
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


def attach(build_id, group_id, token):
    request = urllib.request.Request(
        f"{API}/betaGroups/{group_id}/relationships/builds",
        method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        data=json.dumps({"data": [{"type": "builds", "id": build_id}]}).encode(),
    )
    try:
        with urllib.request.urlopen(request) as response:
            return response.status, ""
    except urllib.error.HTTPError as error:
        return error.code, error.read()[:300].decode("utf-8", "replace")


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__)
    build_id, group_id = argv[1], argv[2]
    token = _token(_require_env("ASC_KEY_ID"), _require_env("ASC_ISSUER_ID"),
                   _require_env("ASC_PRIVATE_KEY_PATH"))
    status, detail = attach(build_id, group_id, token)
    print(f"group attach {status} {detail}".rstrip())
    return 0 if status in (200, 204, 409) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
