 #!/bin/bash
set -o nounset
set -o errexit

bw config server "${BW_HOST}"

export BW_SESSION=$(bw login "${BW_USER}" --passwordenv BW_PASSWORD --raw)

bw unlock --check

echo 'Running `bw server` on port 8087'
bw serve --port 8087 --hostname all #--disable-origin-protection
