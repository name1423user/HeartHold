#!/usr/bin/env bash
# 書き出したファイルの SHA-256 を build/SHA256SUMS.txt に書く(GitHub Releases のノートに貼る)
set -euo pipefail
cd "$(dirname "$0")/.."
find build -type f ! -name '.gdignore' ! -name 'SHA256SUMS.txt' -print0 | sort -z | xargs -0 sha256sum | sed 's#  build/#  #' > build/SHA256SUMS.txt
cat build/SHA256SUMS.txt
