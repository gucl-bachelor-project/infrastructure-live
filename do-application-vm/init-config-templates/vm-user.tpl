#cloud-config
merge_how:
 - name: list
   settings: [append]
 - name: dict
   settings: [no_replace, recurse_list]

users:
  - name: ubuntu
    groups: sudo, docker
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
      ${authorized_ssh_keys}

runcmd:
  # Copy root's AWS credentials to new user
  - cp -r /root/.aws /home/ubuntu/.aws
  # Allow the new user to log in
  - sed -i -e '$aAllowUsers ubuntu' /etc/ssh/sshd_config
  # Restart SSH service to apply new configuration
  - service ssh restart
