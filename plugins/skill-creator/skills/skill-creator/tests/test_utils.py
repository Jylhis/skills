"""Tests for scripts/utils.py — parse_skill_md."""

import textwrap

import pytest

from scripts.utils import parse_skill_md


class TestParseSkillMd:
    def test_basic(self, tmp_skill):
        name, desc, content = parse_skill_md(tmp_skill)
        assert name == "test-skill"
        assert desc == "A test skill for unit testing purposes"
        assert "# Test Skill" in content

    def test_multiline_folded(self, tmp_skill_multiline_desc):
        name, desc, content = parse_skill_md(tmp_skill_multiline_desc)
        assert name == "multi-skill"
        assert "long description" in desc
        assert "spans multiple lines" in desc

    def test_multiline_literal(self, tmp_path):
        skill_dir = tmp_path / "lit-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: lit-skill
            description: |
              Line one
              Line two
            ---

            Body
        """))
        name, desc, _ = parse_skill_md(skill_dir)
        assert name == "lit-skill"
        assert "Line one" in desc
        assert "Line two" in desc

    def test_multiline_folded_strip(self, tmp_path):
        skill_dir = tmp_path / "strip-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: strip-skill
            description: >-
              Stripped folded
              description here
            ---

            Body
        """))
        name, desc, _ = parse_skill_md(skill_dir)
        assert "Stripped folded" in desc

    def test_multiline_literal_strip(self, tmp_path):
        skill_dir = tmp_path / "ls-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: ls-skill
            description: |-
              Literal stripped
              value here
            ---

            Body
        """))
        name, desc, _ = parse_skill_md(skill_dir)
        assert "Literal stripped" in desc

    def test_quoted_values(self, tmp_path):
        skill_dir = tmp_path / "quoted-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: "quoted-skill"
            description: 'A quoted description'
            ---

            Body
        """))
        name, desc, _ = parse_skill_md(skill_dir)
        assert name == "quoted-skill"
        assert desc == "A quoted description"

    def test_missing_frontmatter_opening(self, tmp_path):
        skill_dir = tmp_path / "bad-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("No frontmatter here\n")
        with pytest.raises(ValueError, match="no opening ---"):
            parse_skill_md(skill_dir)

    def test_missing_frontmatter_closing(self, tmp_path):
        skill_dir = tmp_path / "bad-skill"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("---\nname: x\ndescription: y\n")
        with pytest.raises(ValueError, match="no closing ---"):
            parse_skill_md(skill_dir)

    def test_missing_file(self, tmp_path):
        skill_dir = tmp_path / "no-file"
        skill_dir.mkdir()
        with pytest.raises(FileNotFoundError):
            parse_skill_md(skill_dir)
