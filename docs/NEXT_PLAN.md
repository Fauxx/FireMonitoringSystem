# Next Plan (May 12, 2026)

## Goal
Complete the verification and cleanup for the layered Terraform setup with GitHub App auth, then confirm CI workflows are ready for use.

## Plan
1. Ensure GitHub Actions secrets are set (repo or environment secrets):
   - TF_VAR_github_app_id
   - TF_VAR_github_app_installation_id
   - TF_VAR_github_app_private_key (base64-encoded PEM)
   - TF_VAR_github_owner
   - TF_VAR_github_repo
   - TF_VAR_do_token
   - TF_VAR_ssh_key_ids
   - TF_VAR_do_ssh_host_fingerprint
   - TF_STATE_BUCKET / TF_STATE_REGION / TF_STATE_ENDPOINT / TF_STATE_ACCESS_KEY / TF_STATE_SECRET_KEY
2. Run dev plans with DO Spaces credentials in the environment:
   - export AWS_ACCESS_KEY_ID
   - export AWS_SECRET_ACCESS_KEY
   - terraform plan -input=false -var-file="terraform.tfvars" in dev/02-k8s-config
3. Repeat the plan for prod/02-k8s-config (same env credentials).
4. Optional: Update terraform_remote_state to use endpoints.s3 to remove deprecation warning.
5. Run CI workflow manually (terraform-infra.yml) in plan-only mode for dev, both layers.

## Expected Outcomes
- dev/prod 02-k8s-config plan succeeds and reads 01-infra state.
- CI workflow completes with GitHub App credentials only.
- No residual references to github_token remain in Terraform or CI.

## Notes
- terraform_remote_state does not read backend.conf; it uses environment/shared credentials.
- Keep backend.conf credentials private.
