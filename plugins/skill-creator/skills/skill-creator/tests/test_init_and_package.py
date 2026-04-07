"""Tests for scripts/init_skill.py and scripts/package_skill.py."""

from pathlib import Path

import pytest

from scripts.init_skill import title_case, init_skill
from scripts.package_skill import should_exclude


class TestTitleCase:
    def test_simple(self):
        assert title_case("my-skill") == "My Skill"

    def test_single_word(self):
        assert title_case("skill") == "Skill"

    def test_multiple_hyphens(self):
        assert title_case("my-cool-skill") == "My Cool Skill"

    def test_with_digits(self):
        assert title_case("skill-2") == "Skill 2"


class TestInitSkill:
    def test_creates_structure(self, tmp_path):
        result = init_skill("my-skill", str(tmp_path))
        assert result is not None
        skill_dir = tmp_path / "my-skill"
        assert skill_dir.exists()
        assert (skill_dir / "SKILL.md").exists()
        assert (skill_dir / "scripts").is_dir()
        assert (skill_dir / "references").is_dir()
        assert (skill_dir / "assets").is_dir()

    def test_skill_md_content(self, tmp_path):
        init_skill("data-analyzer", str(tmp_path))
        content = (tmp_path / "data-analyzer" / "SKILL.md").read_text()
        assert "name: data-analyzer" in content
        assert "Data Analyzer" in content

    def test_example_script_exists(self, tmp_path):
        init_skill("my-skill", str(tmp_path))
        script = tmp_path / "my-skill" / "scripts" / "example.py"
        assert script.exists()
        assert "my-skill" in script.read_text()

    def test_rejects_existing_directory(self, tmp_path):
        (tmp_path / "my-skill").mkdir()
        result = init_skill("my-skill", str(tmp_path))
        assert result is None

    def test_rejects_uppercase(self, tmp_path):
        result = init_skill("MySkill", str(tmp_path))
        assert result is None

    def test_rejects_spaces(self, tmp_path):
        result = init_skill("my skill", str(tmp_path))
        assert result is None

    def test_rejects_too_long(self, tmp_path):
        result = init_skill("a" * 65, str(tmp_path))
        assert result is None

    def test_accepts_valid_names(self, tmp_path):
        for name in ["a", "my-skill", "skill-2", "a-b-c"]:
            sub = tmp_path / name
            # init_skill creates subdirectory, so we just need unique tmp_paths
            result = init_skill(name, str(tmp_path))
            assert result is not None, f"Should accept '{name}'"

    def test_rejects_leading_hyphen(self, tmp_path):
        result = init_skill("-bad", str(tmp_path))
        assert result is None

    def test_rejects_trailing_hyphen(self, tmp_path):
        result = init_skill("bad-", str(tmp_path))
        assert result is None

    def test_rejects_consecutive_hyphens(self, tmp_path):
        result = init_skill("bad--name", str(tmp_path))
        assert result is None


class TestShouldExclude:
    def test_pycache(self):
        assert should_exclude(Path("skill/__pycache__/module.pyc")) is True

    def test_node_modules(self):
        assert should_exclude(Path("skill/node_modules/pkg/index.js")) is True

    def test_pyc_file(self):
        assert should_exclude(Path("skill/scripts/module.pyc")) is True

    def test_ds_store(self):
        assert should_exclude(Path("skill/.DS_Store")) is True

    def test_root_evals(self):
        # evals/ at skill root (parts[1]) should be excluded
        assert should_exclude(Path("skill/evals/test.json")) is True

    def test_nested_evals_allowed(self):
        # evals/ nested deeper should NOT be excluded
        assert should_exclude(Path("skill/scripts/evals/test.json")) is False

    def test_normal_file_allowed(self):
        assert should_exclude(Path("skill/SKILL.md")) is False
        assert should_exclude(Path("skill/scripts/utils.py")) is False
        assert should_exclude(Path("skill/references/doc.md")) is False
