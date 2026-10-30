"""
Tier 1: Feature Coverage Test Suite (20 Features x 5 Test Cases = 100 Tests)
Opaque-box, requirement-driven tests derived from PROJECT.md & ORIGINAL_REQUEST.md.
"""

import re
import unittest
from pathlib import Path
from typing import Dict, Any

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


class TestTier1FeatureCoverage(unittest.TestCase):
    """
    Tier 1 tests verify happy-path, syntax, schema, structure, target commands,
    and exit codes for all 20 features in PROJECT.md Feature Inventory.
    """

    @classmethod
    def setUpClass(cls):
        # Cache loaded files
        cls.app_pipeline = load_workflow("app-pipeline.yml")
        cls.local_notify = load_workflow("local-cluster-notify.yml")
        cls.local_notify_text = read_file_text(WORKFLOWS_DIR / "local-cluster-notify.yml")
        cls.k8s_manifest = load_workflow("k8s-manifest-validation.yml")
        cls.makefile_info = parse_makefile()
        cls.initial_host_state = get_host_state_snapshot()

    # =========================================================================
    # FEATURE 1: Ephemeral Kind Cluster Setup (app-pipeline.yml)
    # =========================================================================

    def test_f1_01_smoke_test_job_present(self):
        """F1.1: Verify k8s_smoke_test job is declared in app-pipeline.yml."""
        jobs = self.app_pipeline.get("jobs", {})
        self.assertIn(
            "k8s_smoke_test",
            jobs,
            "Job 'k8s_smoke_test' must be defined in app-pipeline.yml per Feature 1."
        )

    def test_f1_02_runner_is_ubuntu_latest(self):
        """F1.2: Verify k8s_smoke_test runs on ubuntu-latest."""
        job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        self.assertEqual(
            job.get("runs-on"),
            "ubuntu-latest",
            "k8s_smoke_test must run on ubuntu-latest runner."
        )

    def test_f1_03_uses_kind_action(self):
        """F1.3: Verify Kind cluster step uses helm/kind-action."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="kind-action")
        self.assertIsNotNone(
            step,
            "k8s_smoke_test must contain a step using helm/kind-action@v1."
        )

    def test_f1_04_cluster_name_configured(self):
        """F1.4: Verify Kind cluster has dedicated name (e.g. ci-smoke-test)."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="kind-action")
        with_params = step.get("with", {}) if step else {}
        cluster_name = with_params.get("cluster_name", "")
        self.assertTrue(
            bool(cluster_name),
            "Kind step must configure cluster_name (e.g., ci-smoke-test)."
        )

    def test_f1_05_cluster_wait_bounded(self):
        """F1.5: Verify Kind cluster creation includes wait timeout."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="kind-action")
        with_params = step.get("with", {}) if step else {}
        wait_val = with_params.get("wait", "")
        self.assertTrue(
            bool(wait_val),
            "Kind step must configure wait parameter (e.g., 60s)."
        )

    # =========================================================================
    # FEATURE 2: GHCR Docker Authentication (app-pipeline.yml)
    # =========================================================================

    def test_f2_01_login_step_present(self):
        """F2.1: Verify Docker login step exists in k8s_smoke_test."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="docker/login-action")
        self.assertIsNotNone(
            step,
            "k8s_smoke_test must contain a docker/login-action step for GHCR."
        )

    def test_f2_02_login_uses_ghcr_registry(self):
        """F2.2: Verify login step registry targets GHCR."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="docker/login-action")
        registry = step.get("with", {}).get("registry", "") if step else ""
        self.assertTrue(
            "${{ env.REGISTRY }}" in registry or "ghcr.io" in registry,
            f"Login step registry must target GHCR (got: {registry})."
        )

    def test_f2_03_login_username_is_actor(self):
        """F2.3: Verify login step username uses github.actor."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="docker/login-action")
        username = step.get("with", {}).get("username", "") if step else ""
        self.assertIn(
            "github.actor",
            username,
            "Login step username must reference github.actor."
        )

    def test_f2_04_login_password_uses_token(self):
        """F2.4: Verify login step password uses secrets.GITHUB_TOKEN."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="docker/login-action")
        password = step.get("with", {}).get("password", "") if step else ""
        self.assertIn(
            "secrets.GITHUB_TOKEN",
            password,
            "Login step password must reference secrets.GITHUB_TOKEN."
        )

    def test_f2_05_job_login_precedes_image_loading(self):
        """F2.5: Verify GHCR login step precedes image load step."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        login_idx = -1
        load_idx = -1
        for idx, s in enumerate(steps):
            if "docker/login-action" in str(s.get("uses", "")):
                login_idx = idx
            if "kind load" in str(s.get("run", "")).lower() or "load images" in str(s.get("name", "")).lower():
                load_idx = idx
        self.assertTrue(
            login_idx != -1 and load_idx != -1 and login_idx < load_idx,
            "GHCR login step must execute before loading images into Kind."
        )

    # =========================================================================
    # FEATURE 3: Image Pull & Local Tagging (app-pipeline.yml)
    # =========================================================================

    def test_f3_01_load_images_step_present(self):
        """F3.1: Verify Load Images step is present in k8s_smoke_test."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, name_substr="load images", run_substr="kind load")
        self.assertIsNotNone(
            step,
            "k8s_smoke_test must contain an image loading step."
        )

    def test_f3_02_reads_image_tag_from_upstream(self):
        """F3.2: Verify image loading step references build_scan_push image_tag output."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind load")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "needs.build_scan_push.outputs.image_tag",
            run_script,
            "Image loading step must retrieve TAG from needs.build_scan_push.outputs.image_tag."
        )

    def test_f3_03_iterates_changed_services(self):
        """F3.3: Verify image loading iterates over detect_changes services."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind load")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "needs.detect_changes.outputs.services",
            run_script,
            "Image loading step must iterate over services from needs.detect_changes.outputs.services."
        )

    def test_f3_04_tags_or_loads_for_local_overlay(self):
        """F3.4: Verify images are mapped to localhost/<svc>:local or loaded directly into Kind."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind load")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "localhost" in run_script or "kind load docker-image" in run_script,
            "Images must be mapped for local overlay compatibility or loaded into Kind."
        )

    def test_f3_05_executes_kind_load_docker_image(self):
        """F3.5: Verify image loading executes 'kind load docker-image'."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind load")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "kind load docker-image",
            run_script,
            "Step must execute 'kind load docker-image'."
        )

    # =========================================================================
    # FEATURE 4: Local Overlay Kustomize Deployment (app-pipeline.yml)
    # =========================================================================

    def test_f4_01_deploy_step_present(self):
        """F4.1: Verify Deploy Local Overlay step is defined."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, name_substr="deploy local overlay", run_substr="overlays/local")
        self.assertIsNotNone(
            step,
            "k8s_smoke_test must contain a step deploying infrastructure/k8s/overlays/local."
        )

    def test_f4_02_creates_local_namespace(self):
        """F4.2: Verify step creates fire-monitoring-local namespace idempotently."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="overlays/local")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "fire-monitoring-local",
            run_script,
            "Deploy step must target namespace fire-monitoring-local."
        )

    def test_f4_03_prepares_secrets_stub(self):
        """F4.3: Verify step ensures secrets.yaml stub exists before applying."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="overlays/local")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "secrets.yaml",
            run_script,
            "Deploy step must verify or stub secrets.yaml for overlays/local."
        )

    def test_f4_04_applies_kustomize_local_overlay(self):
        """F4.4: Verify step applies overlay via kubectl apply -k."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="overlays/local")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "kubectl apply -k" in run_script and "overlays/local" in run_script,
            "Deploy step must run 'kubectl apply -k infrastructure/k8s/overlays/local'."
        )

    def test_f4_05_local_kustomize_manifest_valid(self):
        """F4.5: Verify local overlay builds successfully with kustomize on host."""
        exit_code, stdout, stderr = run_kustomize_build("local")
        self.assertEqual(
            exit_code, 0,
            f"kustomize build infrastructure/k8s/overlays/local failed: {stderr}"
        )

    # =========================================================================
    # FEATURE 5: Core Deployment Rollout Wait (app-pipeline.yml)
    # =========================================================================

    def test_f5_01_rollout_step_present(self):
        """F5.1: Verify Wait for Core Pods step exists in k8s_smoke_test."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, name_substr="wait for core", run_substr="rollout status")
        self.assertIsNotNone(
            step,
            "k8s_smoke_test must contain a step waiting for core deployment rollouts."
        )

    def test_f5_02_targets_api_deployment(self):
        """F5.2: Verify rollout status waits on deployment/api."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="rollout status")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "api",
            run_script,
            "Rollout wait step must check deployment/api."
        )

    def test_f5_03_targets_dashboard_deployment(self):
        """F5.3: Verify rollout status waits on deployment/dashboard."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="rollout status")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "dashboard",
            run_script,
            "Rollout wait step must check deployment/dashboard."
        )

    def test_f5_04_targets_etl_deployment(self):
        """F5.4: Verify rollout status waits on deployment/etl-processor."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="rollout status")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "etl-processor",
            run_script,
            "Rollout wait step must check deployment/etl-processor."
        )

    def test_f5_05_rollout_timeout_specified(self):
        """F5.5: Verify rollout status command specifies timeout (e.g. --timeout=120s)."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="rollout status")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "--timeout=",
            run_script,
            "Rollout status command must define a bounded --timeout."
        )

    # =========================================================================
    # FEATURE 6: Pod CrashLoopBackOff Gating (app-pipeline.yml)
    # =========================================================================

    def test_f6_01_verify_health_step_present(self):
        """F6.1: Verify step checking Pod Health / CrashLoopBackOff exists."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, name_substr="verify pod health", run_substr="CrashLoopBackOff")
        self.assertIsNotNone(
            step,
            "k8s_smoke_test must contain a step verifying pod health."
        )

    def test_f6_02_queries_crashloopbackoff_jsonpath(self):
        """F6.2: Verify step queries CrashLoopBackOff reason via JSONPath."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="CrashLoopBackOff")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "jsonpath=" in run_script and "CrashLoopBackOff" in run_script,
            "Health check step must query containerStatuses for CrashLoopBackOff via jsonpath."
        )

    def test_f6_03_evaluates_crash_count_greater_than_zero(self):
        """F6.3: Verify step evaluates crash count > 0."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="CrashLoopBackOff")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "-gt 0" in run_script or "> 0" in run_script,
            "Health check step must test if crash count exceeds 0."
        )

    def test_f6_04_dumps_logs_on_crash(self):
        """F6.4: Verify step dumps logs when pods are crashing."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="CrashLoopBackOff")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "kubectl logs",
            run_script,
            "Health check step must dump kubectl logs on failure."
        )

    def test_f6_05_exits_with_code_one_on_crash(self):
        """F6.5: Verify step explicitly exits with code 1 on crash detection."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="CrashLoopBackOff")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "exit 1",
            run_script,
            "Health check step must exit with code 1 if crashes are found."
        )

    # =========================================================================
    # FEATURE 7: In-Cluster API Health Probe (app-pipeline.yml)
    # =========================================================================

    def test_f7_01_api_health_step_present(self):
        """F7.1: Verify API Health Check step exists."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, name_substr="api health check", run_substr="port-forward")
        self.assertIsNotNone(
            step,
            "k8s_smoke_test must contain an API health check step."
        )

    def test_f7_02_port_forward_to_svc_api(self):
        """F7.2: Verify step port-forwards to svc/api."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="port-forward")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "svc/api",
            run_script,
            "Health check must port-forward to svc/api."
        )

    def test_f7_03_probes_health_endpoint(self):
        """F7.3: Verify probe requests /health endpoint."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="port-forward")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "curl" in run_script and "/health" in run_script,
            "Health probe step must curl the /health endpoint."
        )

    def test_f7_04_kills_port_forward_process(self):
        """F7.4: Verify step terminates background port-forward process."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="port-forward")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "kill" in run_script,
            "Step must terminate the background port-forward process."
        )

    def test_f7_05_continue_on_error_configured(self):
        """F7.5: Verify health check step has continue-on-error configured."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="port-forward")
        continue_flag = step.get("continue-on-error") if step else None
        self.assertEqual(
            continue_flag, True,
            "API Health Check step must have continue-on-error: true."
        )

    # =========================================================================
    # FEATURE 8: Guaranteed Kind Cleanup (app-pipeline.yml)
    # =========================================================================

    def test_f8_01_cleanup_step_present(self):
        """F8.1: Verify Delete Kind Cluster cleanup step exists."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, name_substr="delete kind cluster", run_substr="kind delete cluster")
        self.assertIsNotNone(
            step,
            "k8s_smoke_test must contain a cluster deletion cleanup step."
        )

    def test_f8_02_cleanup_uses_if_always(self):
        """F8.2: Verify cleanup step executes under if: always()."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind delete cluster")
        if_cond = step.get("if", "") if step else ""
        self.assertEqual(
            if_cond, "always()",
            "Kind cleanup step must specify 'if: always()'."
        )

    def test_f8_03_cleanup_runs_kind_delete_command(self):
        """F8.3: Verify cleanup runs 'kind delete cluster'."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind delete cluster")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "kind delete cluster",
            run_script,
            "Cleanup step must execute 'kind delete cluster'."
        )

    def test_f8_04_cleanup_specifies_cluster_name(self):
        """F8.4: Verify cleanup targets the specific smoke test cluster name."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind delete cluster")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "--name",
            run_script,
            "Cleanup command must pass --name with the cluster name."
        )

    def test_f8_05_cleanup_is_final_step(self):
        """F8.5: Verify cleanup is the last step in k8s_smoke_test."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        self.assertTrue(bool(steps), "k8s_smoke_test must have steps.")
        last_step = steps[-1]
        self.assertIn(
            "kind delete cluster",
            str(last_step.get("run", "")),
            "The final step of k8s_smoke_test must be cluster deletion."
        )

    # =========================================================================
    # FEATURE 9: Consolidated CI Gate Integration (app-pipeline.yml)
    # =========================================================================

    def test_f9_01_ci_gate_needs_includes_smoke_test(self):
        """F9.1: Verify ci_gate needs list includes k8s_smoke_test."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        needs = ci_gate.get("needs", [])
        self.assertIn(
            "k8s_smoke_test",
            needs,
            "ci_gate job must list 'k8s_smoke_test' in its needs dependencies."
        )

    def test_f9_02_ci_gate_echoes_smoke_test_status(self):
        """F9.2: Verify ci_gate script displays k8s_smoke_test status."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        steps = get_job_steps(ci_gate)
        verify_step = find_step(steps, name_substr="verify all ci checks")
        run_script = verify_step.get("run", "") if verify_step else ""
        self.assertIn(
            "needs.k8s_smoke_test.result",
            run_script,
            "ci_gate script must echo needs.k8s_smoke_test.result."
        )

    def test_f9_03_ci_gate_evaluates_smoke_test_failure(self):
        """F9.3: Verify ci_gate fails if k8s_smoke_test.result == 'failure'."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        steps = get_job_steps(ci_gate)
        verify_step = find_step(steps, name_substr="verify all ci checks")
        run_script = verify_step.get("run", "") if verify_step else ""
        self.assertTrue(
            'needs.k8s_smoke_test.result' in run_script and 'failure' in run_script,
            "ci_gate verification script must check for k8s_smoke_test failure."
        )

    def test_f9_04_ci_gate_runs_if_always(self):
        """F9.4: Verify ci_gate has if: always() to collect statuses."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        self.assertEqual(
            ci_gate.get("if"), "always()",
            "ci_gate job must execute under 'if: always()'."
        )

    def test_f9_05_ci_gate_preserves_other_checks(self):
        """F9.5: Verify ci_gate retains detect_changes, test, and build_scan_push."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        needs = ci_gate.get("needs", [])
        for required in ["detect_changes", "test", "build_scan_push"]:
            self.assertIn(
                required, needs,
                f"ci_gate must retain '{required}' in its needs list."
            )

    # =========================================================================
    # FEATURE 10: Commit Status Rebranding (local-cluster-notify.yml)
    # =========================================================================

    def test_f10_01_notify_workflow_exists(self):
        """F10.1: Verify local-cluster-notify.yml exists and parses."""
        self.assertIsNotNone(
            self.local_notify,
            "local-cluster-notify.yml must exist and be valid YAML."
        )

    def test_f10_02_commit_status_no_kind_cluster(self):
        """F10.2: Verify commit status description does not mention 'Kind cluster'."""
        # Find commit status block around line 57
        match = re.search(r"createCommitStatus\(\{.*?description:\s*`([^`]+)`", self.local_notify_text, re.DOTALL)
        self.assertIsNotNone(match, "createCommitStatus block must be present.")
        desc = match.group(1)
        self.assertNotIn(
            "Kind cluster", desc,
            f"Commit status description must NOT refer to 'Kind cluster' (found: '{desc}')."
        )

    def test_f10_03_commit_status_mentions_gke_dev(self):
        """F10.3: Verify commit status description mentions 'GKE Dev cluster'."""
        match = re.search(r"createCommitStatus\(\{.*?description:\s*`([^`]+)`", self.local_notify_text, re.DOTALL)
        self.assertIsNotNone(match, "createCommitStatus block must be present.")
        desc = match.group(1)
        self.assertIn(
            "GKE Dev cluster", desc,
            f"Commit status description must refer to 'GKE Dev cluster' (found: '{desc}')."
        )

    def test_f10_04_commit_status_context_preserved(self):
        """F10.4: Verify commit status context remains 'gitops / argocd-sync-queued'."""
        self.assertIn(
            "gitops / argocd-sync-queued",
            self.local_notify_text,
            "Commit status context must remain 'gitops / argocd-sync-queued'."
        )

    def test_f10_05_commit_status_state_success(self):
        """F10.5: Verify commit status state is 'success'."""
        self.assertIn(
            "state: 'success'",
            self.local_notify_text,
            "Commit status state must be 'success'."
        )

    # =========================================================================
    # FEATURE 11: Summary Table Rebranding (local-cluster-notify.yml)
    # =========================================================================

    def test_f11_01_summary_table_no_local_kind(self):
        """F11.1: Verify check run summary does not mention 'local Kind cluster'."""
        self.assertNotIn(
            "local Kind cluster",
            self.local_notify_text,
            "Summary check run output must NOT mention 'local Kind cluster'."
        )

    def test_f11_02_summary_table_mentions_gke_dev(self):
        """F11.2: Verify check run summary mentions 'GKE Dev cluster'."""
        self.assertIn(
            "GKE Dev cluster",
            self.local_notify_text,
            "Summary check run output must mention 'GKE Dev cluster'."
        )

    def test_f11_03_argocd_target_rebranded(self):
        """F11.3: Verify ArgoCD Target row mentions GKE Dev cluster."""
        match = re.search(r"\|\s*\*\*ArgoCD Target\*\*\s*\|\s*(.*?)\s*\|", self.local_notify_text)
        self.assertIsNotNone(match, "ArgoCD Target row must exist in summary table.")
        val = match.group(1)
        self.assertIn(
            "GKE Dev cluster", val,
            f"ArgoCD Target row must reference 'GKE Dev cluster' (got: '{val}')."
        )

    def test_f11_04_what_happens_next_rebranded(self):
        """F11.4: Verify What Happens Next section mentions GKE Dev cluster."""
        match = re.search(r"ArgoCD.*?\((?:running in your )?([^)]+)\)", self.local_notify_text)
        self.assertIsNotNone(match, "ArgoCD host mention must exist in What Happens Next.")
        val = match.group(1)
        self.assertNotIn("Kind", val, "ArgoCD parenthetical must not state Kind cluster.")

    def test_f11_05_check_run_title_intact(self):
        """F11.5: Verify check run title and heading structure intact."""
        self.assertIn(
            "Deployed ${shortSha} → fire-monitoring-dev",
            self.local_notify_text,
            "Check run title must target fire-monitoring-dev."
        )

    # =========================================================================
    # FEATURE 12: Makefile Baseline Reconciliation (Makefile)
    # =========================================================================

    def test_f12_01_makefile_line_count(self):
        """F12.1: Verify Makefile contains full baseline (>= 350 lines)."""
        self.assertGreaterEqual(
            self.makefile_info.line_count, 350,
            f"Makefile is truncated ({self.makefile_info.line_count} lines). Must preserve full baseline (>= 350 lines)."
        )

    def test_f12_02_dev_targets_present(self):
        """F12.2: Verify dev-up, dev-down, dev-logs are present."""
        for target in ["dev-up", "dev-down", "dev-logs"]:
            self.assertIn(
                target, self.makefile_info.targets,
                f"Target '{target}' must be present in Makefile."
            )

    def test_f12_03_staging_targets_present(self):
        """F12.3: Verify staging-up, staging-down, staging-sync are present."""
        for target in ["staging-up", "staging-down", "staging-sync"]:
            self.assertIn(
                target, self.makefile_info.targets,
                f"Target '{target}' must be present in Makefile per SDLC baseline."
            )

    def test_f12_04_prod_targets_present(self):
        """F12.4: Verify prod-up, prod-down are present."""
        for target in ["prod-up", "prod-down"]:
            self.assertIn(
                target, self.makefile_info.targets,
                f"Target '{target}' must be present in Makefile."
            )

    def test_f12_05_utility_targets_present(self):
        """F12.5: Verify ci-validate, status, clean are present."""
        for target in ["ci-validate", "status", "clean"]:
            self.assertIn(
                target, self.makefile_info.targets,
                f"Target '{target}' must be present in Makefile."
            )

    # =========================================================================
    # FEATURE 13: Makefile kind-up Deprecation (Makefile)
    # =========================================================================

    def test_f13_01_kind_up_target_present(self):
        """F13.1: Verify kind-up target is present in Makefile."""
        self.assertIn(
            "kind-up", self.makefile_info.targets,
            "Target 'kind-up' must be present in Makefile."
        )

    def test_f13_02_kind_up_deprecation_banner(self):
        """F13.2: Verify kind-up recipe displays deprecation warning."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up", {}).get("recipes", []))
        self.assertTrue(
            "DEPRECATION" in recipes.upper() or "DEPRECATED" in recipes.upper() or "⚠️" in recipes,
            "Target 'kind-up' recipe must contain a visible deprecation warning."
        )

    def test_f13_03_kind_up_points_to_dev_up(self):
        """F13.3: Verify kind-up deprecation message directs to 'make dev-up'."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up", {}).get("recipes", []))
        self.assertIn(
            "dev-up", recipes,
            "Target 'kind-up' deprecation notice must recommend 'make dev-up'."
        )

    def test_f13_04_kind_up_points_to_kind_up_debug(self):
        """F13.4: Verify kind-up deprecation message directs to 'make kind-up-debug'."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up", {}).get("recipes", []))
        self.assertIn(
            "kind-up-debug", recipes,
            "Target 'kind-up' deprecation notice must recommend 'make kind-up-debug' for debugging."
        )

    def test_f13_05_kind_up_in_phony(self):
        """F13.5: Verify kind-up is declared in .PHONY."""
        self.assertIn(
            "kind-up", self.makefile_info.phony_targets,
            "Target 'kind-up' must be declared in .PHONY."
        )

    # =========================================================================
    # FEATURE 14: Makefile kind-restart Deprecation (Makefile)
    # =========================================================================

    def test_f14_01_kind_restart_target_present(self):
        """F14.1: Verify kind-restart target is present."""
        self.assertIn(
            "kind-restart", self.makefile_info.targets,
            "Target 'kind-restart' must be defined in Makefile."
        )

    def test_f14_02_kind_restart_deprecation_banner(self):
        """F14.2: Verify kind-restart prints deprecation notice."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-restart", {}).get("recipes", []))
        self.assertTrue(
            "DEPRECATION" in recipes.upper() or "DEPRECATED" in recipes.upper() or "⚠️" in recipes,
            "Target 'kind-restart' must include deprecation notice."
        )

    def test_f14_03_kind_restart_points_to_dev(self):
        """F14.3: Verify kind-restart points to dev-restart or dev-up."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-restart", {}).get("recipes", []))
        self.assertTrue(
            "dev-restart" in recipes or "dev-up" in recipes,
            "Target 'kind-restart' deprecation notice must point to dev alternative."
        )

    def test_f14_04_kind_restart_in_phony(self):
        """F14.4: Verify kind-restart is declared in .PHONY."""
        self.assertIn(
            "kind-restart", self.makefile_info.phony_targets,
            "Target 'kind-restart' must be in .PHONY."
        )

    def test_f14_05_kind_restart_dry_run_syntax(self):
        """F14.5: Verify make -n kind-restart evaluates without syntax error."""
        code, out, err = run_make_dry_run("kind-restart")
        self.assertEqual(code, 0, f"make -n kind-restart failed: {err}")

    # =========================================================================
    # FEATURE 15: Makefile kind-load Deprecation (Makefile)
    # =========================================================================

    def test_f15_01_kind_load_target_present(self):
        """F15.1: Verify kind-load target is present."""
        self.assertIn(
            "kind-load", self.makefile_info.targets,
            "Target 'kind-load' must be defined in Makefile."
        )

    def test_f15_02_kind_load_deprecation_banner(self):
        """F15.2: Verify kind-load prints deprecation notice."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-load", {}).get("recipes", []))
        self.assertTrue(
            "DEPRECATION" in recipes.upper() or "DEPRECATED" in recipes.upper() or "⚠️" in recipes,
            "Target 'kind-load' must include deprecation notice."
        )

    def test_f15_03_kind_load_points_to_dev_build(self):
        """F15.3: Verify kind-load points to dev-build or dev-up."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-load", {}).get("recipes", []))
        self.assertTrue(
            "dev-build" in recipes or "dev-up" in recipes,
            "Target 'kind-load' notice must recommend dev equivalent (e.g. dev-build)."
        )

    def test_f15_04_kind_load_in_phony(self):
        """F15.4: Verify kind-load is declared in .PHONY."""
        self.assertIn(
            "kind-load", self.makefile_info.phony_targets,
            "Target 'kind-load' must be in .PHONY."
        )

    def test_f15_05_kind_load_dry_run_syntax(self):
        """F15.5: Verify make -n kind-load evaluates without syntax error."""
        code, out, err = run_make_dry_run("kind-load")
        self.assertEqual(code, 0, f"make -n kind-load failed: {err}")

    # =========================================================================
    # FEATURE 16: Makefile kind-port-forward Deprecation (Makefile)
    # =========================================================================

    def test_f16_01_kind_port_forward_target_present(self):
        """F16.1: Verify kind-port-forward target is present."""
        self.assertIn(
            "kind-port-forward", self.makefile_info.targets,
            "Target 'kind-port-forward' must be defined in Makefile."
        )

    def test_f16_02_kind_port_forward_deprecation_banner(self):
        """F16.2: Verify kind-port-forward prints deprecation notice."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-port-forward", {}).get("recipes", []))
        self.assertTrue(
            "DEPRECATION" in recipes.upper() or "DEPRECATED" in recipes.upper() or "⚠️" in recipes,
            "Target 'kind-port-forward' must include deprecation notice."
        )

    def test_f16_03_kind_port_forward_points_to_dev_up(self):
        """F16.3: Verify kind-port-forward points to dev-up."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-port-forward", {}).get("recipes", []))
        self.assertIn(
            "dev-up", recipes,
            "Target 'kind-port-forward' notice must recommend 'make dev-up'."
        )

    def test_f16_04_kind_port_forward_in_phony(self):
        """F16.4: Verify kind-port-forward is declared in .PHONY."""
        self.assertIn(
            "kind-port-forward", self.makefile_info.phony_targets,
            "Target 'kind-port-forward' must be in .PHONY."
        )

    def test_f16_05_kind_port_forward_dry_run_syntax(self):
        """F16.5: Verify make -n kind-port-forward evaluates without syntax error."""
        code, out, err = run_make_dry_run("kind-port-forward")
        self.assertEqual(code, 0, f"make -n kind-port-forward failed: {err}")

    # =========================================================================
    # FEATURE 17: Makefile kind-up-debug Target (Makefile)
    # =========================================================================

    def test_f17_01_kind_up_debug_target_present(self):
        """F17.1: Verify kind-up-debug target is defined."""
        self.assertIn(
            "kind-up-debug", self.makefile_info.targets,
            "Target 'kind-up-debug' must be present in Makefile per Feature 17."
        )

    def test_f17_02_kind_up_debug_in_phony(self):
        """F17.2: Verify kind-up-debug is declared in .PHONY."""
        self.assertIn(
            "kind-up-debug", self.makefile_info.phony_targets,
            "Target 'kind-up-debug' must be declared in .PHONY."
        )

    def test_f17_03_kind_up_debug_uses_config_file(self):
        """F17.3: Verify kind-up-debug uses kind-config.yaml."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up-debug", {}).get("recipes", []))
        self.assertTrue(
            "kind-config.yaml" in recipes or "$(LOCAL_BUILD_DIR)" in recipes,
            "Target 'kind-up-debug' must use build/local/kind-config.yaml."
        )

    def test_f17_04_kind_up_debug_uses_cluster_name(self):
        """F17.4: Verify kind-up-debug specifies $(KIND_CLUSTER_NAME)."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up-debug", {}).get("recipes", []))
        self.assertIn(
            "$(KIND_CLUSTER_NAME)", recipes,
            "Target 'kind-up-debug' must use $(KIND_CLUSTER_NAME)."
        )

    def test_f17_05_kind_up_debug_dry_run_syntax(self):
        """F17.5: Verify make -n kind-up-debug evaluates without syntax error."""
        code, out, err = run_make_dry_run("kind-up-debug")
        self.assertEqual(code, 0, f"make -n kind-up-debug failed: {err}")

    # =========================================================================
    # FEATURE 18: Makefile kind-down Retention (Makefile)
    # =========================================================================

    def test_f18_01_kind_down_target_present(self):
        """F18.1: Verify kind-down target is retained in Makefile."""
        self.assertIn(
            "kind-down", self.makefile_info.targets,
            "Target 'kind-down' must be retained in Makefile per Feature 18."
        )

    def test_f18_02_kind_down_in_phony(self):
        """F18.2: Verify kind-down is declared in .PHONY."""
        self.assertIn(
            "kind-down", self.makefile_info.phony_targets,
            "Target 'kind-down' must be declared in .PHONY."
        )

    def test_f18_03_kind_down_runs_delete_cluster(self):
        """F18.3: Verify kind-down executes kind delete cluster."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-down", {}).get("recipes", []))
        self.assertIn(
            "kind delete cluster", recipes,
            "Target 'kind-down' must execute 'kind delete cluster'."
        )

    def test_f18_04_kind_down_kills_port_forward(self):
        """F18.4: Verify kind-down cleans up port-forward processes."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-down", {}).get("recipes", []))
        self.assertTrue(
            "port-forward" in recipes,
            "Target 'kind-down' should terminate kubectl port-forward processes."
        )

    def test_f18_05_kind_down_dry_run_syntax(self):
        """F18.5: Verify make -n kind-down evaluates without syntax error."""
        code, out, err = run_make_dry_run("kind-down")
        self.assertEqual(code, 0, f"make -n kind-down failed: {err}")

    # =========================================================================
    # FEATURE 19: Manifest Validation Assessment (k8s-manifest-validation.yml)
    # =========================================================================

    def test_f19_01_manifest_workflow_exists(self):
        """F19.1: Verify k8s-manifest-validation.yml is valid YAML."""
        self.assertIsNotNone(
            self.k8s_manifest,
            "k8s-manifest-validation.yml must exist and be valid YAML."
        )

    def test_f19_02_kubeconform_step_present(self):
        """F19.2: Verify kubeconform validation step is defined."""
        steps = get_job_steps(get_workflow_job(self.k8s_manifest, "validate"))
        step = find_step(steps, run_substr="kubeconform")
        self.assertIsNotNone(
            step,
            "validate job in k8s-manifest-validation.yml must contain kubeconform step."
        )

    def test_f19_03_dynamic_overlay_matrix(self):
        """F19.3: Verify matrix dynamically runs over changed overlays."""
        validate_job = get_workflow_job(self.k8s_manifest, "validate")
        strategy = validate_job.get("strategy", {})
        matrix = strategy.get("matrix", {})
        overlay_expr = str(matrix.get("overlay", ""))
        self.assertIn(
            "needs.detect_overlays.outputs.overlays",
            overlay_expr,
            "Matrix overlay must be driven by needs.detect_overlays.outputs.overlays."
        )

    def test_f19_04_kubeconform_strict_mode(self):
        """F19.4: Verify kubeconform uses -strict flag."""
        steps = get_job_steps(get_workflow_job(self.k8s_manifest, "validate"))
        step = find_step(steps, name_substr="validate", run_substr="kubeconform")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "-strict", run_script,
            "kubeconform command must include '-strict' flag."
        )

    def test_f19_05_local_overlay_smoke_check(self):
        """F19.5: Verify local overlay smoke check or dry-run is present."""
        steps = get_job_steps(get_workflow_job(self.k8s_manifest, "validate"))
        step = find_step(steps, run_substr="overlays/local")
        self.assertIsNotNone(
            step,
            "k8s-manifest-validation.yml must include local overlay smoke check or validation."
        )

    # =========================================================================
    # FEATURE 20: Host State Invariance (System / Docker / Kind)
    # =========================================================================

    def test_f20_01_kind_clusters_queryable(self):
        """F20.1: Verify host kind clusters queryable without side-effects."""
        clusters = get_host_kind_clusters()
        self.assertIsInstance(clusters, list, "kind get clusters must return a list.")

    def test_f20_02_docker_containers_queryable(self):
        """F20.2: Verify host docker/podman containers queryable without side-effects."""
        containers = get_host_docker_containers()
        self.assertIsInstance(containers, list, "docker ps must return a list.")

    def test_f20_03_no_destructive_commands_in_tests(self):
        """F20.3: Verify test suite files do not execute destructive host commands."""
        test_dir = REPO_ROOT / "tests" / "e2e_ci_migration"
        destructive_patterns = [
            r"kind\s+delete\s+cluster\s+--name\s+fire-monitoring\b",
            r"docker\s+rm\s+-f",
            r"podman\s+rm\s+-f",
            r"docker\s+system\s+prune\s+-f"
        ]
        for py_file in test_dir.glob("*.py"):
            content = read_file_text(py_file)
            for pattern in destructive_patterns:
                self.assertIsNone(
                    re.search(pattern, content),
                    f"Forbidden destructive command found in {py_file}: {pattern}"
                )

    def test_f20_04_host_cluster_invariance(self):
        """F20.4: Verify host Kind clusters list remains invariant."""
        current_clusters = get_host_kind_clusters()
        self.assertEqual(
            self.initial_host_state["clusters"], current_clusters,
            "Host Kind cluster state was altered during testing!"
        )

    def test_f20_05_host_docker_invariance(self):
        """F20.5: Verify host Docker container IDs remain invariant."""
        current_containers = get_host_docker_containers()
        self.assertEqual(
            self.initial_host_state["containers"], current_containers,
            "Host Docker container state was altered during testing!"
        )


if __name__ == "__main__":
    unittest.main()
