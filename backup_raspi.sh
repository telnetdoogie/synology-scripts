#!/bin/sh
IMAGE_FILE=/mnt/thebucket/backup/dockerpi_backup.img
LOG_FILE=/mnt/thebucket/backup/dockerpi_backup.log

exec >> "$LOG_FILE" 2>&1
echo
echo "==== RUNNING BACKUP ON $(date) ===="

# Function to start Docker (cleanup)
start_docker() {
    echo "Starting Docker service..."
    systemctl start docker.service
    echo "==== COMPLETE - $(date) ===="
}

# Trap to always run start_docker on script exit
trap start_docker EXIT

# Stop Docker service
echo "Stopping Docker service..."
systemctl stop docker.service

echo "Running Backup..."
# Backup Raspberry Pi image
/usr/local/sbin/image-backup "$IMAGE_FILE" || {
    echo "ERROR: image-backup failed!"
    exit 1
}
echo "Backup completed successfully."

echo "Validating image..."
# Validate Raspberry Pi image
/usr/local/sbin/image-info "$IMAGE_FILE" || {
    echo "ERROR: image-info failed!"
    exit 1
}
