"""Tests for scripts/generate_report.py — HTML generation and validity."""

import pytest

from scripts.generate_report import generate_html
from conftest import assert_valid_html, assert_html_has_doctype


class TestGenerateHtml:
    def test_basic_output(self, sample_loop_output):
        html = generate_html(sample_loop_output)
        assert "<!DOCTYPE html>" in html
        assert "</html>" in html

    def test_valid_html_structure(self, sample_loop_output):
        html = generate_html(sample_loop_output)
        assert_html_has_doctype(html)
        assert_valid_html(html)

    def test_auto_refresh(self, sample_loop_output):
        html = generate_html(sample_loop_output, auto_refresh=True)
        assert 'http-equiv="refresh"' in html
        assert 'content="5"' in html

    def test_no_auto_refresh_by_default(self, sample_loop_output):
        html = generate_html(sample_loop_output, auto_refresh=False)
        assert 'http-equiv="refresh"' not in html

    def test_skill_name_in_title(self, sample_loop_output):
        html = generate_html(sample_loop_output, skill_name="my-cool-skill")
        assert "my-cool-skill" in html

    def test_html_escaping(self, sample_loop_output):
        """Descriptions with HTML special chars should be escaped."""
        sample_loop_output["original_description"] = '<script>alert("xss")</script>'
        sample_loop_output["best_description"] = 'Use "quotes" & <angles>'
        html = generate_html(sample_loop_output)
        assert "<script>" not in html
        assert "&lt;script&gt;" in html
        assert "&amp;" in html

    def test_query_escaping(self):
        """Query text with HTML chars should be escaped in column headers."""
        data = {
            "original_description": "test",
            "best_description": "test",
            "history": [
                {
                    "iteration": 1,
                    "description": "test",
                    "train_passed": 1,
                    "train_failed": 0,
                    "train_total": 1,
                    "train_results": [
                        {"query": '<img onerror="alert(1)">', "should_trigger": True, "pass": True, "triggers": 1, "runs": 1},
                    ],
                    "test_results": [],
                    "passed": 1,
                    "failed": 0,
                    "total": 1,
                    "results": [],
                },
            ],
        }
        html = generate_html(data)
        assert '<img onerror' not in html
        assert "&lt;img" in html

    def test_score_classification(self, sample_loop_output):
        html = generate_html(sample_loop_output)
        # Iteration 2 has all pass → should have score-good
        assert "score-good" in html

    def test_best_row_highlighted(self, sample_loop_output):
        html = generate_html(sample_loop_output)
        assert "best-row" in html

    def test_empty_history(self):
        data = {
            "original_description": "test",
            "best_description": "test",
            "history": [],
        }
        html = generate_html(data)
        assert_valid_html(html)
        assert "<!DOCTYPE html>" in html

    def test_train_and_test_columns(self, sample_loop_output):
        html = generate_html(sample_loop_output)
        # Test column has different styling
        assert "test-col" in html
        assert "test-result" in html

    def test_contains_description_text(self, sample_loop_output):
        html = generate_html(sample_loop_output)
        assert "Original description" in html
        assert "Improved description" in html

    def test_auto_refresh_still_valid_html(self, sample_loop_output):
        html = generate_html(sample_loop_output, auto_refresh=True)
        assert_valid_html(html)

    def test_special_chars_in_skill_name(self, sample_loop_output):
        html = generate_html(sample_loop_output, skill_name='<script>"test"</script>')
        assert "<script>" not in html
        assert_valid_html(html)
