# Terraform Layout

This Terraform layout is environment-rooted and module-driven:

- `modules/networking`: firewall and ingress rules
- `modules/compute`: droplet resources
- `modules/storage`: placeholder for future storage resources
- `modules/github-secrets`: GitHub Actions secret sync for deployment connection info
- `environments/dev`: dev root module
- `environments/prod`: prod root module

## State strategy

This repository uses environment-only state splitting:

- `environments/dev/terraform.tfstate`
- `environments/prod/terraform.tfstate`

`backend.conf` in each environment captures the key shape and backend settings contract.

## Local init and plan

```bash
cd infrastructure/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init -reconfigure -backend-config=backend.conf -backend-config="key=environments/dev/terraform.tfstate"
terraform validate
terraform plan -input=false
```

## Migration notes

To avoid accidental deletion while migrating existing state addresses, perform one environment at a time:

1. Backup current remote state.
2. Initialize target environment root.
3. Use `terraform state mv` from old root addresses to module addresses.
4. Run `terraform plan` and confirm zero/expected changes before apply.

