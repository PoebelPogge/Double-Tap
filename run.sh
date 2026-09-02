#!/bin/bash
set -e

AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
PASSPHRASE="YOUR_PASSPHRASE"

echo "Starting Docker backup..."

sudo docker run --rm \
    -v .../path/to/your/folder:/data \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    -e AWS_DEFAULT_REGION=eu-central-1 \
    -e PASSPHRASE="${PASSPHRASE}" \
    ghcr.io/poebelpogge/double-tap:0.2.0 /data s3://...bucket_name.../

echo "Backup command finished."
