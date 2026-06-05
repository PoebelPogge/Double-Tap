#!/bin/sh
set -e

show_help() {
    echo "Usage: docker run double-tap [options] [s3_target_path]"
    echo ""
    echo "Options:"
    echo "  -p, --passphrase    GPG passphrase (or set PASSPHRASE env)"
    echo "  -b, --bucket        S3 Bucket name (or set AWS_BUCKET env)"
    echo "  --skip-upload       Only create encrypted archive locally, do not upload to S3."
    echo "                      (Local archive will be saved in the mounted /data volume)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Example (Upload to S3):"
    echo "  docker run --rm -v /path/to/your/data:/data -e AWS_ACCESS_KEY_ID=... double-tap s3://my-bucket/backups/"
    echo ""
    echo "Example (Local encrypted archive):"
    echo "  docker run --rm -v /path/to/your/data:/data -e PASSPHRASE=... double-tap --skip-upload"
}

# Defaults
TARGET_S3_PATH=""
SKIP_UPLOAD=0 # Default to upload

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
        --skip-upload)
            SKIP_UPLOAD=1
            shift
            ;;
        *) # Positional arguments (should only be TARGET_S3_PATH)
            if [ -z "$TARGET_S3_PATH" ]; then
                TARGET_S3_PATH="$1"
            else
                echo "Error: Unknown argument or too many positional arguments: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# SOURCE_DIR is now fixed to /data as per user's request
SOURCE_DIR="/data"

# Validation
if [ -z "$PASSPHRASE" ]; then
    echo "Error: Passphrase is required for encryption."
    exit 1
fi

if [ "$SKIP_UPLOAD" -eq 0 ]; then
    # If uploading, AWS credentials are required
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "Error: Missing AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY for S3 upload."
        exit 1
    fi
    # If uploading, TARGET_S3_PATH (or AWS_BUCKET) is required
    if [ -z "$TARGET_S3_PATH" ] && [ -z "$AWS_BUCKET" ]; then
        echo "Error: S3 target path or AWS_BUCKET is required for S3 upload."
        show_help
        exit 1
    fi
    # If SKIP_UPLOAD is 0, TARGET_S3_PATH should not be empty if AWS_BUCKET is not set
    if [ -z "$TARGET_S3_PATH" ] && [ -z "$AWS_BUCKET" ]; then
        echo "Error: S3 target path or AWS_BUCKET is required for S3 upload."
        show_help
        exit 1
    fi
else # SKIP_UPLOAD is 1
    if [ -n "$TARGET_S3_PATH" ]; then
        echo "Error: S3 target path cannot be specified when --skip-upload is used."
        show_help
        exit 1
    fi
fi

TIMESTAMP=$(date +%F_%H-%M-%S)
FILENAME="backup-${TIMESTAMP}.tar.gz.gpg"

# Logic to handle S3 path and filename (sh compatible)
if [ "$SKIP_UPLOAD" -eq 0 ]; then
    if [ -z "$TARGET_S3_PATH" ]; then
        TARGET_S3_PATH="s3://${AWS_BUCKET}/${FILENAME}"
    else
        # Check if path ends with / using case (portable sh way)
        case "$TARGET_S3_PATH" in
            */) TARGET_S3_PATH="${TARGET_S3_PATH}${FILENAME}" ;;
        esac
    fi
fi

# --- Main Logic ---
if [ "$SKIP_UPLOAD" -eq 1 ]; then
    LOCAL_OUTPUT_PATH="$SOURCE_DIR/$FILENAME"
    echo "Starting archiving and encryption to local file: $LOCAL_OUTPUT_PATH..."
    tar -czf - -C "$SOURCE_DIR" . | \
    gpg --symmetric --cipher-algo AES256 --batch --passphrase "$PASSPHRASE" --pinentry-mode loopback > "$LOCAL_OUTPUT_PATH"
    echo "Backup successfully created locally as $LOCAL_OUTPUT_PATH."
else
    echo "Starting archiving from $SOURCE_DIR to $TARGET_S3_PATH..."
    tar -czf - -C "$SOURCE_DIR" . | \
    gpg --symmetric --cipher-algo AES256 --batch --passphrase "$PASSPHRASE" --pinentry-mode loopback | \
    aws s3 cp - "$TARGET_S3_PATH" --storage-class GLACIER
    echo "Backup successfully uploaded to $TARGET_S3_PATH."
fi