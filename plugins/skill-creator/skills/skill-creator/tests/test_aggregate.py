"""Tests for scripts/aggregate_benchmark.py."""

import json
import math

import pytest

from scripts.aggregate_benchmark import (
    calculate_stats,
    load_run_results,
    aggregate_results,
    generate_benchmark,
    generate_markdown,
)


class TestCalculateStats:
    def test_empty(self):
        result = calculate_stats([])
        assert result == {"mean": 0.0, "stddev": 0.0, "min": 0.0, "max": 0.0}

    def test_single_value(self):
        result = calculate_stats([5.0])
        assert result["mean"] == 5.0
        assert result["stddev"] == 0.0
        assert result["min"] == 5.0
        assert result["max"] == 5.0

    def test_multiple_values(self):
        result = calculate_stats([2.0, 4.0, 6.0])
        assert result["mean"] == 4.0
        assert result["min"] == 2.0
        assert result["max"] == 6.0

    def test_stddev_sample(self):
        """Uses sample stddev (n-1 denominator)."""
        result = calculate_stats([2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0])
        # Known sample stddev for this dataset
        expected_mean = 5.0
        expected_var = sum((x - expected_mean) ** 2 for x in [2, 4, 4, 4, 5, 5, 7, 9]) / 7
        expected_stddev = math.sqrt(expected_var)
        assert abs(result["stddev"] - round(expected_stddev, 4)) < 0.001

    def test_identical_values(self):
        result = calculate_stats([3.0, 3.0, 3.0])
        assert result["mean"] == 3.0
        assert result["stddev"] == 0.0

    def test_rounding(self):
        result = calculate_stats([1.0, 2.0, 3.0])
        # mean = 2.0, stddev = 1.0 — all should be rounded to 4 decimals
        assert isinstance(result["mean"], float)
        # Check string representation doesn't have excessive decimals
        assert len(str(result["mean"]).split(".")[-1]) <= 4


class TestLoadRunResults:
    def test_workspace_layout(self, benchmark_workspace):
        results = load_run_results(benchmark_workspace)
        assert "with_skill" in results
        assert "without_skill" in results
        assert len(results["with_skill"]) == 4  # 2 evals * 2 runs
        assert len(results["without_skill"]) == 4

    def test_legacy_layout(self, tmp_path, sample_grading):
        """Legacy layout has runs/ subdirectory."""
        runs_dir = tmp_path / "runs"
        run_dir = runs_dir / "eval-1" / "with_skill" / "run-1"
        run_dir.mkdir(parents=True)
        (run_dir / "grading.json").write_text(json.dumps(sample_grading))
        results = load_run_results(tmp_path)
        assert "with_skill" in results
        assert len(results["with_skill"]) == 1

    def test_empty_directory(self, tmp_path):
        results = load_run_results(tmp_path)
        assert results == {}

    def test_malformed_grading_json(self, tmp_path):
        run_dir = tmp_path / "eval-1" / "config" / "run-1"
        run_dir.mkdir(parents=True)
        (run_dir / "grading.json").write_text("not valid json{{{")
        results = load_run_results(tmp_path)
        # Should skip malformed files, not crash
        assert results.get("config", []) == []

    def test_missing_grading_json(self, tmp_path):
        run_dir = tmp_path / "eval-1" / "config" / "run-1"
        run_dir.mkdir(parents=True)
        # No grading.json
        results = load_run_results(tmp_path)
        assert results.get("config", []) == []

    def test_extracts_metrics(self, benchmark_workspace):
        results = load_run_results(benchmark_workspace)
        run = results["with_skill"][0]
        assert "pass_rate" in run
        assert "time_seconds" in run
        assert "tool_calls" in run
        assert "expectations" in run
        assert run["pass_rate"] == 0.75

    def test_timing_from_sibling_file(self, tmp_path):
        """Falls back to timing.json when grading.json has no timing."""
        run_dir = tmp_path / "eval-1" / "config" / "run-1"
        run_dir.mkdir(parents=True)
        grading = {"summary": {"pass_rate": 1.0, "passed": 1, "failed": 0, "total": 1}, "expectations": []}
        (run_dir / "grading.json").write_text(json.dumps(grading))
        (run_dir / "timing.json").write_text(json.dumps({"total_duration_seconds": 5.5, "total_tokens": 500}))
        results = load_run_results(tmp_path)
        run = results["config"][0]
        assert run["time_seconds"] == 5.5
        assert run["tokens"] == 500

    def test_eval_metadata(self, tmp_path, sample_grading):
        """Uses eval_metadata.json for eval_id when present."""
        eval_dir = tmp_path / "eval-1"
        eval_dir.mkdir()
        (eval_dir / "eval_metadata.json").write_text(json.dumps({"eval_id": "custom-id"}))
        run_dir = eval_dir / "with_skill" / "run-1"
        run_dir.mkdir(parents=True)
        (run_dir / "grading.json").write_text(json.dumps(sample_grading))
        results = load_run_results(tmp_path)
        assert results["with_skill"][0]["eval_id"] == "custom-id"


class TestAggregateResults:
    def test_basic(self, benchmark_workspace):
        results = load_run_results(benchmark_workspace)
        summary = aggregate_results(results)
        assert "with_skill" in summary
        assert "without_skill" in summary
        assert "delta" in summary
        assert "pass_rate" in summary["with_skill"]
        assert "time_seconds" in summary["with_skill"]
        assert "tokens" in summary["with_skill"]

    def test_delta_calculation(self):
        results = {
            "config_a": [
                {"pass_rate": 0.9, "time_seconds": 10.0, "tokens": 100},
            ],
            "config_b": [
                {"pass_rate": 0.7, "time_seconds": 15.0, "tokens": 200},
            ],
        }
        summary = aggregate_results(results)
        assert summary["delta"]["pass_rate"] == "+0.20"
        assert summary["delta"]["time_seconds"] == "-5.0"
        assert summary["delta"]["tokens"] == "-100"

    def test_single_config(self):
        results = {
            "only_config": [
                {"pass_rate": 0.8, "time_seconds": 5.0, "tokens": 50},
            ],
        }
        summary = aggregate_results(results)
        assert "only_config" in summary
        assert "delta" in summary

    def test_empty_config(self):
        results = {"empty": []}
        summary = aggregate_results(results)
        assert summary["empty"]["pass_rate"]["mean"] == 0.0


class TestGenerateBenchmark:
    def test_structure(self, benchmark_workspace):
        benchmark = generate_benchmark(benchmark_workspace, "test-skill", "/path/to/skill")
        assert "metadata" in benchmark
        assert "runs" in benchmark
        assert "run_summary" in benchmark
        assert "notes" in benchmark
        assert benchmark["metadata"]["skill_name"] == "test-skill"
        assert len(benchmark["runs"]) == 8  # 2 configs * 2 evals * 2 runs

    def test_runs_have_required_fields(self, benchmark_workspace):
        benchmark = generate_benchmark(benchmark_workspace)
        for run in benchmark["runs"]:
            assert "eval_id" in run
            assert "configuration" in run
            assert "run_number" in run
            assert "result" in run
            assert "expectations" in run


class TestGenerateMarkdown:
    def test_basic(self, benchmark_workspace):
        benchmark = generate_benchmark(benchmark_workspace, "test-skill")
        md = generate_markdown(benchmark)
        assert "# Skill Benchmark: test-skill" in md
        assert "| Metric |" in md
        assert "Pass Rate" in md
        assert "Time" in md
        assert "Tokens" in md

    def test_contains_delta(self, benchmark_workspace):
        benchmark = generate_benchmark(benchmark_workspace)
        md = generate_markdown(benchmark)
        # Delta column should have +/- values
        assert "+" in md or "-" in md
