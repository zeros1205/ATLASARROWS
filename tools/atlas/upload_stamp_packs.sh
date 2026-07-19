#!/usr/bin/env bash
# Publishes the stamp packs to Firebase Storage.
#
# Run build_stamp_packs.py first — this only uploads what is already in
# build/stamp_packs/, and the app checks each pack against the sha256 baked
# into the bundled manifest, so a stale upload fails closed rather than
# showing wrong art.
#
#   python tools/atlas/build_stamp_packs.py
#   bash tools/atlas/upload_stamp_packs.sh
#
# Requires: firebase login (already done on this machine) and a Storage bucket,
# which needs the project on the Blaze plan.
set -euo pipefail

PROJECT=atlasarrows-7a720
BUCKET="${PROJECT}.firebasestorage.app"
VERSION=$(python -c "import json;print(json.load(open('assets/campaign/stamp_manifest.json'))['version'])")
SRC=build/stamp_packs

[ -d "$SRC" ] || { echo "no $SRC — run build_stamp_packs.py first"; exit 1; }

echo "→ gs://${BUCKET}/stamps/v${VERSION}/"
for f in "$SRC"/*.zip; do
  echo "  $(basename "$f")  $(du -h "$f" | cut -f1)"
  gcloud storage cp "$f" "gs://${BUCKET}/stamps/v${VERSION}/" --project="$PROJECT"
done

# Rules travel with the packs: the bucket is world-readable for this prefix and
# closed everywhere else.
firebase deploy --only storage --project "$PROJECT"

echo
echo "done. verify one:"
echo "  curl -sI 'https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/stamps%2Fv${VERSION}%2Fstamps-europe-v${VERSION}.zip?alt=media' | head -1"
