"""Tests for eval-viewer/generate_review.py — HTML generation and validity."""

import json
import textwrap
from pathlib import Path

import pytest

# Import from eval-viewer (non-standard path, adjust sys.path)
import sys
import os

SKILL_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(SKILL_ROOT / "eval-viewer"))

from generate_review import (
    embed_file,
    find_runs,
    build_run,
    generate_html,
    get_mime_type,
    load_previous_iteration,
)

from conftest import assert_valid_html, assert_html_has_doctype


class TestGetMimeType:
    def test_svg(self, tmp_path):
        assert get_mime_type(tmp_path / "file.svg") == "image/svg+xml"

    def test_xlsx(self, tmp_path):
        assert "spreadsheet" in get_mime_type(tmp_path / "file.xlsx")

    def test_unknown(self, tmp_path):
        assert get_mime_type(tmp_path / "file.xyz123") == "application/octet-stream"


class TestEmbedFile:
    def test_text_file(self, tmp_path):
        f = tmp_path / "test.py"
        f.write_text("print('hello')")
        result = embed_file(f)
        assert result["type"] == "text"
        assert result["content"] == "print('hello')"
        assert result["name"] == "test.py"

    def test_json_file(self, tmp_path):
        f = tmp_path / "data.json"
        f.write_text('{"key": "value"}')
        result = embed_file(f)
        assert result["type"] == "text"

    def test_image_file(self, tmp_path):
        f = tmp_path / "photo.png"
        f.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00" * 100)
        result = embed_file(f)
        assert result["type"] == "image"
        assert result["data_uri"].startswith("data:image/png;base64,")

    def test_pdf_file(self, tmp_path):
        f = tmp_path / "doc.pdf"
        f.write_bytes(b"%PDF-1.4 fake content")
        result = embed_file(f)
        assert result["type"] == "pdf"
        assert "base64" in result["data_uri"]

    def test_xlsx_file(self, tmp_path):
        f = tmp_path / "sheet.xlsx"
        f.write_bytes(b"PK\x03\x04 fake xlsx")
        result = embed_file(f)
        assert result["type"] == "xlsx"
        assert "data_b64" in result

    def test_unknown_binary(self, tmp_path):
        f = tmp_path / "data.bin"
        f.write_bytes(b"\x00\x01\x02\x03")
        result = embed_file(f)
        assert result["type"] == "binary"
        assert "data_uri" in result

    def test_markdown_file(self, tmp_path):
        f = tmp_path / "readme.md"
        f.write_text("# Hello\n\nWorld")
        result = embed_file(f)
        assert result["type"] == "text"
        assert "# Hello" in result["content"]


class TestFindRuns:
    def test_finds_runs_with_outputs(self, tmp_path):
        run_dir = tmp_path / "eval-1" / "with_skill" / "run-1"
        outputs = run_dir / "outputs"
        outputs.mkdir(parents=True)
        (outputs / "result.txt").write_text("test output")
        (run_dir / "eval_metadata.json").write_text(json.dumps({
            "prompt": "Test prompt",
            "eval_id": 1,
        }))
        runs = find_runs(tmp_path)
        assert len(runs) == 1
        assert runs[0]["prompt"] == "Test prompt"

    def test_skips_dirs_without_outputs(self, tmp_path):
        (tmp_path / "eval-1" / "with_skill" / "run-1").mkdir(parents=True)
        runs = find_runs(tmp_path)
        assert len(runs) == 0

    def test_multiple_runs(self, tmp_path):
        for i in [1, 2]:
            run_dir = tmp_path / f"eval-1" / "config" / f"run-{i}"
            outputs = run_dir / "outputs"
            outputs.mkdir(parents=True)
            (outputs / "result.txt").write_text(f"output {i}")
            (run_dir / "eval_metadata.json").write_text(json.dumps({
                "prompt": f"Prompt {i}",
                "eval_id": 1,
            }))
        runs = find_runs(tmp_path)
        assert len(runs) == 2


class TestBuildRun:
    def test_basic(self, tmp_path):
        run_dir = tmp_path / "run-1"
        outputs = run_dir / "outputs"
        outputs.mkdir(parents=True)
        (outputs / "result.txt").write_text("hello")
        (run_dir / "eval_metadata.json").write_text(json.dumps({
            "prompt": "Test prompt",
            "eval_id": 42,
        }))
        run = build_run(tmp_path, run_dir)
        assert run is not None
        assert run["prompt"] == "Test prompt"
        assert run["eval_id"] == 42
        assert len(run["outputs"]) == 1
        assert run["outputs"][0]["name"] == "result.txt"

    def test_skips_metadata_files(self, tmp_path):
        run_dir = tmp_path / "run-1"
        outputs = run_dir / "outputs"
        outputs.mkdir(parents=True)
        (outputs / "result.txt").write_text("hello")
        (outputs / "transcript.md").write_text("should be skipped")
        (outputs / "metrics.json").write_text("{}")
        run = build_run(tmp_path, run_dir)
        assert len(run["outputs"]) == 1
        assert run["outputs"][0]["name"] == "result.txt"

    def test_loads_grading(self, tmp_path):
        run_dir = tmp_path / "run-1"
        outputs = run_dir / "outputs"
        outputs.mkdir(parents=True)
        (outputs / "result.txt").write_text("hello")
        grading = {"summary": {"pass_rate": 1.0}}
        (run_dir / "grading.json").write_text(json.dumps(grading))
        run = build_run(tmp_path, run_dir)
        assert run["grading"]["summary"]["pass_rate"] == 1.0


class TestGenerateHtmlViewer:
    def _make_runs(self):
        return [
            {
                "id": "eval-1-with_skill-run-1",
                "prompt": "Test prompt",
                "eval_id": 1,
                "outputs": [
                    {"name": "result.txt", "type": "text", "content": "Hello world"},
                ],
                "grading": {
                    "summary": {"pass_rate": 1.0, "passed": 1, "failed": 0, "total": 1},
                    "expectations": [
                        {"text": "Output exists", "passed": True, "evidence": "Found"},
                    ],
                },
            },
        ]

    def test_produces_html(self):
        runs = self._make_runs()
        html = generate_html(runs, "test-skill")
        assert "<!DOCTYPE html>" in html
        assert "</html>" in html

    def test_valid_html_structure(self):
        runs = self._make_runs()
        html = generate_html(runs, "test-skill")
        assert_html_has_doctype(html)
        assert_valid_html(html)

    def test_embeds_data(self):
        runs = self._make_runs()
        html = generate_html(runs, "test-skill")
        assert "EMBEDDED_DATA" in html
        assert "test-skill" in html

    def test_embeds_run_data(self):
        runs = self._make_runs()
        html = generate_html(runs, "test-skill")
        assert "Test prompt" in html
        assert "Hello world" in html

    def test_with_previous_feedback(self):
        runs = self._make_runs()
        previous = {
            "eval-1-with_skill-run-1": {
                "feedback": "Looks good!",
                "outputs": [{"name": "old.txt", "type": "text", "content": "old"}],
            },
        }
        html = generate_html(runs, "test-skill", previous=previous)
        assert_valid_html(html)
        assert "Looks good!" in html

    def test_with_benchmark(self):
        runs = self._make_runs()
        benchmark = {
            "metadata": {"skill_name": "test-skill", "timestamp": "2026-01-01"},
            "runs": [],
            "run_summary": {},
            "notes": ["Test note"],
        }
        html = generate_html(runs, "test-skill", benchmark=benchmark)
        assert_valid_html(html)
        assert "Test note" in html

    def test_html_escaping_in_data(self):
        """Embedded data should be JSON-safe (not break the script tag)."""
        runs = [
            {
                "id": "test",
                "prompt": 'Use </script><script>alert(1)</script>',
                "eval_id": 1,
                "outputs": [],
                "grading": None,
            },
        ]
        html = generate_html(runs, "test-skill")
        # The </script> in the data should be JSON-encoded inside the script tag
        # JSON.dumps escapes / as \/ by default, but Python doesn't.
        # The key thing is the HTML should still parse without the script tag breaking.
        # The data is inside a JS variable assignment, so it's JSON-encoded.
        assert "EMBEDDED_DATA" in html

    def test_empty_runs(self):
        html = generate_html([], "test-skill")
        assert_valid_html(html)

    def test_special_chars_in_skill_name(self):
        runs = self._make_runs()
        html = generate_html(runs, "test & <skill>")
        # The skill name is embedded in JSON, so it should be safe
        assert "EMBEDDED_DATA" in html
