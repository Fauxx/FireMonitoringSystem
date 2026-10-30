"""
Tier 3: Cross-Feature Combinations & Pairwise Interactions Test Suite
Validates interface contracts, pipeline data flow, and target interactions
derived from PROJECT.md § Interface Contracts & TEST_INFRA.md.
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
    get_host_state_snapshot,
    WORKFLOWS_DIR,
    MAKEFILE_PATH,
    OVERLAYS_DIR,
)


class TestTier3Interactions(unittest.TestCase):
    """
    Tier 3 tests verify pairwise interactions and interface contracts
    between features as specified in PROJECT.md.
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
    # Pair 1: F1 (Kind Setup) + F8 (Kind Cleanup)
    # -------------------------------------------------------------------------
    def test_pairwise_f1_f8_cluster_lifecycle_guarantee(self):
        """F1 + F8: Ephemeral cluster setup is strictly paired with always cleanup."""
        smoke_job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        steps = get_job_steps(smoke_job)
        self.assertTrue(bool(steps), "k8s_smoke_test must contain steps.")

        setup_step = find_step(steps, uses_substr="kind-action")
        cleanup_step = find_step(steps, run_substr="kind delete cluster")

        self.assertIsNotNone(setup_step, "Setup step using kind-action must exist.")
        self.assertIsNotNone(cleanup_step, "Cleanup step executing kind delete cluster must exist.")

        setup_name = setup_step.get("with", {}).get("cluster_name", "")
        cleanup_run = str(cleanup_step.get("run", ""))

        self.assertIn(
            setup_name, cleanup_run,
            f"Cleanup step must delete the exact cluster '{setup_name}' created by setup step."
        )
        self.assertEqual(
            cleanup_step.get("if", "").strip(), "always()",
            "Cleanup step must run with 'if: always()' to guarantee teardown."
        )

    # -------------------------------------------------------------------------
    # Pair 2: F2 (GHCR Auth) + F3 (Image Pull / Tag)
    # -------------------------------------------------------------------------
    def test_pairwise_f2_f3_auth_to_image_pull_flow(self):
        """F2 + F3: Docker login precedes image pulling and matches registry."""
        smoke_job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        steps = get_job_steps(smoke_job)
        self.assertTrue(bool(steps), "k8s_smoke_test must contain steps.")

        login_step = find_step(steps, uses_substr="docker/login-action")
        load_step = find_step(steps, run_substr="kind load")

        self.assertIsNotNone(login_step, "Login step must be present.")
        self.assertIsNotNone(load_step, "Load images step must be present.")

        login_idx = steps.index(login_step)
        load_idx = steps.index(load_step)

        self.assertLess(
            login_idx, load_idx,
            "Docker login must precede image pulling and loading in step order."
        )

        registry = login_step.get("with", {}).get("registry", "")
        self.assertTrue(
            "${{ env.REGISTRY }}" in registry or "ghcr.io" in registry,
            "Login registry must target GHCR."
        )

    # -------------------------------------------------------------------------
    # Pair 3: F3 (Image Tagging) + F4 (Local Overlay Deployment)
    # -------------------------------------------------------------------------
    def test_pairwise_f3_f4_tag_remapping_matches_local_overlay(self):
        """F3 + F4: Images remapped to localhost/<svc>:local match overlay's imagePullPolicy: Never."""
        smoke_job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        steps = get_job_steps(smoke_job)
        self.assertTrue(bool(steps), "k8s_smoke_test must contain steps.")

        load_step = find_step(steps, run_substr="kind load")
        deploy_step = find_step(steps, run_substr="overlays/local")

        self.assertIsNotNone(load_step, "Load images step must exist.")
        self.assertIsNotNone(deploy_step, "Deploy overlay step must exist.")

        load_run = str(load_step.get("run", ""))
        self.assertTrue(
            "localhost" in load_run or "kind load docker-image" in load_run,
            "Images loaded into Kind must satisfy local overlay image names."
        )

        # Inspect local overlay kustomization
        kust_text = read_file_text(OVERLAYS_DIR / "local" / "kustomization.yaml")
        for svc in ["api", "dashboard", "etl-processor"]:
            self.assertIn(
                f"newName: localhost/{svc}",
                kust_text,
                f"Local overlay kustomization must rewrite image name to localhost/{svc}."
            )

    # -------------------------------------------------------------------------
    # Pair 4: F4 (Deploy Overlay) + F5 (Rollout Status Wait)
    # -------------------------------------------------------------------------
    def test_pairwise_f4_f5_deploy_precedes_rollout_in_same_namespace(self):
        """F4 + F5: Deployment precedes rollout wait and both target fire-monitoring-local."""
        smoke_job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        steps = get_job_steps(smoke_job)
        self.assertTrue(bool(steps), "k8s_smoke_test must contain steps.")

        deploy_step = find_step(steps, run_substr="overlays/local")
        rollout_step = find_step(steps, run_substr="rollout status")

        self.assertIsNotNone(deploy_step, "Deploy step must exist.")
        self.assertIsNotNone(rollout_step, "Rollout wait step must exist.")

        deploy_idx = steps.index(deploy_step)
        rollout_idx = steps.index(rollout_step)

        self.assertLess(
            deploy_idx, rollout_idx,
            "Local overlay deployment must precede rollout status check."
        )

        deploy_run = str(deploy_step.get("run", ""))
        rollout_run = str(rollout_step.get("run", ""))

        self.assertIn("fire-monitoring-local", deploy_run)
        self.assertIn("fire-monitoring-local", rollout_run)

    # -------------------------------------------------------------------------
    # Pair 5: F5 (Rollout Wait) + F6 (CrashLoopBackOff Gate)
    # -------------------------------------------------------------------------
    def test_pairwise_f5_f6_rollout_wait_to_crashloop_gate(self):
        """F5 + F6: Rollout wait passes unready pods to CrashLoopBackOff diagnostic gate."""
        smoke_job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        steps = get_job_steps(smoke_job)
        self.assertTrue(bool(steps), "k8s_smoke_test must contain steps.")

        rollout_step = find_step(steps, run_substr="rollout status")
        crash_step = find_step(steps, run_substr="CrashLoopBackOff")

        self.assertIsNotNone(rollout_step, "Rollout step must exist.")
        self.assertIsNotNone(crash_step, "CrashLoopBackOff check step must exist.")

        rollout_idx = steps.index(rollout_step)
        crash_idx = steps.index(crash_step)

        self.assertLess(
            rollout_idx, crash_idx,
            "Rollout wait must precede CrashLoopBackOff evaluation."
        )

        # Rollout must tolerate timeout so crash step can diagnose
        rollout_run = str(rollout_step.get("run", ""))
        self.assertTrue(
            "||" in rollout_run,
            "Rollout status must not abort workflow before CrashLoopBackOff analyzer can run."
        )

    # -------------------------------------------------------------------------
    # Pair 6: F6 (CrashLoop Gate) + F7 (API Health Probe)
    # -------------------------------------------------------------------------
    def test_pairwise_f6_f7_crashloop_precedes_health_probe(self):
        """F6 + F7: CrashLoopBackOff gating runs before or alongside API health probe."""
        smoke_job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        steps = get_job_steps(smoke_job)
        self.assertTrue(bool(steps), "k8s_smoke_test must contain steps.")

        crash_step = find_step(steps, run_substr="CrashLoopBackOff")
        health_step = find_step(steps, run_substr="port-forward")

        self.assertIsNotNone(crash_step, "Crash check step must exist.")
        self.assertIsNotNone(health_step, "API health step must exist.")

        crash_idx = steps.index(crash_step)
        health_idx = steps.index(health_step)

        self.assertLess(
            crash_idx, health_idx,
            "CrashLoopBackOff gate must execute before API health probe."
        )
        self.assertIs(
            health_step.get("continue-on-error"), True,
            "Health probe must have continue-on-error: true to avoid masking crash gating."
        )

    # -------------------------------------------------------------------------
    # Pair 7: F8 (Cleanup) + F9 (CI Gate Consolidation)
    # -------------------------------------------------------------------------
    def test_pairwise_f8_f9_cleanup_occurs_before_ci_gate_collects(self):
        """F8 + F9: Ephemeral cluster cleanup completes in smoke test before ci_gate aggregates."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        needs = ci_gate.get("needs", [])
        self.assertIn("k8s_smoke_test", needs, "ci_gate must depend on k8s_smoke_test.")

        smoke_job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        steps = get_job_steps(smoke_job)
        cleanup_step = find_step(steps, run_substr="kind delete cluster")
        self.assertIsNotNone(cleanup_step, "Cleanup step must be part of k8s_smoke_test.")

    # -------------------------------------------------------------------------
    # Pair 8: F1 (Smoke Test Job) + F9 (CI Gate Integration)
    # -------------------------------------------------------------------------
    def test_pairwise_f1_f9_smoke_test_linked_to_ci_gate(self):
        """F1 + F9: ci_gate verification script checks needs.k8s_smoke_test.result."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        steps = get_job_steps(ci_gate)
        verify_step = find_step(steps, name_substr="verify all ci checks")
        self.assertIsNotNone(verify_step, "ci_gate verification step must exist.")

        run_script = str(verify_step.get("run", ""))
        self.assertIn("needs.k8s_smoke_test.result", run_script)
        self.assertTrue(
            '[ "${{ needs.k8s_smoke_test.result }}" = "failure" ]' in run_script or
            '[ "${{ needs.k8s_smoke_test.result }}" == "failure" ]' in run_script
        )

    # -------------------------------------------------------------------------
    # Pair 9: F9 (CI Gate) + F10 (Notification Rebranding)
    # -------------------------------------------------------------------------
    def test_pairwise_f9_f10_gate_completion_triggers_notify(self):
        """F9 + F10: Notification workflow runs after pipeline completes on main."""
        on_clause = self.local_notify.get("on", {})
        wf_run = on_clause.get("workflow_run", {})
        workflows = wf_run.get("workflows", [])
        self.assertTrue(
            any("Application CI/CD" in w or "app-pipeline" in w for w in workflows),
            "local-cluster-notify.yml must trigger on Application CI/CD workflow."
        )

    # -------------------------------------------------------------------------
    # Pair 10: F10 (Commit Status) + F11 (Summary Table)
    # -------------------------------------------------------------------------
    def test_pairwise_f10_f11_commit_status_and_summary_sync(self):
        """F10 + F11: Both commit status and summary markdown rebrand in unison to GKE Dev cluster."""
        self.assertNotIn("Kind cluster", self.local_notify_text)
        self.assertNotIn("local Kind cluster", self.local_notify_text)
        self.assertIn("GKE Dev cluster", self.local_notify_text)

    # -------------------------------------------------------------------------
    # Pair 11: F12 (Makefile Baseline) + F13 (kind-up Deprecation)
    # -------------------------------------------------------------------------
    def test_pairwise_f12_f13_makefile_retains_all_stages_while_deprecating_kind_up(self):
        """F12 + F13: Makefile preserves all SDLC stages while adding deprecation banner to kind-up."""
        self.assertGreaterEqual(self.makefile_info.line_count, 350)
        self.assertIn("kind-up", self.makefile_info.targets)
        self.assertIn("dev-up", self.makefile_info.targets)
        self.assertIn("staging-up", self.makefile_info.targets)
        self.assertIn("prod-up", self.makefile_info.targets)

    # -------------------------------------------------------------------------
    # Pair 12: F13 (kind-up Deprecation) + F17 (kind-up-debug)
    # -------------------------------------------------------------------------
    def test_pairwise_f13_f17_kind_up_points_to_kind_up_debug(self):
        """F13 + F17: kind-up deprecation message explicitly points to kind-up-debug."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up", {}).get("recipes", []))
        self.assertIn("kind-up-debug", recipes)
        self.assertIn("kind-up-debug", self.makefile_info.targets)

    # -------------------------------------------------------------------------
    # Pair 13: F17 (kind-up-debug) + F18 (kind-down)
    # -------------------------------------------------------------------------
    def test_pairwise_f17_f18_debug_creation_to_down_lifecycle(self):
        """F17 + F18: kind-up-debug and kind-down use identical $(KIND_CLUSTER_NAME)."""
        debug_recipes = "\n".join(self.makefile_info.targets.get("kind-up-debug", {}).get("recipes", []))
        down_recipes = "\n".join(self.makefile_info.targets.get("kind-down", {}).get("recipes", []))
        self.assertIn("$(KIND_CLUSTER_NAME)", debug_recipes)
        self.assertIn("$(KIND_CLUSTER_NAME)", down_recipes)

    # -------------------------------------------------------------------------
    # Pair 14: F4 (Local Overlay) + F19 (Manifest Validation)
    # -------------------------------------------------------------------------
    def test_pairwise_f4_f19_local_overlay_validated_in_manifest_workflow(self):
        """F4 + F19: Manifest validation workflow validates local overlay."""
        steps = get_job_steps(get_workflow_job(self.k8s_manifest, "validate"))
        local_step = find_step(steps, run_substr="overlays/local")
        self.assertIsNotNone(local_step, "k8s-manifest-validation must validate overlays/local.")

    # -------------------------------------------------------------------------
    # Pair 15: F18 (kind-down) + F20 (Host State Invariance)
    # -------------------------------------------------------------------------
    def test_pairwise_f18_f20_kind_down_dry_run_preserves_host_clusters(self):
        """F18 + F20: make -n kind-down dry-run does not alter host Kind clusters."""
        code, out, err = run_make_dry_run("kind-down")
        self.assertEqual(code, 0, f"make -n kind-down failed: {err}")

        current_clusters = get_host_kind_clusters()
        self.assertEqual(
            self.initial_host_state["clusters"], current_clusters,
            "Host clusters changed after kind-down dry run!"
        )


if __name__ == "__main__":
    unittest.main()
