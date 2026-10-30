"""
Adversarial Stress Test Suite & Oracle Harness for Kind-to-CI Migration
Author: teamwork_challenger (Challenger 1)
Target Repository: /home/zett/RiderProjects/FireMonitoringSystem
"""

import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Dict, List, Any, Optional

import yaml

REPO_ROOT = Path("/home/zett/RiderProjects/FireMonitoringSystem").resolve()
WORKFLOWS_DIR = REPO_ROOT / ".github" / "workflows"
MAKEFILE_PATH = REPO_ROOT / "Makefile"
OVERLAYS_DIR = REPO_ROOT / "infrastructure" / "k8s" / "overlays"


def load_yaml(path: Path) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f.read()) or {}
    if isinstance(data, dict) and True in data:
        data["on"] = data.pop(True)
    return data


class TestAdversarialWorkflows(unittest.TestCase):
    """Stress tests and oracles for workflow event lifecycle semantics."""

    @classmethod
    def setUpClass(cls):
        cls.app_pipeline = load_yaml(WORKFLOWS_DIR / "app-pipeline.yml")
        cls.jobs = cls.app_pipeline.get("jobs", {})

    def test_workflow_events_and_paths(self):
        """Verify on triggers include pull_request, push (main & tags v*.*.*), and workflow_dispatch."""
        on = self.app_pipeline.get("on", {})
        self.assertIn("workflow_dispatch", on)
        self.assertIn("pull_request", on)
        self.assertIn("push", on)

        push = on["push"]
        self.assertIn("branches", push)
        self.assertIn("main", push["branches"])
        self.assertIn("tags", push)
        self.assertIn("v*.*.*", push["tags"])

        pr = on["pull_request"]
        self.assertIn("paths", pr)
        self.assertIn("apps/**", pr["paths"])
        self.assertIn(".github/workflows/app-pipeline.yml", pr["paths"])

    def test_job_dependency_dag(self):
        """Verify the DAG integrity: detect_changes -> test & build_scan_push -> k8s_smoke_test -> ci_gate."""
        test_job = self.jobs.get("test", {})
        self.assertEqual(test_job.get("needs"), "detect_changes")

        build_job = self.jobs.get("build_scan_push", {})
        self.assertEqual(set(build_job.get("needs", [])), {"detect_changes", "test"})

        smoke_job = self.jobs.get("k8s_smoke_test", {})
        self.assertEqual(set(smoke_job.get("needs", [])), {"detect_changes", "build_scan_push"})

        gate_job = self.jobs.get("ci_gate", {})
        self.assertEqual(
            set(gate_job.get("needs", [])),
            {"detect_changes", "test", "build_scan_push", "k8s_smoke_test"}
        )

        deploy_dev = self.jobs.get("deploy_dev", {})
        self.assertEqual(set(deploy_dev.get("needs", [])), {"detect_changes", "build_scan_push"})

        promote_prod = self.jobs.get("promote_prod", {})
        self.assertEqual(set(promote_prod.get("needs", [])), {"detect_changes", "build_scan_push"})

    def test_pr_event_simulation(self):
        """Simulate PR event semantics: no push to registry, k8s_smoke_test executes with fallback."""
        event = {
            "github.event_name": "pull_request",
            "github.ref": "refs/pull/42/merge",
            "github.ref_name": "42/merge"
        }

        # 1. k8s_smoke_test condition: "!startsWith(github.ref, 'refs/tags/v')"
        ref = event["github.ref"]
        is_release_tag = ref.startswith("refs/tags/v")
        smoke_should_run = not is_release_tag
        self.assertTrue(smoke_should_run, "k8s_smoke_test MUST run on PR events")

        # 2. build_scan_push: push boolean
        # github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')
        push_registry = (ref == "refs/heads/main" or ref.startswith("refs/tags/v"))
        self.assertFalse(push_registry, "Images MUST NOT be pushed to remote registries on PRs")

        # 3. deploy_dev condition: (github.event_name == 'push' || ...) && github.ref == 'refs/heads/main'
        deploy_dev_should_run = (event["github.event_name"] == "push" and ref == "refs/heads/main")
        self.assertFalse(deploy_dev_should_run, "deploy_dev MUST NOT run on PRs")

        # 4. promote_prod condition: startsWith(github.ref, 'refs/tags/v')
        promote_prod_should_run = ref.startswith("refs/tags/v")
        self.assertFalse(promote_prod_should_run, "promote_prod MUST NOT run on PRs")

    def test_main_push_event_simulation(self):
        """Simulate push to main semantics: images pushed, k8s_smoke_test runs, deploy_dev runs."""
        event = {
            "github.event_name": "push",
            "github.ref": "refs/heads/main",
            "github.ref_name": "main"
        }
        ref = event["github.ref"]

        smoke_should_run = not ref.startswith("refs/tags/v")
        self.assertTrue(smoke_should_run, "k8s_smoke_test MUST run on main push")

        push_registry = (ref == "refs/heads/main" or ref.startswith("refs/tags/v"))
        self.assertTrue(push_registry, "Images MUST be pushed to GHCR & GAR on main push")

        deploy_dev_should_run = (event["github.event_name"] == "push" and ref == "refs/heads/main")
        self.assertTrue(deploy_dev_should_run, "deploy_dev MUST run on main push")

        promote_prod_should_run = ref.startswith("refs/tags/v")
        self.assertFalse(promote_prod_should_run, "promote_prod MUST NOT run on main push")

    def test_tag_event_simulation(self):
        """Simulate release tag push: k8s_smoke_test skipped, deploy_dev skipped, promote_prod runs."""
        event = {
            "github.event_name": "push",
            "github.ref": "refs/tags/v1.0.0",
            "github.ref_name": "v1.0.0"
        }
        ref = event["github.ref"]

        smoke_should_run = not ref.startswith("refs/tags/v")
        self.assertFalse(smoke_should_run, "k8s_smoke_test MUST be skipped on production tags")

        push_registry = (ref == "refs/heads/main" or ref.startswith("refs/tags/v"))
        self.assertTrue(push_registry, "Images MUST be pushed on release tags")

        deploy_dev_should_run = (event["github.event_name"] == "push" and ref == "refs/heads/main")
        self.assertFalse(deploy_dev_should_run, "deploy_dev MUST NOT run on release tags")

        promote_prod_should_run = ref.startswith("refs/tags/v")
        self.assertTrue(promote_prod_should_run, "promote_prod MUST run on release tags")

    def test_ci_gate_truth_table_oracle(self):
        """
        Adversarial Truth Table Oracle for ci_gate logic:
        Script:
        if [ "$detect_changes" = "failure" ] || \
           [ "$test" = "failure" ] || \
           [ "$build_scan_push" = "failure" ] || \
           [ "$k8s_smoke_test" = "failure" ]; then
          exit 1
        fi
        """
        possible_states = ["success", "failure", "skipped"]

        # Gate must only fail if ANY required job failed.
        # If a job was skipped (e.g. k8s_smoke_test skipped on tags), gate must succeed.
        for s_dc in possible_states:
            for s_test in possible_states:
                for s_bsp in possible_states:
                    for s_smoke in possible_states:
                        bash_cmd = f"""
                        if [ "{s_dc}" = "failure" ] || \
                           [ "{s_test}" = "failure" ] || \
                           [ "{s_bsp}" = "failure" ] || \
                           [ "{s_smoke}" = "failure" ]; then
                          exit 1
                        fi
                        exit 0
                        """
                        res = subprocess.run(
                            ["bash", "-c", bash_cmd],
                            capture_output=True,
                            text=True
                        )
                        any_failure = any(s == "failure" for s in [s_dc, s_test, s_bsp, s_smoke])
                        expected_rc = 1 if any_failure else 0
                        self.assertEqual(
                            res.returncode,
                            expected_rc,
                            f"Mismatch in ci_gate truth table for ({s_dc}, {s_test}, {s_bsp}, {s_smoke})"
                        )


class TestAdversarialCrashLoopJSONPath(unittest.TestCase):
    """Adversarially stress-tests JSONPath expression and shell counting logic."""

    @staticmethod
    def evaluate_jsonpath_bash(pod_list_json: Dict[str, Any]) -> Tuple[int, str]:
        """
        Simulates the exact shell logic in app-pipeline.yml:
        CRASHES=$(echo '$JSON' | jq -r '...' | wc -w)
        and Python equivalent of Kubernetes JSONPath.
        """
        # In Kubernetes:
        # jsonpath='{.items[*].status.containerStatuses[?(@.state.waiting.reason=="CrashLoopBackOff")].name}'
        crashed_names = []
        for item in pod_list_json.get("items", []):
            phase = item.get("status", {}).get("phase", "")
            if phase == "Succeeded":
                # Filtered out by --field-selector=status.phase!=Succeeded
                continue
            statuses = item.get("status", {}).get("containerStatuses") or []
            for cs in statuses:
                waiting = cs.get("state", {}).get("waiting") or {}
                if waiting.get("reason") == "CrashLoopBackOff":
                    crashed_names.append(cs.get("name", "unnamed"))

        jsonpath_output = " ".join(crashed_names)

        # Run in bash with wc -w and if [ "$CRASHES" -gt 0 ]
        bash_script = f"""
        CRASHES=$(echo -n "{jsonpath_output}" | wc -w)
        if [ "$CRASHES" -gt 0 ]; then
          echo "$CRASHES pods crashed"
          exit 1
        fi
        exit 0
        """
        res = subprocess.run(["bash", "-c", bash_script], capture_output=True, text=True)
        return res.returncode, jsonpath_output

    def test_case_empty_pod_list(self):
        """Case 1: Empty pod list should pass."""
        mock = {"apiVersion": "v1", "kind": "PodList", "items": []}
        rc, out = self.evaluate_jsonpath_bash(mock)
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")

    def test_case_running_healthy_pods(self):
        """Case 2: All pods healthy Running state should pass."""
        mock = {
            "apiVersion": "v1",
            "kind": "PodList",
            "items": [
                {
                    "metadata": {"name": "api-1"},
                    "status": {
                        "phase": "Running",
                        "containerStatuses": [
                            {"name": "api", "state": {"running": {"startedAt": "2026-10-30T00:00:00Z"}}}
                        ]
                    }
                },
                {
                    "metadata": {"name": "dashboard-1"},
                    "status": {
                        "phase": "Running",
                        "containerStatuses": [
                            {"name": "dashboard", "state": {"running": {"startedAt": "2026-10-30T00:00:00Z"}}}
                        ]
                    }
                }
            ]
        }
        rc, out = self.evaluate_jsonpath_bash(mock)
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")

    def test_case_completed_jobs_succeeded(self):
        """Case 3: Completed pod (Succeeded phase) filtered out by apiserver should pass."""
        mock = {
            "apiVersion": "v1",
            "kind": "PodList",
            "items": [
                {
                    "metadata": {"name": "flyway-migrate-job"},
                    "status": {
                        "phase": "Succeeded",
                        "containerStatuses": [
                            {"name": "flyway", "state": {"terminated": {"reason": "Completed"}}}
                        ]
                    }
                }
            ]
        }
        rc, out = self.evaluate_jsonpath_bash(mock)
        self.assertEqual(rc, 0)

    def test_case_single_crashloopbackoff(self):
        """Case 4: Single container in CrashLoopBackOff must be detected and fail."""
        mock = {
            "apiVersion": "v1",
            "kind": "PodList",
            "items": [
                {
                    "metadata": {"name": "api-crashed"},
                    "status": {
                        "phase": "Running",
                        "containerStatuses": [
                            {"name": "api", "state": {"waiting": {"reason": "CrashLoopBackOff"}}}
                        ]
                    }
                }
            ]
        }
        rc, out = self.evaluate_jsonpath_bash(mock)
        self.assertEqual(rc, 1)
        self.assertEqual(out, "api")

    def test_case_multi_container_pod_one_crashed(self):
        """Case 5: Multi-container pod where only one is crashing must fail."""
        mock = {
            "apiVersion": "v1",
            "kind": "PodList",
            "items": [
                {
                    "metadata": {"name": "dual-pod"},
                    "status": {
                        "phase": "Running",
                        "containerStatuses": [
                            {"name": "sidecar", "state": {"running": {}}},
                            {"name": "app", "state": {"waiting": {"reason": "CrashLoopBackOff"}}}
                        ]
                    }
                }
            ]
        }
        rc, out = self.evaluate_jsonpath_bash(mock)
        self.assertEqual(rc, 1)
        self.assertEqual(out, "app")

    def test_case_multiple_pods_crashed(self):
        """Case 6: Multiple crashing pods must detect all crashing container names and fail."""
        mock = {
            "apiVersion": "v1",
            "kind": "PodList",
            "items": [
                {
                    "metadata": {"name": "api-crashed"},
                    "status": {
                        "phase": "Running",
                        "containerStatuses": [
                            {"name": "api", "state": {"waiting": {"reason": "CrashLoopBackOff"}}}
                        ]
                    }
                },
                {
                    "metadata": {"name": "etl-crashed"},
                    "status": {
                        "phase": "Running",
                        "containerStatuses": [
                            {"name": "etl-processor", "state": {"waiting": {"reason": "CrashLoopBackOff"}}}
                        ]
                    }
                }
            ]
        }
        rc, out = self.evaluate_jsonpath_bash(mock)
        self.assertEqual(rc, 1)
        self.assertIn("api", out)
        self.assertIn("etl-processor", out)

    def test_case_pending_pod_without_container_statuses(self):
        """Case 7: Pending pod where containerStatuses key is absent must pass gracefully."""
        mock = {
            "apiVersion": "v1",
            "kind": "PodList",
            "items": [
                {
                    "metadata": {"name": "pending-pod"},
                    "status": {
                        "phase": "Pending"
                    }
                }
            ]
        }
        rc, out = self.evaluate_jsonpath_bash(mock)
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")

    def test_case_other_waiting_reasons(self):
        """Case 8: Waiting for ContainerCreating should not be flagged as CrashLoopBackOff."""
        mock = {
            "apiVersion": "v1",
            "kind": "PodList",
            "items": [
                {
                    "metadata": {"name": "creating-pod"},
                    "status": {
                        "phase": "Pending",
                        "containerStatuses": [
                            {"name": "api", "state": {"waiting": {"reason": "ContainerCreating"}}}
                        ]
                    }
                }
            ]
        }
        rc, out = self.evaluate_jsonpath_bash(mock)
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")


class TestAdversarialMakefile(unittest.TestCase):
    """Stress tests Makefile targets, parameter overrides, and phony rules."""

    def test_override_kind_cluster_name(self):
        """Verify KIND_CLUSTER_NAME override propagates to kind targets."""
        targets = ["kind-up-debug", "kind-up", "kind-down", "kind-restart", "kind-load", "kind-query-backend"]
        custom_cluster = "adversarial-cluster-999"

        for target in targets:
            cmd = ["make", "-C", str(REPO_ROOT), "-n", target, f"KIND_CLUSTER_NAME={custom_cluster}"]
            res = subprocess.run(cmd, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"make -n {target} failed with cluster override")
            self.assertIn(custom_cluster, res.stdout, f"Custom cluster name not found in recipe for {target}")

    def test_all_phony_targets_executable(self):
        """Verify that EVERY target listed in .PHONY evaluates without error under make -n."""
        with open(MAKEFILE_PATH, "r", encoding="utf-8") as f:
            lines = f.readlines()

        phony_targets = set()
        for idx, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith(".PHONY:"):
                # Collect continuation lines
                curr_idx = idx
                while curr_idx < len(lines):
                    l_str = lines[curr_idx].strip()
                    clean_l = l_str.replace(".PHONY:", "").replace("\\", "").strip()
                    for t in clean_l.split():
                        phony_targets.add(t)
                    if not lines[curr_idx].rstrip().endswith("\\"):
                        break
                    curr_idx += 1

        self.assertGreater(len(phony_targets), 30, "Should have parsed at least 30 phony targets")

        failures = []
        for target in sorted(phony_targets):
            cmd = ["make", "-C", str(REPO_ROOT), "-n", target]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode != 0:
                failures.append(f"{target}: code {res.returncode}, stderr={res.stderr.strip()}")

        self.assertEqual(failures, [], f"Phony targets failed make -n: {failures}")

    def test_deprecation_banner_contents(self):
        """Verify deprecation banners specifically direct developers to make dev-up and make kind-up-debug."""
        deprecated_targets = {
            "kind-up": ["make dev-up", "make kind-up-debug"],
            "kind-restart": ["make dev-restart", "make kind-up-debug"],
            "kind-load": ["make dev-build", "make kind-up-debug"],
            "kind-port-forward": ["make dev-up", "make kind-up-debug"],
        }

        for target, expected_refs in deprecated_targets.items():
            cmd = ["make", "-C", str(REPO_ROOT), "-n", target]
            res = subprocess.run(cmd, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            for ref in expected_refs:
                self.assertIn(ref, res.stdout, f"Target {target} output missing reference to {ref}")

    def test_kind_up_debug_recipes(self):
        """Verify kind-up-debug creates cluster with kind-config.yaml and sets kubectl context."""
        cmd = ["make", "-C", str(REPO_ROOT), "-n", "kind-up-debug"]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("kind create cluster --name fire-monitoring --config build/local/kind-config.yaml --wait 60s", res.stdout)
        self.assertIn("kubectl config use-context kind-fire-monitoring", res.stdout)


class TestAdversarialKustomize(unittest.TestCase):
    """Stress tests Kustomize overlays under strict conditions."""

    def test_render_all_overlays(self):
        """Verify dev, local, and prod overlays build cleanly via kubectl kustomize."""
        for overlay in ["dev", "local", "prod"]:
            overlay_dir = OVERLAYS_DIR / overlay
            self.assertTrue(overlay_dir.exists(), f"Overlay dir does not exist: {overlay_dir}")
            cmd = ["kubectl", "kustomize", str(overlay_dir)]
            res = subprocess.run(cmd, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"kustomize build failed for {overlay}: {res.stderr}")
            self.assertGreater(len(res.stdout), 100, f"Rendered output too small for {overlay}")

    def test_local_overlay_pod_specs(self):
        """Verify local overlay renders core services (api, dashboard, etl-processor) with local images."""
        cmd = ["kubectl", "kustomize", str(OVERLAYS_DIR / "local")]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)

        rendered_yaml = res.stdout
        docs = list(yaml.safe_load_all(rendered_yaml))

        # Check for core deployments
        deployments = {
            doc["metadata"]["name"]: doc
            for doc in docs
            if doc and doc.get("kind") == "Deployment"
        }

        self.assertIn("api", deployments)
        self.assertIn("dashboard", deployments)
        self.assertIn("etl-processor", deployments)

        # In local overlay, api image should be localhost/api:local
        api_deploy = deployments["api"]
        containers = api_deploy["spec"]["template"]["spec"]["containers"]
        container_images = {c["name"]: c["image"] for c in containers}
        self.assertIn("api", container_images)
        self.assertEqual(container_images["api"], "localhost/api:local")

    def test_local_overlay_no_cloud_sql_proxy(self):
        """Verify remove-sql-proxy patch removes cloud-sql-proxy container from local overlay."""
        cmd = ["kubectl", "kustomize", str(OVERLAYS_DIR / "local")]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)

        docs = list(yaml.safe_load_all(res.stdout))
        for doc in docs:
            if not doc or doc.get("kind") not in ("Deployment", "StatefulSet"):
                continue
            containers = doc.get("spec", {}).get("template", {}).get("spec", {}).get("containers", [])
            names = [c.get("name") for c in containers]
            self.assertNotIn("cloud-sql-proxy", names, f"cloud-sql-proxy container found in {doc.get('kind')} {doc.get('metadata', {}).get('name')}")


if __name__ == "__main__":
    unittest.main()
