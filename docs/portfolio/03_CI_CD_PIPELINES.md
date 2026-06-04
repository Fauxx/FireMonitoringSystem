# Automated CI/CD Pipelines

The project implements a **High-Velocity CI/CD pipeline** that automates the transition from code commit to container deployment, ensuring consistency and safety through automated pull requests.

## 🏗️ Stage 1: Build & Containerization

Managed via GitHub Actions in `app-pipeline.yml`, this stage handles the creation of immutable artifacts.

### Key Features:
- **Matrix Builds:** Parallel execution for `api`, `dashboard`, and `etl-processor` to minimize pipeline latency.
- **Immutable Tagging:** Every image is tagged with the first 7 characters of its **Git SHA** (e.g., `api:0fb86d9`), preventing "latest" tag ambiguity and enabling easy rollbacks.
- **Multi-Registry Support:** Images are pushed to **GitHub Container Registry (GHCR)**.

## 🔄 Stage 2: GitOps Manifest Bumping

Instead of the CI pipeline directly modifying the cluster (which is a security risk), it uses an **indirect manifest-update pattern**:

1.  **Image Push:** The build job completes and outputs the new Git SHA tag.
2.  **Kustomize Edit:** A secondary job uses `kustomize edit set image` to update the `infrastructure/k8s/overlays/dev/kustomization.yaml` file with the new tag.
3.  **Automated Pull Request:** The pipeline uses a GitHub App token to create a Pull Request against the `main` branch with the manifest changes.
4.  **Promotion to Production:** On merge to `main`, a similar process triggers for the `prod` overlay, following a successful validation in dev.

## 🛡️ Pipeline Security & Optimization

- **GitHub App Authentication:** Uses fine-grained GitHub App tokens instead of personal access tokens (PATs), adhering to the principle of least privilege.
- **Path-Based Filtering:** Pipelines only trigger when changes are detected in the `apps/` directory or the workflow files themselves, saving GitHub Action minutes.
- **Environment Protection:** Production deployments require manual approval or a successful merge to the protected `main` branch.

## 🛠️ Verification & Quality Gates

Beyond building images, the pipeline infrastructure supports:
- **Linting & Validation:** Ensuring Kubernetes manifests are valid before they are even considered for deployment.
- **State Consistency:** The use of GitOps ensures that if a manual change is made to the cluster, the pipeline (via ArgoCD) will automatically revert it to the state defined in Git.
