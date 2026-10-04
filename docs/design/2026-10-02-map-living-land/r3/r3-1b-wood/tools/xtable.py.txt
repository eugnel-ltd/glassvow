"""Parse an `xctrace export --xpath .../table[@schema=...]` XML into rows.

Each row becomes a dict keyed by the schema's column mnemonics; each value is
(fmt, text) with id/ref deduplication resolved. Sentinel cells are None.
"""
import sys
import xml.etree.ElementTree as ET


def _flat(el, ids):
    if el.get("ref") is not None:
        return ids[el.get("ref")]
    val = (el.get("fmt"), (el.text or "").strip(), el)
    if el.get("id") is not None:
        ids[el.get("id")] = val
    # Register nested ids too, so later refs into children resolve.
    for child in el.iter():
        if child is el:
            continue
        if child.get("id") is not None and child.get("id") not in ids:
            ids[child.get("id")] = (child.get("fmt"), (child.text or "").strip(), child)
    return val


def rows(path):
    ids = {}
    cols = []
    out = []
    for event, el in ET.iterparse(path, events=("end",)):
        if el.tag == "schema":
            cols = [c.findtext("mnemonic") for c in el.findall("col")]
        elif el.tag == "row":
            r = {}
            for name, cell in zip(cols, list(el)):
                r[name] = None if cell.tag == "sentinel" else _flat(cell, ids)
            out.append(r)
    return cols, out


if __name__ == "__main__":
    cols, rs = rows(sys.argv[1])
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    print(cols)
    for r in rs[:n]:
        print({k: (v[0] if v else None) for k, v in r.items()})
