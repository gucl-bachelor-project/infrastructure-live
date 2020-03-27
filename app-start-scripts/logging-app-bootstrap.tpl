#cloud-config
merge_how:
  - name: list
    settings: [append]
  - name: dict
    settings: [no_replace, recurse_list]

write_files:
  - path: /etc/environment
    permissions: 0644
    append: true
    content: |
      export LOGGING_APP_REPO_URL="${logging_app_repo_url}"
      export MONGODB_FILES_PATH="/mnt/${block_storage_mount_name}/data/db"

runcmd:
  # Load environment variables
  - . /etc/environment
  # Create a mount point for the prod log data volume
  - mkdir -p /mnt/${block_storage_mount_name}
  # Mount volume at the newly-created mount point
  - mount -o discard,defaults,noatime /dev/disk/by-id/scsi-0DO_Volume_${block_storage_name} /mnt/${block_storage_mount_name}
  # Change fstab so the volume will be mounted after a reboot
  - echo '/dev/disk/by-id/scsi-0DO_Volume_${block_storage_name} /mnt/${block_storage_mount_name} ext4 defaults,nofail,discard 0 0' | sudo tee -a /etc/fstab
  # Download Docker Compose files for application from S3 bucket
  - aws s3 cp s3://${app_docker_compose_bucket_id}/logging/ /usr/local/app/ --recursive
  # Setup app and start it
  - service-bootstrap -r ${ecr_base_url}
