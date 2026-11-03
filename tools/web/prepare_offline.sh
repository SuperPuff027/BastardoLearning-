#!/usr/bin/env bash
# Bereitet build/web für den Offline-Betrieb vor:
#  - entfernt Debug-Symbole und ungenutzte Renderer (spart ~25 MB)
#  - schreibt precache.json (alle Dateien, die beim ersten Besuch geladen werden)
#  - setzt die Build-Version in offline_sw.js (neue Version = Update)
set -euo pipefail
DIR="${1:-build/web}"
VERSION="${2:-$(date +%Y%m%d%H%M%S)}"
cd "$DIR"

find . -name '*.symbols' -delete
rm -rf canvaskit/skwasm* canvaskit/wimp* canvaskit/webparagraph flutter_service_worker.js

# canvaskit/ (Safari) und canvaskit/chromium/ (Chrome) werden beide vorab geladen.
python3 - "$VERSION" <<'PY'
import json, os, sys
files = ["./"]
for root, _, names in os.walk("."):
    for n in names:
        p = os.path.relpath(os.path.join(root, n), ".").replace(os.sep, "/")
        if p in ("offline_sw.js", "precache.json"):
            continue
        files.append(p)
json.dump(sorted(files), open("precache.json", "w"), indent=0)
sw = open("offline_sw.js").read().replace("__BUILD_VERSION__", sys.argv[1])
open("offline_sw.js", "w").write(sw)
print(f"{len(files)} Dateien im Offline-Cache, Version {sys.argv[1]}")
PY
du -sh .
