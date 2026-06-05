# double-tap: Dockerized Encrypted Backup Tool

`double-tap` is a simple, Dockerized command-line tool designed to create encrypted backups of specified directories and optionally upload them to AWS S3, or store them locally. It leverages `tar` for archiving, `gpg` for AES256 encryption, and `aws-cli` for S3 integration.

## Running the Backup

The `backup.sh` script inside the Docker image acts as a command-line interface. You can pass arguments directly to the `docker run` command.

### Environment Variables

The following environment variables are **required** for the backup process. It's recommended to pass them via `-e` flags to `docker run` or use an `.env` file.

*   `AWS_ACCESS_KEY_ID`: Your AWS IAM user access key ID.
*   `AWS_SECRET_ACCESS_KEY`: Your AWS IAM user secret access key.
*   `PASSPHRASE`: The GPG passphrase used for encryption.
*   `AWS_DEFAULT_REGION`: (Optional) The AWS region for S3 (default: `eu-central-1`).

### Backup to S3

To create an encrypted backup and upload it to an S3 bucket:

```bash
docker run --rm \
  -v /path/to/your/data:/data \
  -e AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY" \
  -e PASSPHRASE="YOUR_GPG_PASSPHRASE" \
  -e AWS_DEFAULT_REGION="eu-central-1" \
  ghcr.io/poebelpogge/double-tap:0.1.1 s3://your-s3-bucket/backups/
```

*   `-v /path/to/your/data:/data`: Mounts your host directory (`/path/to/your/data`) into the container at `/data`. The `backup.sh` script will archive `/data`.
*   `s3://your-s3-bucket/backups/`: The target S3 path. If it ends with a `/`, a timestamped filename (`backup-YYYY-MM-DD_HH-MM-SS.tar.gz.gpg`) will be appended automatically.

### Local Encrypted Backup

To create an encrypted backup and save it locally within the mounted volume (without uploading to S3):

```bash
docker run --rm \
  -v /path/to/your/data:/data \
  -e PASSPHRASE="YOUR_GPG_PASSPHRASE" \
  ghcr.io/poebelpogge/double-tap:0.1.1 --skip-upload
```

The encrypted archive (`backup-YYYY-MM-DD_HH-MM-SS.tar.gz.gpg`) will be created directly in `/path/to/your/data` on your host machine.

## Decrypting and Extracting Backups

To restore a backup, you need `gpg` and `tar` installed on your system.

1.  **Download the `.gpg` file:** Retrieve your backup file (e.g., `backup-2023-10-27_14-30-00.tar.gz.gpg`) from S3 or your local storage.

2.  **Decrypt and Extract (single command):**

    ```bash
    gpg --decrypt your-backup-file.tar.gz.gpg | tar -xzf -
    ```

    You will be prompted for the `PASSPHRASE` used during encryption. The files will be extracted into your current directory.