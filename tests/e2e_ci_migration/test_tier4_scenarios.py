"""
Tier 4: Real-World Application Scenarios Test Suite (5 End-to-End Scenarios)
Validates complete user, developer, and CI/CD lifecycle workflows
derived from TEST_INFRA.md § Real-World Application Scenarios.
"""

import re
import unittest
from pathlib import Path

from tests.e2e_ci_migration.helpers import (
    REPO_ROOT,
    load_workflow,
    read_file_text,
    get_workflow_job,
    get_job_steps,
    find_step,
    parse_makefile,
    run_make_dry_run,
    run_kustomize_build,
    get_host_kind_clusters,
    get_host_docker_containers,
    get_host_state_snapshot,
    WORKFLOWS_DIR,
    MAKEFILE_PATH,
    OVERLAYS_DIR,
)


class TestTier4RealWorldScenarios(unittest.TestCase):
    """
    Tier 4 tests verify full end-to-end scenarios reflecting realistic workloads,
    developer migration behaviors, and production gate invariants.
    """

    @classmethod
    def setUpClass(cls):
        cls.app_pipeline = load_workflow("app-pipeline.yml")
        cls.local_notify = load_workflow("local-cluster-notify.yml")
        cls.local_notify_text = read_file_text(WORKFLOWS_DIR / "local-cluster-notify.yml")
        cls.k8s_manifest = load_workflow("k8s-manifest-validation.yml")
        cls.makefile_info = parse_makefile()
        cls.initial_host_state = get_host_state_snapshot()

    # -------------------------------------------------------------------------
    # Scenario 1: PR CI Workflow Lifecycle Simulation (F1 - F9)
    # -------------------------------------------------------------------------
    def test_scenario1_pr_workflow_lifecycle_simulation(self):
        """
        Scenario 1: Full Pull Request CI Workflow Lifecycle Simulation
        Verifies execution graph, stage order, and gating from PR trigger to CI gate.
        """
        jobs = self.app_pipeline.get("jobs", {})

        # Step 1: Trigger validation
        on_clause = self.app_pipeline.get("on", {})
        pr_paths = on_clause.get("pull_request", {}).get("paths", [])
        self.assertIn("apps/**", pr_paths, "PR trigger must watch apps/**.")
        self.assertIn(".github/workflows/app-pipeline.yml", pr_paths)

        # Step 2: Job dependency graph sequence:
        # detect_changes -> test -> build_scan_push -> k8s_smoke_test -> ci_gate
        self.assertIn("detect_changes", jobs)
        self.assertIn("test", jobs)
        self.assertIn("build_scan_push", jobs)
        self.assertIn("k8s_smoke_test", jobs, "Job k8s_smoke_test must be in jobs.")
        self.assertIn("ci_gate", jobs)

        smoke_job = jobs.get("k8s_smoke_test", {})
        smoke_needs = smoke_job.get("needs", [])
        self.assertIn("detect_changes", smoke_needs)
        self.assertIn("build_scan_push", smoke_needs)

        ci_gate_job = jobs.get("ci_gate", {})
        ci_gate_needs = ci_gate_job.get("needs", [])
        self.assertIn("k8s_smoke_test", ci_gate_needs)

        # Step 3: Verify PR push condition in build_scan_push (no push on PRs)
        bld_steps = get_job_steps(jobs.get("build_scan_push", {}))
        push_step = find_step(bld_steps, name_substr="push container image")
        push_cond = str(push_step.get("with", {}).get("push", "")) if push_step else ""
        self.assertIn("refs/heads/main", push_cond, "Images must not be pushed on PR branches.")

        # Step 4: Verify k8s_smoke_test steps execution order
        smoke_steps = get_job_steps(smoke_job)
        self.assertTrue(bool(smoke_steps), "k8s_smoke_test must have steps.")

        step_names = [str(s.get("name", "")).lower() for s in smoke_steps]
        create_idx = next((i for i, n in enumerate(step_names) if "kind" in n and "create" in n), -1)
        login_idx = next((i for i, n in enumerate(step_names) if "ghcr" in n or "login" in n), -1)
        load_idx = next((i for i, n in enumerate(step_names) if "load" in n), -1)
        deploy_idx = next((i for i, n in enumerate(step_names) if "deploy" in n), -1)
        rollout_idx = next((i for i, n in enumerate(step_names) if "wait" in n or "rollout" in n), -1)
        health_idx = next((i for i, n in enumerate(step_names) if "pod" in n or "crash" in n), -1)
        cleanup_idx = next((i for i, n in enumerate(step_names) if "delete" in n or "cleanup" in n), -1)

        self.assertTrue(create_idx < login_idx < load_idx < deploy_idx < rollout_idx < health_idx < cleanup_idx,
                        "k8s_smoke_test steps must follow proper lifecycle ordering.")

        # Step 5: Verify post-gate stages deploy_dev and promote_prod are skipped on PRs
        deploy_dev = jobs.get("deploy_dev", {})
        promote_prod = jobs.get("promote_prod", {})
        self.assertIn("refs/heads/main", str(deploy_dev.get("if", "")))
        self.assertIn("refs/tags/v", str(promote_prod.get("if", "")))

    # -------------------------------------------------------------------------
    # Scenario 2: Main Branch Promotion & Rebranding Sync (F9, F10, F11)
    # -------------------------------------------------------------------------
    def test_scenario2_main_branch_promotion_and_rebranding(self):
        """
        Scenario 2: Main Branch Merge, Dev Deployment & Notification Rebranding Sync
        Verifies end-to-end sync between pipeline completion and GKE Dev cluster status.
        """
        # Step 1: Pipeline push to main triggers
        on_clause = self.app_pipeline.get("on", {})
        push_branches = on_clause.get("push", {}).get("branches", [])
        self.assertIn("main", push_branches)

        # Step 2: deploy_dev commits to overlays/dev
        deploy_dev = get_workflow_job(self.app_pipeline, "deploy_dev")
        dev_steps = get_job_steps(deploy_dev)
        gitops_step = find_step(dev_steps, run_substr="kustomize edit set image")
        self.assertIsNotNone(gitops_step, "deploy_dev must contain a step setting image tags via kustomize.")
        run_script = str(gitops_step.get("run", ""))
        self.assertIn("infrastructure/k8s/overlays/dev", run_script)

        # Step 3: local-cluster-notify triggers after pipeline
        notify_on = self.local_notify.get("on", {})
        wf_run = notify_on.get("workflow_run", {})
        self.assertIn("main", wf_run.get("branches", []))
        self.assertEqual(wf_run.get("types", []), ["completed"])

        # Step 4: Rebranding verification
        # Commit status
        self.assertNotIn("Kind cluster", self.local_notify_text)
        self.assertIn("GKE Dev cluster", self.local_notify_text)

        # Markdown summary check run
        self.assertIn("fire-monitoring-dev", self.local_notify_text)
        self.assertIn("namespace on GKE Dev cluster", self.local_notify_text)

    # -------------------------------------------------------------------------
    # Scenario 3: Developer Local Workflow Migration (F12 - F18)
    # -------------------------------------------------------------------------
    def test_scenario3_developer_local_migration_commands(self):
        """
        Scenario 3: Developer Local Workflow Migration
        Verifies developer interaction with Makefile: dev-up, kind-up deprecation,
        kind-up-debug, and kind-down.
        """
        # Step 1: Developer runs make help
        code, out, err = run_make_dry_run("help")
        self.assertEqual(code, 0, f"make -n help failed: {err}")

        # Step 2: Developer runs make dev-up (primary daily dev tool)
        code, out, err = run_make_dry_run("dev-up")
        self.assertEqual(code, 0, f"make -n dev-up failed: {err}")
        self.assertTrue("docker compose" in out or "docker-compose" in out)

        # Step 3: Developer runs legacy make kind-up and receives guidance
        code, out, err = run_make_dry_run("kind-up")
        self.assertEqual(code, 0, f"make -n kind-up failed: {err}")
        recipes = "\n".join(self.makefile_info.targets.get("kind-up", {}).get("recipes", []))
        self.assertIn("dev-up", recipes)
        self.assertIn("kind-up-debug", recipes)

        # Step 4: Developer runs make kind-up-debug for manual troubleshooting
        code, out, err = run_make_dry_run("kind-up-debug")
        self.assertEqual(code, 0, f"make -n kind-up-debug failed: {err}")
        debug_recipes = "\n".join(self.makefile_info.targets.get("kind-up-debug", {}).get("recipes", []))
        self.assertIn("kind create cluster", debug_recipes)

        # Step 5: Developer runs make kind-down to tear down
        code, out, err = run_make_dry_run("kind-down")
        self.assertEqual(code, 0, f"make -n kind-down failed: {err}")
        down_recipes = "\n".join(self.makefile_info.targets.get("kind-down", {}).get("recipes", []))
        self.assertIn("kind delete cluster", down_recipes)

    # -------------------------------------------------------------------------
    # Scenario 4: Host Machine Invariant Audit During SDLC (F18, F20)
    # -------------------------------------------------------------------------
    def test_scenario4_host_safety_audit(self):
        """
        Scenario 4: Host Machine Invariant Audit
        Verifies that no host Kind clusters or Docker containers were altered
        across testing and make evaluations.
        """
        current_state = get_host_state_snapshot()

        # Clusters invariance
        self.assertEqual(
            self.initial_host_state["clusters"], current_state["clusters"],
            "Host Kind cluster list was altered!"
        )
        self.assertEqual(
            self.initial_host_state["clusters_hash"], current_state["clusters_hash"],
            "Host Kind cluster state hash mismatch!"
        )

        # Containers invariance
        self.assertEqual(
            self.initial_host_state["containers"], current_state["containers"],
            "Host Docker container list was altered!"
        )
        self.assertEqual(
            self.initial_host_state["containers_hash"], current_state["containers_hash"],
            "Host Docker container state hash mismatch!"
        )

    # -------------------------------------------------------------------------
    # Scenario 5: Full Repository Manifest & Makefile Validation Suite
    # -------------------------------------------------------------------------
    def test_scenario5_full_repository_manifest_and_makefile_audit(self):
        """
        Scenario 5: Full Manifest & Makefile Target Dry-Run Audit
        Verifies that all Kustomize overlays build cleanly and Makefile ci-validate passes.
        """
        # Validate overlays
        for overlay in ["dev", "prod", "local"]:
            code, out, err = run_kustomize_build(overlay)
            self.assertEqual(
                code, 0,
                f"Kustomize build failed for overlay '{overlay}': {err}"
            )

        # Validate Makefile ci-validate target
        code, out, err = run_make_dry_run("ci-validate")
        self.assertEqual(
            code, 0,
            f"make -n ci-validate failed: {err}"
        )


if __name__ == "__main__":
    unittest.main()
