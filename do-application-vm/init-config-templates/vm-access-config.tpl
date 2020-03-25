#cloud-config
merge_how:
 - name: list
   settings: [append]
 - name: dict
   settings: [no_replace, recurse_list]

runcmd:
  # Change the port the SSH daemon listens on (for security reasons)
  - sed -i -e '/^Port/s/^.*$/Port 4444/' /etc/ssh/sshd_config
  # Disallow root login
  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  # Restart SSH service to apply new configuration
  - service ssh restart
