#!/usr/bin/env python3
"""Download thumbnails for the stock plants in mock_json/details into the
frontend's public folder and point each snapshot's default_image.thumbnail at
the self-hosted copy (/images/plants/<id>.jpg).

Why: Perenual retired its old perenual.com/storage image links and now serves
signed URLs that expire after 24 hours, so snapshotted links rot. Hosting the
thumbnails with the frontend makes the stock list stable and costs no API calls
at runtime.

Usage (from the backend repo root):
    PERENUAL_API_KEY=... python scripts/snapshot_plant_images.py ../backyarder-ui

Idempotent: plants already pointing at a local file are skipped. Stops on the
first 429 so you can rerun after the free-tier daily quota resets. Each plant
costs one Perenual request.
"""
import glob
import json
import os
import sys
import time
import urllib.request

DETAILS_DIR = "mock_json/details"


def main(ui_root: str) -> int:
    key = os.environ.get("PERENUAL_API_KEY")
    if not key:
        print("PERENUAL_API_KEY is not set", file=sys.stderr)
        return 2
    out_dir = os.path.join(ui_root, "public", "images", "plants")
    os.makedirs(out_dir, exist_ok=True)

    ids = sorted(int(os.path.basename(p)[:-5]) for p in glob.glob(f"{DETAILS_DIR}/*.json"))
    done, todo, failed, no_image = [], [], [], []
    for pid in ids:
        path = f"{DETAILS_DIR}/{pid}.json"
        text = open(path, "rb").read().decode()
        current = (json.loads(text).get("default_image") or {}).get("thumbnail")
        local = f"/images/plants/{pid}.jpg"
        if not current:
            no_image.append(pid)
            continue
        if current == local and os.path.exists(os.path.join(out_dir, f"{pid}.jpg")):
            done.append(pid)
            continue
        try:
            with urllib.request.urlopen(f"https://perenual.com/api/v2/species/details/{pid}?key={key}", timeout=30) as r:
                live = json.load(r)
            url = (live.get("default_image") or {}).get("thumbnail")
            if not url:
                print(f"{pid}: no live thumbnail, leaving as is")
                failed.append(pid)
                continue
            with urllib.request.urlopen(url, timeout=30) as r:
                data = r.read()
                ctype = r.headers.get("Content-Type", "")
            if not ctype.startswith("image/") or len(data) < 500:
                print(f"{pid}: unexpected response ({ctype}, {len(data)} bytes)")
                failed.append(pid)
                continue
            with open(os.path.join(out_dir, f"{pid}.jpg"), "wb") as f:
                f.write(data)
            with open(path, "wb") as f:
                f.write(text.replace(current, local).encode())
            print(f"{pid}: saved {len(data)} bytes ({live.get('common_name')})")
            todo.append(pid)
            time.sleep(0.3)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                print(f"{pid}: HTTP 429 - Perenual daily quota exhausted; rerun later", file=sys.stderr)
                remaining = [i for i in ids if i not in done + todo + no_image + failed]
                print(f"remaining: {remaining}", file=sys.stderr)
                return 1
            print(f"{pid}: HTTP {e.code}", file=sys.stderr)
            failed.append(pid)
        except Exception as e:  # noqa: BLE001
            print(f"{pid}: {e!r}", file=sys.stderr)
            failed.append(pid)

    print(f"already local: {len(done)}, downloaded now: {len(todo)}, no image: {no_image}, failed: {failed}")
    return 0 if not failed else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
