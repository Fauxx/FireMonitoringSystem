"""
Helpers and utilities for Kind-to-CI Migration E2E Test Suite.
Repository: /home/zett/RiderProjects/FireMonitoringSystem
"""

import os
import re
import sys
import json
import shutil
import hashlib
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional, Set, Tuple

try:
    import yaml
except ImportError:
    raise ImportError("PyYAML is required for E2E tests. Please install PyYAML.")

REPO_ROOT = Path("/home/zett/RiderProjects/FireMonitoringSystem").resolve()
WORKFLOWS_DIR = REPO_ROOT / ".github" / "workflows"
MAKEFILE_PATH = REPO_ROOT / "Makefile"
OVERLAYS_DIR = REPO_ROOT / "infrastructure" / "k8s" / "overlays"


def load_yaml_file(path: Path) -> Dict[str, Any]:
    """Loads and parses a YAML file safely, normalizing GitHub Action 'on:' key."""
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    data = yaml.safe_load(content) or {}
    if isinstance(data, dict) and True in data:
        data["on"] = data.pop(True)
    return data


def read_file_text(path: Path) -> str:
    """Reads raw text from a file."""
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def load_workflow(filename: str) -> Dict[str, Any]:
    """Loads a workflow YAML from .github/workflows/."""
    return load_yaml_file(WORKFLOWS_DIR / filename)


def get_workflow_job(workflow_data: Dict[str, Any], job_id: str) -> Dict[str, Any]:
    """Retrieves a job by its ID from a workflow data dict."""
    jobs = workflow_data.get("jobs", {})
    return jobs.get(job_id, {})


def get_job_steps(job_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Retrieves the list of steps for a job."""
    return job_data.get("steps", [])


def find_step(steps: List[Dict[str, Any]],
              name_substr: Optional[str] = None,
              uses_substr: Optional[str] = None,
              run_substr: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """Finds a step matching all given non-None criteria."""
    for step in steps:
        if name_substr and name_substr.lower() not in str(step.get("name", "")).lower():
            continue
        if uses_substr and uses_substr.lower() not in str(step.get("uses", "")).lower():
            continue
        if run_substr and run_substr.lower() not in str(step.get("run", "")).lower():
            continue
        return step
    return None


class MakefileInfo:
    """Parsed representation of a GNU Makefile."""
    def __init__(self, raw_text: str):
        self.raw_text = raw_text
        self.lines = raw_text.splitlines()
        self.line_count = len(self.lines)
        self.targets: Dict[str, Dict[str, Any]] = {}
        self.phony_targets: Set[str] = set()
        self.variables: Dict[str, str] = {}
        self._parse()

    def _parse(self):
        current_target = None
        current_recipes = []
        current_prereqs = []
        target_start_line = 0

        for line_no, line in enumerate(self.lines, start=1):
            stripped = line.strip()

            # Variable assignment
            var_match = re.match(r"^([A-Za-z0-9_]+)\s*(\?=|:=|=|\+=)\s*(.*)$", line)
            if var_match and not line.startswith("\t"):
                var_name = var_match.group(1)
                var_val = var_match.group(3).strip()
                self.variables[var_name] = var_val

            # .PHONY collection
            if stripped.startswith(".PHONY:"):
                # can be multi-line with backslash
                rest = stripped.replace(".PHONY:", "").replace("\\", "").strip()
                for t in rest.split():
                    self.phony_targets.add(t)
                continue

            # Check if this line is part of a continuing .PHONY line
            if line_no > 1 and self.lines[line_no - 2].rstrip().endswith("\\"):
                prev_line = self.lines[line_no - 2].strip()
                if ".PHONY" in prev_line or any(p in prev_line for p in self.phony_targets):
                    for t in stripped.replace("\\", "").split():
                        self.phony_targets.add(t)

            # Target definition
            target_match = re.match(r"^([a-zA-Z0-9_\-\.]+)\s*:(?!=)\s*(.*)$", line)
            if target_match and not line.startswith("\t"):
                if current_target:
                    self.targets[current_target] = {
                        "recipes": current_recipes,
                        "prereqs": current_prereqs,
                        "line_no": target_start_line
                    }
                current_target = target_match.group(1)
                prereqs_str = target_match.group(2).strip()
                current_prereqs = [p for p in prereqs_str.split() if p and p != "\\"]
                current_recipes = []
                target_start_line = line_no
                continue

            # Recipe lines
            if line.startswith("\t") and current_target:
                current_recipes.append(line[1:])
            elif stripped == "" or stripped.startswith("#"):
                continue
            else:
                if current_target and not line.endswith("\\"):
                    self.targets[current_target] = {
                        "recipes": current_recipes,
                        "prereqs": current_prereqs,
                        "line_no": target_start_line
                    }
                    current_target = None
                    current_recipes = []
                    current_prereqs = []

        if current_target:
            self.targets[current_target] = {
                "recipes": current_recipes,
                "prereqs": current_prereqs,
                "line_no": target_start_line
            }


def parse_makefile(path: Path = MAKEFILE_PATH) -> MakefileInfo:
    """Reads and parses the repository Makefile."""
    text = read_file_text(path)
    return MakefileInfo(text)


def run_make_dry_run(target: str, path: Path = REPO_ROOT, timeout: int = 5) -> Tuple[int, str, str]:
    """
    Executes 'make -n <target>' without performing actions.
    Safe dry-run: returns (exit_code, stdout, stderr).
    """
    cmd = ["make", "-C", str(path), "-n", target]
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout
        )
        return proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Timeout expired during make dry-run"
    except Exception as e:
        return -1, "", str(e)


def run_kustomize_build(overlay_name: str, timeout: int = 10) -> Tuple[int, str, str]:
    """
    Executes 'kustomize build infrastructure/k8s/overlays/<overlay_name>'.
    Safe read-only operation: returns (exit_code, stdout, stderr).
    """
    overlay_path = OVERLAYS_DIR / overlay_name
    if not overlay_path.exists():
        return -1, "", f"Overlay path not found: {overlay_path}"
    
    cmd = ["kustomize", "build", str(overlay_path)]
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout
        )
        return proc.returncode, proc.stdout, proc.stderr
    except FileNotFoundError:
        # Fallback to 'kubectl kustomize' if standalone kustomize not in PATH
        cmd = ["kubectl", "kustomize", str(overlay_path)]
        try:
            proc = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=timeout
            )
            return proc.returncode, proc.stdout, proc.stderr
        except Exception as e:
            return -1, "", str(e)
    except Exception as e:
        return -1, "", str(e)


def get_host_kind_clusters() -> List[str]:
    """Queries existing Kind clusters on host safely via 'kind get clusters'."""
    try:
        proc = subprocess.run(
            ["kind", "get", "clusters"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=5
        )
        if proc.returncode == 0:
            return [line.strip() for line in proc.stdout.splitlines() if line.strip()]
        return []
    except Exception:
        return []


def get_host_docker_containers() -> List[str]:
    """Queries running Docker/Podman container IDs on host safely."""
    for cli in ["docker", "podman"]:
        try:
            proc = subprocess.run(
                [cli, "ps", "-q"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=5
            )
            if proc.returncode == 0:
                return [line.strip() for line in proc.stdout.splitlines() if line.strip()]
        except Exception:
            continue
    return []


def get_host_state_snapshot() -> Dict[str, Any]:
    """Captures a snapshot of host Kind and Docker states."""
    clusters = get_host_kind_clusters()
    containers = get_host_docker_containers()
    clusters_hash = hashlib.sha256(" ".join(sorted(clusters)).encode()).hexdigest()
    containers_hash = hashlib.sha256(" ".join(sorted(containers)).encode()).hexdigest()
    return {
        "clusters": clusters,
        "clusters_hash": clusters_hash,
        "containers": containers,
        "containers_hash": containers_hash,
    }
