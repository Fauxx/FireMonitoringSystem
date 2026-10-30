#!/usr/bin/env python3
"""
Self-contained E2E Test Suite Runner for Kind-to-CI Migration.
Target Repository: /home/zett/RiderProjects/FireMonitoringSystem
Location: tests/e2e_ci_migration/test_runner.py

Executes test suites across Tiers 1-4, provides detailed breakdown by tier and feature,
and returns exit code 0 if all tests pass, non-zero otherwise.
"""

import sys
import os
import time
import argparse
import unittest
import json
from pathlib import Path

# Ensure repo root is in sys.path
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tests.e2e_ci_migration.test_tier1_features import TestTier1FeatureCoverage
from tests.e2e_ci_migration.test_tier2_boundaries import TestTier2BoundaryCases
from tests.e2e_ci_migration.test_tier3_interactions import TestTier3Interactions
from tests.e2e_ci_migration.test_tier4_scenarios import TestTier4RealWorldScenarios


def build_test_suite(tier: int = None, feature: str = None) -> unittest.TestSuite:
    """Builds a test suite filtered by tier and/or feature."""
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    tier_classes = {
        1: [TestTier1FeatureCoverage],
        2: [TestTier2BoundaryCases],
        3: [TestTier3Interactions],
        4: [TestTier4RealWorldScenarios],
    }

    selected_classes = []
    if tier:
        selected_classes = tier_classes.get(tier, [])
    else:
        for classes in tier_classes.values():
            selected_classes.extend(classes)

    for test_class in selected_classes:
        test_names = loader.getTestCaseNames(test_class)
        for name in test_names:
            if feature:
                # Feature filter: e.g. 'F1', 'f1', 'F12'
                feat_lower = feature.lower()
                if not (f"_{feat_lower}_" in name.lower() or f"_{feat_lower}" in name.lower() or f"{feat_lower}_" in name.lower()):
                    continue
            suite.addTest(test_class(name))

    return suite


def run_tests(args) -> int:
    """Runs the test suite and prints formatted summary."""
    print("=" * 80)
    print("   FIRE MONITORING SYSTEM — KIND-TO-CI MIGRATION E2E TEST SUITE")
    print("=" * 80)
    print(f"Target Directory : {REPO_ROOT}")
    print(f"Selected Tier    : {args.tier if args.tier else 'All (Tiers 1-4)'}")
    print(f"Feature Filter   : {args.feature if args.feature else 'All (F1 - F20)'}")
    print("-" * 80)

    suite = build_test_suite(tier=args.tier, feature=args.feature)
    total_tests = suite.countTestCases()
    print(f"Total Test Cases Loaded: {total_tests}\n")

    if args.list:
        print("Discovered Test Cases:")
        for test in suite:
            print(f"  • {test.id()}")
        return 0

    start_time = time.time()
    verbosity = 2 if args.verbose else 1
    runner = unittest.TextTestRunner(verbosity=verbosity, stream=sys.stdout)
    result = runner.run(suite)
    duration = time.time() - start_time

    passed = total_tests - len(result.failures) - len(result.errors) - len(result.skipped)

    print("\n" + "=" * 80)
    print("                           TEST RUN SUMMARY")
    print("=" * 80)
    print(f"  Total Run    : {result.testsRun}")
    print(f"  Passed       : {passed} ({(passed / total_tests * 100):.1f}%)" if total_tests else "  Passed: 0")
    print(f"  Failures     : {len(result.failures)}")
    print(f"  Errors       : {len(result.errors)}")
    print(f"  Skipped      : {len(result.skipped)}")
    print(f"  Elapsed Time : {duration:.2f} seconds")
    print("-" * 80)

    if result.failures:
        print("\n❌ FAILED TESTS SUMMARY:")
        for failure in result.failures:
            test_obj, err_msg = failure
            # Extract first line of error
            first_err_line = err_msg.strip().splitlines()[-1]
            print(f"  [FAIL] {test_obj.id()}: {first_err_line}")

    if result.errors:
        print("\n💥 ERROR TESTS SUMMARY:")
        for error in result.errors:
            test_obj, err_msg = error
            first_err_line = err_msg.strip().splitlines()[-1]
            print(f"  [ERR]  {test_obj.id()}: {first_err_line}")

    # Optional JSON output
    if args.json_output:
        json_path = Path(args.json_output).resolve()
        data = {
            "total": total_tests,
            "run": result.testsRun,
            "passed": passed,
            "failures": len(result.failures),
            "errors": len(result.errors),
            "skipped": len(result.skipped),
            "duration": duration,
            "failed_tests": [test.id() for test, _ in result.failures],
            "error_tests": [test.id() for test, _ in result.errors],
        }
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        print(f"\nReport written to: {json_path}")

    print("=" * 80)
    if result.wasSuccessful():
        print("🎉 STATUS: ALL TESTS PASSED SUCCESSFULLY (Exit Code 0)")
        return 0
    else:
        print("⚠️ STATUS: TEST SUITE FAILED — DEFECTS DETECTED (Exit Code 1)")
        return 1


def main():
    parser = argparse.ArgumentParser(description="Kind-to-CI Migration E2E Test Suite Runner")
    parser.add_argument("--tier", type=int, choices=[1, 2, 3, 4], help="Run a specific tier (1, 2, 3, or 4)")
    parser.add_argument("--feature", type=str, help="Filter by feature (e.g. F1, F10, F13)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose test execution output")
    parser.add_argument("--list", "-l", action="store_true", help="List tests without executing")
    parser.add_argument("--json-output", type=str, help="Path to write JSON test report")

    args = parser.parse_args()
    sys.exit(run_tests(args))


if __name__ == "__main__":
    main()
