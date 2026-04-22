## Plan: Restructure Terraform + CI/CD Pipelines

Refactor the repo into environment-driven Terraform roots and separated CI/CD workflows by responsibility: infrastructure (`terraform-infra`), image build/publish (`app-ci-build`), and server deployment (`app-cd-deploy`). Preserve current DigitalOcean + GitHub secret behavior, then migrate state/workflow contracts incrementally to avoid drift and broken automation while switching paths and triggers.

### Steps {3–6 steps, 5–20 words each}
1. Baseline current behavior from `.github/workflows/ci-pr.yml`, `.github/workflows/cd-main.yml`, `.github/workflows/infra.yml`, and `.github/workflows/terraform-execution.yml`.
2. Create Terraform structure under `infrastructure/terraform/modules/*` and `infrastructure/terraform/environments/{dev,prod}` from current root files.
3. Move `digitalocean_droplet.fire_core`, `digitalocean_firewall.fire_monitoring_fw`, and `github_actions_secret.*` into modules with stable outputs.
4. Wire `environments/dev/main.tf` and `environments/prod/main.tf` to module inputs (`region`, `droplet_size`, `ssh_key_ids`, `github_repo`).
5. Replace workflow layout with `.github/workflows/terraform-infra.yml`, `.github/workflows/app-ci-build.yml`, and `.github/workflows/app-cd-deploy.yml`.
6. Update reusable contract paths (`working_directory`) and docs in `README.md` for new env roots and promotion flow.

### Further Considerations {1–3, 5–25 words each}
1. How should state be split: one backend key per environment, or keep workspace suffixing too? Option A env-only / Option B env+workspace / Option C workspace-only.
2. Should `app-cd-deploy.yml` deploy to `dev` on branch pushes and `prod` on tags/manual approval? Option A branch-based / Option B tag-based / Option C manual-only.
3. I still see path inconsistency around `infrastructure/terraform`; confirm canonical location before execution. Option A same path / Option B moved path / Option C temporary sync issue.

