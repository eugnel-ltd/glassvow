"""Small unencrypted Godot4 PCK reader/writer for real malformed-pack controls."""
from __future__ import annotations

import hashlib
from pathlib import Path
import struct


def read(path: Path) -> dict[str, bytes]:
    with path.open("rb") as file:
        header = file.read(112)
        magic, version, _major, _minor, _patch, flags = struct.unpack_from("<4s5I", header)
        if magic != b"GDPC" or version != 4 or flags != 2:
            raise ValueError("fixture requires the actual unencrypted Godot4 pack format4")
        base, directory = struct.unpack_from("<QQ", header, 24)
        file.seek(directory)
        count, = struct.unpack("<I", file.read(4))
        entries = []
        names = set()
        for _ in range(count):
            length, = struct.unpack("<I", file.read(4))
            name = file.read(length).split(b"\0", 1)[0].decode()
            offset, size = struct.unpack("<QQ", file.read(16))
            digest = file.read(16)
            entry_flags, = struct.unpack("<I", file.read(4))
            if entry_flags or offset + base + size > directory:
                raise ValueError("unexpected/duplicate/out-of-range pack entry")
            entries.append((name, offset + base, size, digest))
        files = {}
        for name, offset, size, digest in entries:
            file.seek(offset)
            data = file.read(size)
            if len(data) != size or hashlib.md5(data).digest() != digest:
                raise ValueError("pack entry checksum mismatch")
            normalized = name if name.startswith("res://") else "res://" + name
            if normalized in files and (normalized.startswith("res://_paged_paintings/") or files[normalized] != data):
                raise ValueError("conflicting or generated duplicate pack entry")
            files[normalized] = data
        return files


def write(path: Path, files: dict[str, bytes]) -> None:
    base = 112
    with path.open("wb") as file:
        header = bytearray(base)
        struct.pack_into("<4s5IQQ", header, 0, b"GDPC", 4, 4, 7, 2, 2, base, 0)
        file.write(header)
        entries = []
        for name, data in sorted(files.items()):
            offset = file.tell() - base
            file.write(data)
            entries.append((name, offset, len(data), hashlib.md5(data).digest()))
        directory = file.tell()
        file.write(struct.pack("<I", len(entries)))
        for name, offset, size, digest in entries:
            encoded = name.removeprefix("res://").encode() + b"\0"
            encoded += b"\0" * (-len(encoded) % 4)
            file.write(struct.pack("<I", len(encoded)))
            file.write(encoded)
            file.write(struct.pack("<QQ", offset, size) + digest + struct.pack("<I", 0))
        file.seek(32)
        file.write(struct.pack("<Q", directory))
