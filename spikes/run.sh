#!/bin/sh
# run every spike from the repo root; exit non-zero if any fails
cd "$(dirname "$0")/.." || exit 2
rc=0
for f in spikes/a*.q; do
  echo "=== $f"
  q "$f" -q || rc=1
done
exit $rc
