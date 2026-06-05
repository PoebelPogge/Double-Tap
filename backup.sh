#!/bin/sh
set -e

show_help() {
    echo "Usage: docker run double-tap [options] <source_directory> <s3_target_path>"
    echo ""
    echo "Options:"
    echo "  -p, --passphrase    GPG passphrase (or set PASSPHRASE env)"
    echo "  -b, --bucket        S3 Bucket name (or set AWS_BUCKET env)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Example:"
    echo "  docker run --rm -v /my/data:/data -e AWS_ACCESS_KEY_ID=... double-tap /data s3://my-bucket/backups/"
}

# Defaults
SOURCE_DIR=""
TARGET_S3_PATH=""

# Argument parsing
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--passphrase)
            PASSPHRASE="$2"
            shift 2
            ;;
        -b|--bucket)
            AWS_BUCKET="$2"
            shift 2
            ;;
        *)
            if [ -z "$SOURCE_DIR" ]; then
                SOURCE_DIR="$1"
            elif [ -z "$TARGET_S3_PATH" ]; then
                TARGET_S3_PATH="$1"
            else
                echo "Error: Unknown argument $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validation
SOURCE_DIR=${SOURCE_DIR:-"/data"}

if [ -z "$PASSPHRASE" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: Missing configuration (Passphrase or AWS Credentials)."
    exit 1
fi

TIMESTAMP=$(date +%F_%H-%M-%S)
FILENAME="backup-${TIMESTAMP}.tar.gz.gpg"

# Logic to handle S3 path and filename (sh compatible)
if [ -z "$TARGET_S3_PATH" ]; then
    if [ -z "$AWS_BUCKET" ]; then
        echo "Error: AWS_BUCKET or a full S3 path is required."
        exit 1
    fi
    TARGET_S3_PATH="s3://${AWS_BUCKET}/${FILENAME}"
else
    # Check if path ends with / using case (portable sh way)
    case "$TARGET_S3_PATH" in
        */) TARGET_S3_PATH="${TARGET_S3_PATH}${FILENAME}" ;;
    esac
fi

echo "Starting archiving from $SOURCE_DIR to $TARGET_S3_PATH..."

tar -czf - -C "$SOURCE_DIR" . | \
gpg --symmetric --cipher-algo AES256 --batch --passphrase "$PASSPHRASE" --pinentry-mode loopback | \
aws s3 cp - "$TARGET_S3_PATH" --storage-class GLACIER

echo "Backup successfully uploaded to $TARGET_S3_PATH."