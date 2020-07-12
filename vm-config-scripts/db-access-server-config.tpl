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
      export LOGGING_APP_HOST_URL="${logging_app_host_url}"
      export DB_ADMINISTRATION_APP_REPO_URL="${db_administration_app_repo_url}"
      export DB_ADMIN_ADMINISTRATION_APP_REPO_URL="${db_admin_administration_app_repo_url}"
      export APP_DB_USERNAME="${app_db_username}"
      export APP_DB_PASSWORD="${app_db_password}"
      export APP_DB_1_NAME="${app_db_1_name}"
      export APP_DB_2_NAME="${app_db_2_name}"
      export DB_HOSTNAME="${db_hostname}"
      export DB_PORT="${db_port}"

runcmd:
  # Load environment variables
  - . /etc/environment
  # Download Docker Compose files for persistence subsystem from S3 bucket
  - aws s3 cp s3://${app_docker_compose_bucket_id}/persistence/ /usr/local/app/ --recursive
  # Setup persistence subsystem and start it
  - start-application -r ${ecr_base_url}
