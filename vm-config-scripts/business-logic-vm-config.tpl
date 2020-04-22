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
      export DB_ACCESS_APP_1_URL="${db_access_app_1_host_url}"
      export DB_ACCESS_ADMIN_APP_1_URL="${db_access_admin_app_1_host_url}"
      export DB_ACCESS_APP_2_URL="${db_access_app_2_host_url}"
      export DB_ACCESS_ADMIN_APP_2_URL="${db_access_admin_app_2_host_url}"
      export MAIN_APP_REPO_URL="${main_app_repo_url}"
      export SUPPORT_APP_REPO_URL="${support_app_repo_url}"
      export NGINX_REPO_URL="${nginx_repo_url}"

runcmd:
  # Load environment variables
  - . /etc/environment
  # Download Docker Compose files for application from S3 bucket
  - aws s3 cp s3://${app_docker_compose_bucket_id}/business-logic/ /usr/local/app/ --recursive
  # Setup app and start it
  - start-application -r ${ecr_base_url}
