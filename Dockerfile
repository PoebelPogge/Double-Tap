FROM alpine:latest

# Install necessary tools
RUN apk add --no-cache \
    tar \
    age \
    aws-cli \
    bash

COPY backup.sh /usr/local/bin/backup
RUN chmod +x /usr/local/bin/backup

# Set entrypoint to the script, allowing arguments to be passed
ENTRYPOINT ["/usr/local/bin/backup"]
CMD ["--help"]