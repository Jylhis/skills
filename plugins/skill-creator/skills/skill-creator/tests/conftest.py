"""Shared fixtures for skill-creator tests."""

import sys
import textwrap
from pathlib import Path

import pytest

# Add scripts directory to path so imports work like `from scripts.utils import ...`
SKILL_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(SKILL_ROOT))


# ---------------------------------------------------------------------------
# HTML validation helpers
# ---------------------------------------------------------------------------

from html.parser import HTMLParser


class HTMLValidator(HTMLParser):
    """Validates that HTML is structurally well-formed.

    Tracks open/close tags and reports mismatches. Self-closing tags
    (br, img, meta, link, input, hr, col, area, base, source, wbr, embed,
    track, param) are exempt from close-tag checks.
    """

    VOID_ELEMENTS = frozenset({
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    })

    def __init__(self):
        super().__init__()
        self.errors: list[str] = []
        self.tag_stack: list[tuple[str, int, int]] = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() not in self.VOID_ELEMENTS:
            self.tag_stack.append((tag.lower(), *self.getpos()))

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in self.VOID_ELEMENTS:
            return
        if not self.tag_stack:
            self.errors.append(f"Unexpected closing tag </{tag}> at line {self.getpos()[0]}")
            return
        expected_tag, line, col = self.tag_stack[-1]
        if expected_tag != tag:
            self.errors.append(
                f"Mismatched tag: expected </{expected_tag}> (opened at line {line}), "
                f"got </{tag}> at line {self.getpos()[0]}"
            )
        else:
            self.tag_stack.pop()

    def validate(self):
        """Call after feeding all data. Returns list of errors."""
        for tag, line, col in self.tag_stack:
            self.errors.append(f"Unclosed tag <{tag}> opened at line {line}")
        return self.errors


def assert_valid_html(html_string: str):
    """Assert that an HTML string is structurally well-formed."""
    validator = HTMLValidator()
    validator.feed(html_string)
    errors = validator.validate()
    assert not errors, f"HTML validation errors:\n" + "\n".join(f"  - {e}" for e in errors)


def assert_html_has_doctype(html_string: str):
    """Assert that the HTML string starts with a DOCTYPE declaration."""
    stripped = html_string.lstrip()
    assert stripped.lower().startswith("<!doctype html>"), \
        f"Missing DOCTYPE. Starts with: {stripped[:50]!r}"


# ---------------------------------------------------------------------------
# Sample data fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def tmp_skill(tmp_path):
    """Create a minimal valid skill directory with SKILL.md."""
    skill_dir = tmp_path / "test-skill"
    skill_dir.mkdir()
    (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
        ---
        name: test-skill
        description: A test skill for unit testing purposes
        ---

        # Test Skill

        This is a test skill.
    """))
    return skill_dir


@pytest.fixture
def tmp_skill_multiline_desc(tmp_path):
    """Create a skill with multiline folded description (>)."""
    skill_dir = tmp_path / "multi-skill"
    skill_dir.mkdir()
    (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
        ---
        name: multi-skill
        description: >
          This is a long description
          that spans multiple lines
        ---

        # Multi Skill
    """))
    return skill_dir


@pytest.fixture
def sample_grading():
    """Sample grading.json data."""
    return {
        "summary": {
            "pass_rate": 0.75,
            "passed": 3,
            "failed": 1,
            "total": 4,
        },
        "expectations": [
            {"text": "Should create file", "passed": True, "evidence": "File exists"},
            {"text": "Should be valid JSON", "passed": True, "evidence": "Parsed OK"},
            {"text": "Should have key", "passed": True, "evidence": "Key found"},
            {"text": "Should be fast", "passed": False, "evidence": "Took 10s"},
        ],
        "timing": {"total_duration_seconds": 12.5},
        "execution_metrics": {
            "total_tool_calls": 5,
            "errors_encountered": 0,
            "output_chars": 1200,
        },
    }


@pytest.fixture
def sample_loop_output():
    """Sample output from run_loop.py."""
    return {
        "exit_reason": "all_passed (iteration 2)",
        "original_description": "Original description",
        "best_description": "Improved description",
        "best_score": "3/3",
        "best_train_score": "2/2",
        "best_test_score": "1/1",
        "final_description": "Improved description",
        "iterations_run": 2,
        "holdout": 0.4,
        "train_size": 2,
        "test_size": 1,
        "history": [
            {
                "iteration": 1,
                "description": "Original description",
                "train_passed": 1,
                "train_failed": 1,
                "train_total": 2,
                "train_results": [
                    {"query": "create a chart", "should_trigger": True, "pass": True, "triggers": 2, "runs": 3},
                    {"query": "what is 2+2", "should_trigger": False, "pass": False, "triggers": 2, "runs": 3},
                ],
                "test_passed": 0,
                "test_failed": 1,
                "test_total": 1,
                "test_results": [
                    {"query": "make a graph", "should_trigger": True, "pass": False, "triggers": 1, "runs": 3},
                ],
                "passed": 1,
                "failed": 1,
                "total": 2,
                "results": [
                    {"query": "create a chart", "should_trigger": True, "pass": True, "triggers": 2, "runs": 3},
                    {"query": "what is 2+2", "should_trigger": False, "pass": False, "triggers": 2, "runs": 3},
                ],
            },
            {
                "iteration": 2,
                "description": "Improved description",
                "train_passed": 2,
                "train_failed": 0,
                "train_total": 2,
                "train_results": [
                    {"query": "create a chart", "should_trigger": True, "pass": True, "triggers": 3, "runs": 3},
                    {"query": "what is 2+2", "should_trigger": False, "pass": True, "triggers": 0, "runs": 3},
                ],
                "test_passed": 1,
                "test_failed": 0,
                "test_total": 1,
                "test_results": [
                    {"query": "make a graph", "should_trigger": True, "pass": True, "triggers": 3, "runs": 3},
                ],
                "passed": 2,
                "failed": 0,
                "total": 2,
                "results": [
                    {"query": "create a chart", "should_trigger": True, "pass": True, "triggers": 3, "runs": 3},
                    {"query": "what is 2+2", "should_trigger": False, "pass": True, "triggers": 0, "runs": 3},
                ],
            },
        ],
    }


@pytest.fixture
def sample_eval_set():
    """Sample eval set for split tests."""
    return [
        {"query": "create a chart", "should_trigger": True},
        {"query": "make a graph", "should_trigger": True},
        {"query": "plot data", "should_trigger": True},
        {"query": "visualize results", "should_trigger": True},
        {"query": "what is 2+2", "should_trigger": False},
        {"query": "hello world", "should_trigger": False},
        {"query": "tell me a joke", "should_trigger": False},
        {"query": "what time is it", "should_trigger": False},
    ]


@pytest.fixture
def benchmark_workspace(tmp_path, sample_grading):
    """Create a workspace directory layout with grading.json files."""
    # eval-1/with_skill/run-1/grading.json
    for eval_num in [1, 2]:
        for config in ["with_skill", "without_skill"]:
            for run_num in [1, 2]:
                run_dir = tmp_path / f"eval-{eval_num}" / config / f"run-{run_num}"
                run_dir.mkdir(parents=True)
                grading = sample_grading.copy()
                # Vary pass rates slightly
                if config == "without_skill":
                    grading = {
                        **grading,
                        "summary": {**grading["summary"], "pass_rate": 0.5, "passed": 2, "failed": 2},
                    }
                import json
                (run_dir / "grading.json").write_text(json.dumps(grading))
    return tmp_path
