#cloud-config
merge_how:
 - name: list
   settings: [append]
 - name: dict
   settings: [no_replace, recurse_list]

runcmd:
  - aws configure set default.region ${aws_region}
  - aws configure set aws_access_key_id ${aws_access_key_id}
  - aws configure set aws_secret_access_key ${aws_secret_access_key}
