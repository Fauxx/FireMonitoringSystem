# Terraform State Migration Runbook

Use this runbook to migrate state from the legacy root layout to the new environment-rooted module layout without deleting live resources.

## Scope

Legacy addresses (previous root):

- `digitalocean_droplet.fire_core[0]`
- `digitalocean_firewall.fire_monitoring_fw`
- `github_actions_secret.do_ssh_host[0]`
- `github_actions_secret.do_ssh_fingerprint[0]`
- `github_actions_secret.do_ssh_port[0]`
- `github_actions_secret.do_ssh_user[0]`

New addresses (per environment root):

- `module.compute.digitalocean_droplet.this`
- `module.networking.digitalocean_firewall.this`
- `module.github_secrets.github_actions_secret.do_ssh_host[0]`
- `module.github_secrets.github_actions_secret.do_ssh_fingerprint[0]`
- `module.github_secrets.github_actions_secret.do_ssh_port[0]`
- `module.github_secrets.github_actions_secret.do_ssh_user[0]`

## Steps (repeat once per environment)

1. Back up current state.
2. Initialize the new environment root.
3. Move state addresses.
4. Run `terraform plan` and confirm no unexpected deletes.

Example for `prod`:

```bash
cd infrastructure/terraform/environments/prod
terraform init -backend-config=backend.conf
terraform state pull > state-backup-prod-$(date +%Y%m%d-%H%M%S).json
terraform state mv 'digitalocean_droplet.fire_core[0]' 'module.compute.digitalocean_droplet.this'
terraform state mv 'digitalocean_firewall.fire_monitoring_fw' 'module.networking.digitalocean_firewall.this'
terraform state mv 'github_actions_secret.do_ssh_host[0]' 'module.github_secrets.github_actions_secret.do_ssh_host[0]'
terraform state mv 'github_actions_secret.do_ssh_fingerprint[0]' 'module.github_secrets.github_actions_secret.do_ssh_fingerprint[0]'
terraform state mv 'github_actions_secret.do_ssh_port[0]' 'module.github_secrets.github_actions_secret.do_ssh_port[0]'
terraform state mv 'github_actions_secret.do_ssh_user[0]' 'module.github_secrets.github_actions_secret.do_ssh_user[0]'
terraform plan -input=false
```

If any `state mv` fails because the source is missing, inspect current addresses first:

```bash
terraform state list
```

