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
      export DB_ADMINISTRATION_APP_1_HOST_URL="${db_administration_app_1_host_url}"
      export DB_ADMIN_ADMINISTRATION_APP_1_HOST_URL="${db_admin_administration_app_1_host_url}"
      export DB_ADMINISTRATION_APP_2_HOST_URL="${db_administration_app_2_host_url}"
      export DB_ADMIN_ADMINISTRATION_APP_2_HOST_URL="${db_admin_administration_app_2_host_url}"
      export MAIN_APP_REPO_URL="${main_app_repo_url}"
      export SUPPORT_APP_REPO_URL="${support_app_repo_url}"
      export NGINX_REPO_URL="${nginx_repo_url}"
