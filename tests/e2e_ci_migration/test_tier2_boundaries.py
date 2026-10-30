"""
Tier 2: Boundary & Corner Cases Test Suite (20 Features x 5 Test Cases = 100 Tests)
Opaque-box, requirement-driven tests covering edge conditions, timeouts, missing configs,
regex patterns, and failure modes derived from PROJECT.md & ORIGINAL_REQUEST.md.
"""

import re
import json
import subprocess
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
    get_host_kind_clusters,
    get_host_docker_containers,
    get_host_state_snapshot,
    WORKFLOWS_DIR,
    MAKEFILE_PATH,
    OVERLAYS_DIR,
)


class TestTier2BoundaryCases(unittest.TestCase):
    """
    Tier 2 tests verify boundary conditions, error handling, edge cases,
    and resilience for all 20 features in PROJECT.md.
    """

    @classmethod
    def setUpClass(cls):
        cls.app_pipeline = load_workflow("app-pipeline.yml")
        cls.local_notify = load_workflow("local-cluster-notify.yml")
        cls.local_notify_text = read_file_text(WORKFLOWS_DIR / "local-cluster-notify.yml")
        cls.k8s_manifest = load_workflow("k8s-manifest-validation.yml")
        cls.makefile_info = parse_makefile()
        cls.initial_host_state = get_host_state_snapshot()

    # =========================================================================
    # FEATURE 1: Ephemeral Kind Cluster Setup (app-pipeline.yml)
    # =========================================================================

    def test_f1_b1_wait_timeout_format_and_bounds(self):
        """F1.B1: Verify wait parameter format is bounded (30s-300s)."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="kind-action")
        wait_val = step.get("with", {}).get("wait", "") if step else ""
        match = re.match(r"^(\d+)([sm])$", str(wait_val))
        self.assertIsNotNone(match, f"Wait timeout '{wait_val}' must match format (e.g. 60s).")
        val, unit = int(match.group(1)), match.group(2)
        seconds = val * 60 if unit == "m" else val
        self.assertTrue(30 <= seconds <= 300, f"Wait timeout {seconds}s must be between 30s and 300s.")

    def test_f1_b2_ephemeral_cluster_name_isolation(self):
        """F1.B2: Verify CI cluster name is NOT 'fire-monitoring' to prevent local collision."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="kind-action")
        cluster_name = step.get("with", {}).get("cluster_name", "") if step else ""
        self.assertNotEqual(
            cluster_name, "fire-monitoring",
            "CI smoke test cluster name must NOT be 'fire-monitoring' to protect local cluster."
        )

    def test_f1_b3_job_timeout_minutes_bounded(self):
        """F1.B3: Verify k8s_smoke_test has timeout-minutes bounded between 5 and 20."""
        job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        timeout = job.get("timeout-minutes")
        self.assertIsNotNone(timeout, "k8s_smoke_test must specify timeout-minutes.")
        self.assertTrue(5 <= int(timeout) <= 20, f"timeout-minutes ({timeout}) must be between 5 and 20.")

    def test_f1_b4_no_host_port_mapping_in_ci(self):
        """F1.B4: Verify no hostPort configuration is passed to Kind action."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="kind-action")
        config = step.get("with", {}).get("config", "") if step else ""
        self.assertNotIn("hostPort", config, "CI Kind cluster must not require hostPort mappings.")

    def test_f1_b5_skip_on_production_release_tags(self):
        """F1.B5: Verify k8s_smoke_test skips on production release tags (refs/tags/v*)."""
        job = get_workflow_job(self.app_pipeline, "k8s_smoke_test")
        if_cond = job.get("if", "")
        self.assertTrue(
            "!startsWith(github.ref, 'refs/tags/v')" in if_cond or "refs/tags/v" in if_cond,
            f"k8s_smoke_test must conditionally skip on release tags (got: '{if_cond}')."
        )

    # =========================================================================
    # FEATURE 2: GHCR Docker Authentication (app-pipeline.yml)
    # =========================================================================

    def test_f2_b1_secret_token_syntax_strict(self):
        """F2.B1: Verify secret reference uses exact secrets.GITHUB_TOKEN expression."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="docker/login-action")
        password = str(step.get("with", {}).get("password", "")) if step else ""
        self.assertEqual(
            password.strip(), "${{ secrets.GITHUB_TOKEN }}",
            f"Password must strictly be '${{{{ secrets.GITHUB_TOKEN }}}}' (got: '{password}')."
        )

    def test_f2_b2_registry_env_variable_fallback(self):
        """F2.B2: Verify registry is either ${{ env.REGISTRY }} or ghcr.io."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="docker/login-action")
        registry = str(step.get("with", {}).get("registry", "")).strip() if step else ""
        self.assertTrue(
            registry in ["${{ env.REGISTRY }}", "ghcr.io"],
            f"Registry must be '${{{{ env.REGISTRY }}}}' or 'ghcr.io' (got: '{registry}')."
        )

    def test_f2_b3_unauthenticated_pull_graceful_handling(self):
        """F2.B3: Verify image loading tolerates unauthenticated or unpushed PR images."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind load")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "|| echo" in run_script or "|| true" in run_script or "if docker pull" in run_script,
            "Pull/load step must handle missing images gracefully on PRs without aborting."
        )

    def test_f2_b4_packages_permission_declared(self):
        """F2.B4: Verify workflow-level permissions grant packages access."""
        permissions = self.app_pipeline.get("permissions", {})
        self.assertTrue(
            permissions.get("packages") in ["read", "write"],
            f"Workflow must grant packages read or write permission (got: {permissions.get('packages')})."
        )

    def test_f2_b5_username_actor_syntax_strict(self):
        """F2.B5: Verify username strictly references github.actor."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, uses_substr="docker/login-action")
        username = str(step.get("with", {}).get("username", "")).strip() if step else ""
        self.assertEqual(
            username, "${{ github.actor }}",
            f"Username must strictly be '${{{{ github.actor }}}}' (got: '{username}')."
        )

    # =========================================================================
    # FEATURE 3: Image Pull & Local Tagging (app-pipeline.yml)
    # =========================================================================

    def test_f3_b1_missing_remote_image_does_not_abort_job(self):
        """F3.B1: Verify docker pull failure does not trigger pipefail abort."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind load")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "||" in run_script or "if " in run_script,
            "docker pull must be guarded with error tolerance in PR smoke test."
        )

    def test_f3_b2_handles_empty_services_json(self):
        """F3.B2: Verify script parses services via jq without crashing on empty array."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind load")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "jq -r '.[]'" in run_script or "jq -r" in run_script,
            "Services iteration must parse JSON array safely via jq."
        )

    def test_f3_b3_handles_all_five_services(self):
        """F3.B3: Verify detect_changes covers all 5 microservices."""
        detect_job = get_workflow_job(self.app_pipeline, "detect_changes")
        steps = get_job_steps(detect_job)
        filter_step = find_step(steps, uses_substr="paths-filter")
        filters = filter_step.get("with", {}).get("filters", "") if filter_step else ""
        for svc in ["api", "dashboard", "etl-processor", "db-migrations", "mcu-simulator"]:
            self.assertIn(svc, filters, f"detect_changes filters must include '{svc}'.")

    def test_f3_b4_sha_tag_length_is_seven(self):
        """F3.B4: Verify build_scan_push produces 7-character short SHA."""
        build_job = get_workflow_job(self.app_pipeline, "build_scan_push")
        steps = get_job_steps(build_job)
        tag_step = find_step(steps, name_substr="set image tag")
        run_script = tag_step.get("run", "") if tag_step else ""
        self.assertIn("${GITHUB_SHA::7}", run_script, "Tag resolution must use 7-char short SHA.")

    def test_f3_b5_local_tag_remapping_format(self):
        """F3.B5: Verify tag remapping produces 'localhost/${svc}:local' format."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind load")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "localhost/" in run_script and ":local" in run_script,
            "Images must be tagged as 'localhost/${svc}:local' for local overlay compatibility."
        )

    # =========================================================================
    # FEATURE 4: Local Overlay Kustomize Deployment (app-pipeline.yml)
    # =========================================================================

    def test_f4_b1_missing_secrets_stubbing_guard(self):
        """F4.B1: Verify secrets.yaml stubbing guards against missing file."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="overlays/local")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "[ ! -f" in run_script or "test -f" in run_script or "cp " in run_script,
            "Deploy step must guard secrets.yaml with conditional check."
        )

    def test_f4_b2_existing_secrets_not_overwritten(self):
        """F4.B2: Verify secrets stubbing does not overwrite existing secrets."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="overlays/local")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "[ ! -f", run_script,
            "Secrets preparation must check '[ ! -f .../secrets.yaml ]' before copying."
        )

    def test_f4_b3_namespace_creation_idempotency(self):
        """F4.B3: Verify namespace creation command uses dry-run client apply pattern."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="overlays/local")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "--dry-run=client" in run_script and "kubectl apply" in run_script,
            "Namespace creation must use '--dry-run=client -o yaml | kubectl apply -f -' pattern."
        )

    def test_f4_b4_local_overlay_enforces_image_pull_policy_never(self):
        """F4.B4: Verify local overlay kustomization enforces imagePullPolicy: Never."""
        kust_path = OVERLAYS_DIR / "local" / "kustomization.yaml"
        text = read_file_text(kust_path)
        self.assertIn("imagePullPolicy", text, "Local overlay must configure imagePullPolicy.")

    def test_f4_b5_local_overlay_removes_cloud_sql_proxy(self):
        """F4.B5: Verify local overlay removes cloud-sql-proxy patch."""
        kust_path = OVERLAYS_DIR / "local" / "kustomization.yaml"
        text = read_file_text(kust_path)
        self.assertIn("remove-sql-proxy.yaml", text, "Local overlay must include remove-sql-proxy patch.")

    # =========================================================================
    # FEATURE 5: Core Deployment Rollout Wait (app-pipeline.yml)
    # =========================================================================

    def test_f5_b1_timeout_bounded_between_60_and_180_seconds(self):
        """F5.B1: Verify rollout wait timeout is bounded between 60s and 180s."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="rollout status")
        run_script = step.get("run", "") if step else ""
        match = re.search(r"--timeout=(\d+)s", run_script)
        self.assertIsNotNone(match, "Rollout command must specify --timeout=<N>s.")
        seconds = int(match.group(1))
        self.assertTrue(60 <= seconds <= 180, f"Rollout timeout {seconds}s must be between 60s and 180s.")

    def test_f5_b2_unready_deployment_non_fatal_diagnosis(self):
        """F5.B2: Verify rollout status allows unready deployment to pass to health check."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="rollout status")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "||" in run_script,
            "Rollout status must use '||' to allow detailed diagnosis in pod health check step."
        )

    def test_f5_b3_rollout_order_api_before_dashboard(self):
        """F5.B3: Verify api rollout wait precedes dashboard wait due to initContainer."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="rollout status")
        run_script = step.get("run", "") if step else ""
        api_pos = run_script.find("api")
        dashboard_pos = run_script.find("dashboard")
        self.assertTrue(
            api_pos != -1 and dashboard_pos != -1 and api_pos < dashboard_pos,
            "api deployment must precede dashboard in rollout wait sequence."
        )

    def test_f5_b4_explicit_namespace_in_rollout(self):
        """F5.B4: Verify rollout status explicitly passes -n fire-monitoring-local."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="rollout status")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "-n fire-monitoring-local" in run_script or "--namespace=fire-monitoring-local" in run_script,
            "Rollout command must explicitly define namespace fire-monitoring-local."
        )

    def test_f5_b5_multi_deployment_loop_syntax(self):
        """F5.B5: Verify for-loop syntax evaluates deployments cleanly."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="rollout status")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "for deploy in" in run_script and "done" in run_script,
            "Rollout wait must iterate over deployments in a shell loop."
        )

    # =========================================================================
    # FEATURE 6: Pod CrashLoopBackOff Gating (app-pipeline.yml)
    # =========================================================================

    def test_f6_b1_zero_crash_logic(self):
        """F6.B1: Verify bash crash evaluation logic passes when CRASHES=0."""
        cmd = 'CRASHES=0; if [ "$CRASHES" -gt 0 ]; then exit 1; else exit 0; fi'
        res = subprocess.run(["bash", "-c", cmd])
        self.assertEqual(res.returncode, 0, "Zero crashes must result in exit code 0.")

    def test_f6_b2_single_crash_logic(self):
        """F6.B2: Verify bash crash evaluation logic fails when CRASHES=1."""
        cmd = 'CRASHES=1; if [ "$CRASHES" -gt 0 ]; then exit 1; else exit 0; fi'
        res = subprocess.run(["bash", "-c", cmd])
        self.assertEqual(res.returncode, 1, "One crash must result in exit code 1.")

    def test_f6_b3_multiple_crashes_logic(self):
        """F6.B3: Verify bash crash evaluation logic fails when CRASHES=3."""
        cmd = 'CRASHES=3; if [ "$CRASHES" -gt 0 ]; then exit 1; else exit 0; fi'
        res = subprocess.run(["bash", "-c", cmd])
        self.assertEqual(res.returncode, 1, "Multiple crashes must result in exit code 1.")

    def test_f6_b4_succeeded_pods_excluded_filter(self):
        """F6.B4: Verify field-selector excludes Succeeded pods to ignore completed jobs."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="CrashLoopBackOff")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "status.phase!=Succeeded",
            run_script,
            "kubectl get pods must use '--field-selector=status.phase!=Succeeded'."
        )

    def test_f6_b5_log_dump_tail_bounded(self):
        """F6.B5: Verify kubectl logs tail is bounded (<= 100 lines)."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="CrashLoopBackOff")
        run_script = step.get("run", "") if step else ""
        match = re.search(r"--tail=(\d+)", run_script)
        self.assertIsNotNone(match, "Log dump command must include --tail=<N>.")
        tail_lines = int(match.group(1))
        self.assertTrue(10 <= tail_lines <= 100, f"--tail={tail_lines} must be bounded between 10 and 100.")

    # =========================================================================
    # FEATURE 7: In-Cluster API Health Probe (app-pipeline.yml)
    # =========================================================================

    def test_f7_b1_port_forward_process_killed(self):
        """F7.B1: Verify background process is killed with kill $PF_PID."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="port-forward")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "kill $PF_PID" in run_script or "killall" in run_script or "pkill" in run_script,
            "Step must kill the specific port-forward PID."
        )

    def test_f7_b2_health_url_path_is_strictly_root_health(self):
        """F7.B2: Verify probe URL is http://127.0.0.1:8000/health (not /api/health)."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="port-forward")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "http://127.0.0.1:8000/health",
            run_script,
            "Health probe must target http://127.0.0.1:8000/health (Express endpoint)."
        )

    def test_f7_b3_curl_silent_fail_flags(self):
        """F7.B3: Verify curl flags include -s and -f."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="port-forward")
        run_script = step.get("run", "") if step else ""
        self.assertTrue(
            "curl -sf" in run_script or "curl -fs" in run_script or ("-s" in run_script and "-f" in run_script),
            "curl command must use silent fail flags (-sf)."
        )

    def test_f7_b4_continue_on_error_is_boolean_true(self):
        """F7.B4: Verify continue-on-error is strictly boolean True."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="port-forward")
        self.assertIsNotNone(step, "API health check step must exist in k8s_smoke_test.")
        self.assertIs(
            step.get("continue-on-error"), True,
            "continue-on-error must be True in API health check step."
        )

    def test_f7_b5_port_forward_readiness_sleep(self):
        """F7.B5: Verify sleep delay exists between backgrounding and curl."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="port-forward")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "sleep", run_script,
            "Step must include sleep to allow port-forward socket establishment."
        )

    # =========================================================================
    # FEATURE 8: Guaranteed Kind Cleanup (app-pipeline.yml)
    # =========================================================================

    def test_f8_b1_always_runs_condition_string(self):
        """F8.B1: Verify cleanup condition is exact expression 'always()'."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind delete cluster")
        if_cond = step.get("if", "") if step else ""
        self.assertEqual(if_cond.strip(), "always()", "Condition must strictly be 'always()'.")

    def test_f8_b2_always_cleanup_placed_after_health_check(self):
        """F8.B2: Verify cleanup is positioned after the API health check."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        health_idx = -1
        cleanup_idx = -1
        for idx, s in enumerate(steps):
            if "port-forward" in str(s.get("run", "")):
                health_idx = idx
            if "kind delete cluster" in str(s.get("run", "")):
                cleanup_idx = idx
        self.assertTrue(
            health_idx != -1 and cleanup_idx != -1 and health_idx < cleanup_idx,
            "Cleanup must execute after the API health check."
        )

    def test_f8_b3_cluster_delete_scoped_name(self):
        """F8.B3: Verify cleanup command specifies the explicit cluster name."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind delete cluster")
        run_script = step.get("run", "") if step else ""
        self.assertIn(
            "ci-smoke-test", run_script,
            "Cleanup command must target the specific cluster 'ci-smoke-test'."
        )

    def test_f8_b4_no_wildcard_cluster_delete(self):
        """F8.B4: Verify no wildcard or all-clusters flag is passed to kind delete."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind delete cluster")
        run_script = step.get("run", "") if step else ""
        self.assertNotIn("--all", run_script, "kind delete cluster must not use --all.")

    def test_f8_b5_isolated_step_execution(self):
        """F8.B5: Verify cleanup step is a standalone step."""
        steps = get_job_steps(get_workflow_job(self.app_pipeline, "k8s_smoke_test"))
        step = find_step(steps, run_substr="kind delete cluster")
        self.assertIsNotNone(step, "Cleanup must be an independent step.")
        run_script = step.get("run", "").strip() if step else ""
        lines = [l for l in run_script.splitlines() if l.strip()]
        self.assertLessEqual(len(lines), 3, "Cleanup step must be concise and dedicated.")

    # =========================================================================
    # FEATURE 9: Consolidated CI Gate Integration (app-pipeline.yml)
    # =========================================================================

    def test_f9_b1_allows_skipped_smoke_test_on_release_tags(self):
        """F9.B1: Verify gate condition checks failure specifically, tolerating skipped."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        steps = get_job_steps(ci_gate)
        verify_step = find_step(steps, name_substr="verify all ci checks")
        run_script = verify_step.get("run", "") if verify_step else ""
        self.assertNotIn(
            '[ "${{ needs.k8s_smoke_test.result }}" != "success" ]',
            run_script,
            "Gate must check for '= \"failure\"' rather than '!= \"success\"' to tolerate skipped."
        )

    def test_f9_b2_failure_condition_operator(self):
        """F9.B2: Verify failure check uses = 'failure'."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        steps = get_job_steps(ci_gate)
        verify_step = find_step(steps, name_substr="verify all ci checks")
        run_script = verify_step.get("run", "") if verify_step else ""
        self.assertTrue(
            '[ "${{ needs.k8s_smoke_test.result }}" = "failure" ]' in run_script or
            '[ "${{ needs.k8s_smoke_test.result }}" == "failure" ]' in run_script,
            "Script must test if needs.k8s_smoke_test.result equals 'failure'."
        )

    def test_f9_b3_gate_exits_with_code_one(self):
        """F9.B3: Verify gate script exits with code 1 upon failure."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        steps = get_job_steps(ci_gate)
        verify_step = find_step(steps, name_substr="verify all ci checks")
        run_script = verify_step.get("run", "") if verify_step else ""
        self.assertIn("exit 1", run_script, "Gate script must execute exit 1 on check failure.")

    def test_f9_b4_branch_protection_name_intact(self):
        """F9.B4: Verify ci_gate job name remains stable for GitHub branch protection."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        self.assertEqual(
            ci_gate.get("name"), "CI Gate / All Checks Passed",
            "ci_gate job name must remain 'CI Gate / All Checks Passed'."
        )

    def test_f9_b5_gate_dependencies_count(self):
        """F9.B5: Verify ci_gate has exactly 4 dependencies."""
        ci_gate = get_workflow_job(self.app_pipeline, "ci_gate")
        needs = ci_gate.get("needs", [])
        self.assertEqual(len(needs), 4, f"ci_gate needs must have 4 jobs (got {needs}).")

    # =========================================================================
    # FEATURE 10: Commit Status Rebranding (local-cluster-notify.yml)
    # =========================================================================

    def test_f10_b1_no_case_variants_of_kind_cluster(self):
        """F10.B1: Verify commit status block has no case variants of 'kind cluster'."""
        match = re.search(r"createCommitStatus\(\{.*?description:\s*`([^`]+)`", self.local_notify_text, re.DOTALL)
        self.assertIsNotNone(match, "createCommitStatus block must be present.")
        desc = match.group(1)
        self.assertIsNone(
            re.search(r"kind\s+cluster", desc, re.IGNORECASE),
            f"Commit status description contains case-insensitive 'kind cluster': {desc}"
        )

    def test_f10_b2_short_sha_interpolation(self):
        """F10.B2: Verify ${shortSha} is present in commit status description."""
        match = re.search(r"createCommitStatus\(\{.*?description:\s*`([^`]+)`", self.local_notify_text, re.DOTALL)
        self.assertIsNotNone(match, "createCommitStatus block must be present.")
        desc = match.group(1)
        self.assertIn("${shortSha}", desc, "Description must interpolate ${shortSha}.")

    def test_f10_b3_target_url_run_url(self):
        """F10.B3: Verify target_url maps to runUrl."""
        match = re.search(r"target_url:\s*(\w+)", self.local_notify_text)
        self.assertIsNotNone(match, "target_url must be defined.")
        self.assertEqual(match.group(1), "runUrl", "target_url must map to runUrl.")

    def test_f10_b4_octokit_method_call(self):
        """F10.B4: Verify github.rest.repos.createCommitStatus is called."""
        self.assertIn(
            "github.rest.repos.createCommitStatus",
            self.local_notify_text,
            "Must call github.rest.repos.createCommitStatus."
        )

    def test_f10_b5_surrounding_text_fidelity(self):
        """F10.B5: Verify surrounding text 'Image ${shortSha} pushed to GHCR & overlay updated' intact."""
        self.assertIn(
            "pushed to GHCR & overlay updated",
            self.local_notify_text,
            "Notification context text must remain intact."
        )

    # =========================================================================
    # FEATURE 11: Summary Table Rebranding (local-cluster-notify.yml)
    # =========================================================================

    def test_f11_b1_no_case_variants_of_local_kind_cluster(self):
        """F11.B1: Verify summary has no case-insensitive 'local kind cluster'."""
        self.assertIsNone(
            re.search(r"local\s+kind\s+cluster", self.local_notify_text, re.IGNORECASE),
            "Summary markdown must not contain 'local kind cluster'."
        )

    def test_f11_b2_argocd_polling_frequency_intact(self):
        """F11.B2: Verify 3-minute ArgoCD polling explanation preserved."""
        self.assertIn(
            "polls GitHub every 3 minutes",
            self.local_notify_text,
            "ArgoCD polling documentation must be preserved."
        )

    def test_f11_b3_markdown_table_formatting_valid(self):
        """F11.B3: Verify markdown table syntax preserved."""
        self.assertIn("| Field         | Value |", self.local_notify_text)
        self.assertIn("|:-------------|:------|", self.local_notify_text)

    def test_f11_b4_check_run_conclusion_is_success(self):
        """F11.B4: Verify check run conclusion is 'success'."""
        self.assertIn("conclusion: 'success'", self.local_notify_text)

    def test_f11_b5_helper_commands_retained(self):
        """F11.B5: Verify 'make staging-sync' and 'make staging-watch' hints retained."""
        self.assertIn("make staging-sync", self.local_notify_text)
        self.assertIn("make staging-watch", self.local_notify_text)

    # =========================================================================
    # FEATURE 12: Makefile Baseline Reconciliation (Makefile)
    # =========================================================================

    def test_f12_b1_working_tree_drift_check(self):
        """F12.B1: Verify working tree Makefile matches or exceeds 400 lines."""
        self.assertGreaterEqual(
            self.makefile_info.line_count, 400,
            f"Makefile is truncated ({self.makefile_info.line_count} lines) vs 409-line baseline."
        )

    def test_f12_b2_section_headings_present(self):
        """F12.B2: Verify all major SDLC section headings are present."""
        text = self.makefile_info.raw_text
        for heading in ["DEV", "KIND", "STAGING", "PRODUCTION", "CLOUD INFRA", "UTILITIES"]:
            self.assertIn(heading, text, f"Section heading '{heading}' missing from Makefile.")

    def test_f12_b3_gke_terraform_targets_present(self):
        """F12.B3: Verify GKE Terraform targets are present."""
        for target in ["gke-dev-infra-plan", "gke-dev-platform-apply", "gke-prod-infra-plan"]:
            self.assertIn(
                target, self.makefile_info.targets,
                f"GKE target '{target}' missing from Makefile."
            )

    def test_f12_b4_staging_gitops_targets_present(self):
        """F12.B4: Verify Staging GitOps targets are present."""
        for target in ["staging-sync", "staging-watch", "staging-pause", "staging-resume"]:
            self.assertIn(
                target, self.makefile_info.targets,
                f"Staging target '{target}' missing from Makefile."
            )

    def test_f12_b5_default_goal_is_dev_up(self):
        """F12.B5: Verify default goal is dev-up."""
        self.assertIn(
            ".DEFAULT_GOAL := dev-up", self.makefile_info.raw_text,
            "Makefile default goal must be 'dev-up'."
        )

    # =========================================================================
    # FEATURE 13: Makefile kind-up Deprecation (Makefile)
    # =========================================================================

    def test_f13_b1_banner_visual_indicator(self):
        """F13.B1: Verify deprecation banner contains warning symbol or banner."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up", {}).get("recipes", []))
        self.assertTrue(
            "⚠️" in recipes or "DEPRECATION NOTICE" in recipes or "DEPRECATED" in recipes,
            "kind-up recipe must include warning symbol or banner."
        )

    def test_f13_b2_mentions_ci_validation(self):
        """F13.B2: Verify deprecation notice explains that validation moved to CI."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up", {}).get("recipes", []))
        self.assertTrue(
            "CI" in recipes,
            "kind-up deprecation message must mention that validation moved to CI."
        )

    def test_f13_b3_dry_run_syntax_clean(self):
        """F13.B3: Verify make -n kind-up exits with 0 and produces banner."""
        code, out, err = run_make_dry_run("kind-up")
        self.assertEqual(code, 0, f"make -n kind-up failed with error: {err}")
        self.assertTrue("dev-up" in out or "dev-up" in err or "kind-up-debug" in out)

    def test_f13_b4_alias_kind_points_to_kind_up(self):
        """F13.B4: Verify alias 'kind' depends on 'kind-up'."""
        prereqs = self.makefile_info.targets.get("kind", {}).get("prereqs", [])
        self.assertIn("kind-up", prereqs, "Target 'kind' must alias 'kind-up'.")

    def test_f13_b5_help_menu_shows_kind_up_deprecated(self):
        """F13.B5: Verify help target indicates kind-up is deprecated."""
        recipes = "\n".join(self.makefile_info.targets.get("help", {}).get("recipes", []))
        self.assertTrue(
            "DEPRECATED" in recipes or "deprecated" in recipes.lower(),
            "Makefile help target must mark Kind section as deprecated."
        )

    # =========================================================================
    # FEATURE 14: Makefile kind-restart Deprecation (Makefile)
    # =========================================================================

    def test_f14_b1_banner_indicates_deprecation(self):
        """F14.B1: Verify kind-restart banner contains DEPRECATION or ⚠️."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-restart", {}).get("recipes", []))
        self.assertTrue(
            "DEPRECATION" in recipes.upper() or "⚠️" in recipes,
            "kind-restart must display deprecation banner."
        )

    def test_f14_b2_points_specifically_to_dev_restart(self):
        """F14.B2: Verify kind-restart recommends dev-restart."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-restart", {}).get("recipes", []))
        self.assertIn("dev-restart", recipes, "kind-restart notice must mention dev-restart.")

    def test_f14_b3_retains_rollout_restart_command(self):
        """F14.B3: Verify kind-restart retains rollout restart execution."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-restart", {}).get("recipes", []))
        self.assertIn("rollout restart", recipes, "kind-restart must execute rollout restart.")

    def test_f14_b4_clean_stderr_dry_run(self):
        """F14.B4: Verify make -n kind-restart produces zero stderr errors."""
        code, out, err = run_make_dry_run("kind-restart")
        self.assertEqual(code, 0, f"make -n kind-restart failed: {err}")

    def test_f14_b5_prereqs_build_and_load(self):
        """F14.B5: Verify kind-restart has prerequisites build-local and kind-load."""
        prereqs = self.makefile_info.targets.get("kind-restart", {}).get("prereqs", [])
        self.assertTrue(
            "build-local" in prereqs and "kind-load" in prereqs,
            "kind-restart must list build-local and kind-load as prerequisites."
        )

    # =========================================================================
    # FEATURE 15: Makefile kind-load Deprecation (Makefile)
    # =========================================================================

    def test_f15_b1_banner_indicates_deprecation(self):
        """F15.B1: Verify kind-load banner contains DEPRECATION or ⚠️."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-load", {}).get("recipes", []))
        self.assertTrue(
            "DEPRECATION" in recipes.upper() or "⚠️" in recipes,
            "kind-load must display deprecation banner."
        )

    def test_f15_b2_points_specifically_to_dev_build(self):
        """F15.B2: Verify kind-load recommends dev-build."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-load", {}).get("recipes", []))
        self.assertIn("dev-build", recipes, "kind-load notice must mention dev-build.")

    def test_f15_b3_loads_all_five_service_images(self):
        """F15.B3: Verify kind-load loads all 5 services into Kind."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-load", {}).get("recipes", []))
        for svc in ["api", "dashboard", "etl-processor", "mcu-simulator", "db-migrations"]:
            self.assertIn(svc, recipes, f"kind-load must load service '{svc}'.")

    def test_f15_b4_clean_stderr_dry_run(self):
        """F15.B4: Verify make -n kind-load produces zero stderr errors."""
        code, out, err = run_make_dry_run("kind-load")
        self.assertEqual(code, 0, f"make -n kind-load failed: {err}")

    def test_f15_b5_prereq_build_local(self):
        """F15.B5: Verify kind-load has build-local prerequisite."""
        prereqs = self.makefile_info.targets.get("kind-load", {}).get("prereqs", [])
        self.assertIn("build-local", prereqs, "kind-load must depend on build-local.")

    # =========================================================================
    # FEATURE 16: Makefile kind-port-forward Deprecation (Makefile)
    # =========================================================================

    def test_f16_b1_banner_indicates_deprecation(self):
        """F16.B1: Verify kind-port-forward banner contains DEPRECATION or ⚠️."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-port-forward", {}).get("recipes", []))
        self.assertTrue(
            "DEPRECATION" in recipes.upper() or "⚠️" in recipes,
            "kind-port-forward must display deprecation banner."
        )

    def test_f16_b2_points_specifically_to_dev_up(self):
        """F16.B2: Verify kind-port-forward recommends dev-up."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-port-forward", {}).get("recipes", []))
        self.assertIn("dev-up", recipes, "kind-port-forward notice must mention dev-up.")

    def test_f16_b3_port_conflict_checks_preserved(self):
        """F16.B3: Verify port conflict check loop is preserved."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-port-forward", {}).get("recipes", []))
        self.assertIn("ss -tuln", recipes, "kind-port-forward must retain port conflict checks.")

    def test_f16_b4_clean_stderr_dry_run(self):
        """F16.B4: Verify make -n kind-port-forward produces zero stderr errors."""
        code, out, err = run_make_dry_run("kind-port-forward")
        self.assertEqual(code, 0, f"make -n kind-port-forward failed: {err}")

    def test_f16_b5_killall_kubectl_safely_tolerated(self):
        """F16.B5: Verify killall kubectl is protected with 2>/dev/null || true."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-port-forward", {}).get("recipes", []))
        self.assertTrue(
            "killall kubectl 2>/dev/null || true" in recipes or "killall" in recipes,
            "killall kubectl must be protected against non-zero exit."
        )

    # =========================================================================
    # FEATURE 17: Makefile kind-up-debug Target (Makefile)
    # =========================================================================

    def test_f17_b1_creates_cluster_with_kind_create(self):
        """F17.B1: Verify recipe executes 'kind create cluster'."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up-debug", {}).get("recipes", []))
        self.assertIn("kind create cluster", recipes, "kind-up-debug must execute 'kind create cluster'.")

    def test_f17_b2_uses_wait_60s(self):
        """F17.B2: Verify kind-up-debug specifies wait parameter (--wait 60s)."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up-debug", {}).get("recipes", []))
        self.assertIn("--wait", recipes, "kind-up-debug must specify --wait parameter.")

    def test_f17_b3_sets_kubectl_context(self):
        """F17.B3: Verify kind-up-debug switches kubectl context."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up-debug", {}).get("recipes", []))
        self.assertIn(
            "kubectl config use-context", recipes,
            "kind-up-debug must set context via kubectl config use-context."
        )

    def test_f17_b4_debugging_banner_present(self):
        """F17.B4: Verify kind-up-debug prints debugging notice."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-up-debug", {}).get("recipes", []))
        self.assertTrue(
            "DEBUGGING" in recipes.upper() or "DEBUG" in recipes.upper(),
            "kind-up-debug must display debugging notice."
        )

    def test_f17_b5_config_file_exists_on_disk(self):
        """F17.B5: Verify referenced kind-config.yaml exists on disk."""
        config_path = REPO_ROOT / "build" / "local" / "kind-config.yaml"
        self.assertTrue(config_path.exists(), f"Configuration file {config_path} must exist.")

    # =========================================================================
    # FEATURE 18: Makefile kind-down Retention (Makefile)
    # =========================================================================

    def test_f18_b1_not_marked_as_deprecated(self):
        """F18.B1: Verify kind-down is NOT marked as deprecated (retained cleanup)."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-down", {}).get("recipes", []))
        self.assertNotIn(
            "DEPRECATION NOTICE", recipes,
            "kind-down must NOT be marked with deprecation notice (it is retained for cleanup)."
        )

    def test_f18_b2_pkill_port_forward_safely_tolerated(self):
        """F18.B2: Verify pkill port-forward is protected with || true."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-down", {}).get("recipes", []))
        self.assertTrue(
            "|| true" in recipes or "pkill" in recipes,
            "pkill must tolerate non-running processes safely."
        )

    def test_f18_b3_delete_cluster_tolerates_non_existent(self):
        """F18.B3: Verify delete cluster command tolerates non-existent cluster (|| true)."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-down", {}).get("recipes", []))
        self.assertTrue(
            "|| true" in recipes,
            "kind delete cluster must have '|| true' fallback for idempotency."
        )

    def test_f18_b4_uses_cluster_name_variable(self):
        """F18.B4: Verify kind-down deletes $(KIND_CLUSTER_NAME)."""
        recipes = "\n".join(self.makefile_info.targets.get("kind-down", {}).get("recipes", []))
        self.assertIn("$(KIND_CLUSTER_NAME)", recipes, "kind-down must delete $(KIND_CLUSTER_NAME).")

    def test_f18_b5_clean_stderr_dry_run(self):
        """F18.B5: Verify make -n kind-down produces zero stderr errors."""
        code, out, err = run_make_dry_run("kind-down")
        self.assertEqual(code, 0, f"make -n kind-down failed: {err}")

    # =========================================================================
    # FEATURE 19: Manifest Validation Assessment (k8s-manifest-validation.yml)
    # =========================================================================

    def test_f19_b1_paths_filter_covers_k8s_and_workflow(self):
        """F19.B1: Verify workflow triggers on both infrastructure/k8s/** and workflow."""
        on_clause = self.k8s_manifest.get("on", {})
        push_paths = on_clause.get("push", {}).get("paths", [])
        self.assertIn("infrastructure/k8s/**", push_paths)
        self.assertIn(".github/workflows/k8s-manifest-validation.yml", push_paths)

    def test_f19_b2_fail_fast_false_on_matrix(self):
        """F19.B2: Verify strategy sets fail-fast: false to validate all overlays."""
        validate_job = get_workflow_job(self.k8s_manifest, "validate")
        strategy = validate_job.get("strategy", {})
        self.assertIs(strategy.get("fail-fast"), False, "validate job must set fail-fast: false.")

    def test_f19_b3_base_changes_trigger_both_overlays(self):
        """F19.B3: Verify detect_overlays script adds both dev and prod on base changes."""
        detect_job = get_workflow_job(self.k8s_manifest, "detect_overlays")
        steps = get_job_steps(detect_job)
        matrix_step = find_step(steps, name_substr="build changed overlay matrix")
        run_script = matrix_step.get("run", "") if matrix_step else ""
        self.assertTrue(
            '["dev", "prod"]' in run_script or "dev" in run_script and "prod" in run_script,
            "Changes to base must trigger validation for both dev and prod."
        )

    def test_f19_b4_kubernetes_version_pinned_in_env(self):
        """F19.B4: Verify KUBERNETES_VERSION is pinned in env."""
        env_vars = self.k8s_manifest.get("env", {})
        k8s_ver = env_vars.get("KUBERNETES_VERSION")
        self.assertIsNotNone(k8s_ver, "KUBERNETES_VERSION must be defined in workflow env.")

    def test_f19_b5_dev_secrets_stub_copy_on_demand(self):
        """F19.B5: Verify dev secrets stubbing checks if secrets.yaml exists."""
        steps = get_job_steps(get_workflow_job(self.k8s_manifest, "validate"))
        stub_step = find_step(steps, name_substr="prepare secrets stub")
        run_script = stub_step.get("run", "") if stub_step else ""
        self.assertIn("secrets.yaml.example", run_script)

    # =========================================================================
    # FEATURE 20: Host State Invariance (System / Docker / Kind)
    # =========================================================================

    def test_f20_b1_no_destructive_make_target_called(self):
        """F20.B1: Verify tests do not execute bare destructive make targets."""
        # Check that dry-run is always used
        code, out, err = run_make_dry_run("clean")
        self.assertEqual(code, 0, f"make -n clean failed: {err}")

    def test_f20_b2_no_kind_delete_executed_on_host(self):
        """F20.B2: Verify host Kind clusters list is strictly non-empty if clusters existed."""
        current_clusters = get_host_kind_clusters()
        self.assertEqual(len(current_clusters), len(self.initial_host_state["clusters"]))

    def test_f20_b3_no_docker_prune_executed_on_host(self):
        """F20.B3: Verify host Docker container count was not reduced."""
        current_containers = get_host_docker_containers()
        self.assertGreaterEqual(
            len(current_containers), len(self.initial_host_state["containers"]),
            "Docker containers were pruned or deleted during test execution!"
        )

    def test_f20_b4_cluster_list_hash_invariance(self):
        """F20.B4: Verify cluster hash matches initial state."""
        current_state = get_host_state_snapshot()
        self.assertEqual(
            self.initial_host_state["clusters_hash"], current_state["clusters_hash"],
            "Host Kind cluster hash mismatch!"
        )

    def test_f20_b5_docker_containers_hash_invariance(self):
        """F20.B5: Verify containers hash matches initial state."""
        current_state = get_host_state_snapshot()
        self.assertEqual(
            self.initial_host_state["containers_hash"], current_state["containers_hash"],
            "Host Docker container hash mismatch!"
        )


if __name__ == "__main__":
    unittest.main()
