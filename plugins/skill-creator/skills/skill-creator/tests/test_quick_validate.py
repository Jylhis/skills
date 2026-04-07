"""Tests for scripts/quick_validate.py — validate_skill."""

import textwrap

import pytest

from scripts.quick_validate import validate_skill


class TestValidateSkill:
    def test_valid_skill(self, tmp_skill):
        valid, msg = validate_skill(tmp_skill)
        assert valid is True
        assert "valid" in msg.lower()

    def test_missing_skill_md(self, tmp_path):
        skill_dir = tmp_path / "empty"
        skill_dir.mkdir()
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "SKILL.md not found" in msg

    def test_no_frontmatter(self, tmp_path):
        skill_dir = tmp_path / "no-fm"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("Just text\n")
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "frontmatter" in msg.lower()

    def test_invalid_frontmatter_format(self, tmp_path):
        skill_dir = tmp_path / "bad-fm"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("---\n: invalid yaml\n---\n")
        valid, msg = validate_skill(skill_dir)
        # Should fail on either YAML parse or missing required fields
        assert valid is False

    def test_frontmatter_not_dict(self, tmp_path):
        skill_dir = tmp_path / "list-fm"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text("---\n- item1\n- item2\n---\n")
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "dictionary" in msg.lower()

    def test_missing_name(self, tmp_path):
        skill_dir = tmp_path / "no-name"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            description: Has description but no name
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "name" in msg.lower()

    def test_missing_description(self, tmp_path):
        skill_dir = tmp_path / "no-desc"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: no-desc
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "description" in msg.lower()

    def test_name_not_kebab_case(self, tmp_path):
        skill_dir = tmp_path / "BadName"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: BadName
            description: Valid description
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "kebab-case" in msg.lower()

    def test_name_starts_with_hyphen(self, tmp_path):
        skill_dir = tmp_path / "bad"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: -bad-name
            description: Valid description
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "hyphen" in msg.lower()

    def test_name_ends_with_hyphen(self, tmp_path):
        skill_dir = tmp_path / "bad"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: bad-name-
            description: Valid description
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "hyphen" in msg.lower()

    def test_name_consecutive_hyphens(self, tmp_path):
        skill_dir = tmp_path / "bad"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: bad--name
            description: Valid description
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "hyphen" in msg.lower()

    def test_name_too_long(self, tmp_path):
        skill_dir = tmp_path / "long"
        skill_dir.mkdir()
        long_name = "a" * 65
        (skill_dir / "SKILL.md").write_text(textwrap.dedent(f"""\
            ---
            name: {long_name}
            description: Valid description
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "64" in msg

    def test_description_angle_brackets(self, tmp_path):
        skill_dir = tmp_path / "brackets"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: brackets
            description: Use <script> tags
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "angle bracket" in msg.lower()

    def test_description_too_long(self, tmp_path):
        skill_dir = tmp_path / "longdesc"
        skill_dir.mkdir()
        long_desc = "a" * 1025
        (skill_dir / "SKILL.md").write_text(textwrap.dedent(f"""\
            ---
            name: longdesc
            description: {long_desc}
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "1024" in msg

    def test_unexpected_keys(self, tmp_path):
        skill_dir = tmp_path / "extra"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: extra
            description: Valid description
            author: someone
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "author" in msg.lower()

    def test_allowed_optional_fields(self, tmp_path):
        skill_dir = tmp_path / "full"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: full
            description: Valid description
            license: MIT
            compatibility: Works with Claude Code 1.0+
            allowed-tools: Read, Write
            metadata:
              version: 1.0
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is True

    def test_compatibility_too_long(self, tmp_path):
        skill_dir = tmp_path / "longcompat"
        skill_dir.mkdir()
        long_compat = "a" * 501
        (skill_dir / "SKILL.md").write_text(textwrap.dedent(f"""\
            ---
            name: longcompat
            description: Valid description
            compatibility: {long_compat}
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is False
        assert "500" in msg

    def test_name_not_string(self, tmp_path):
        skill_dir = tmp_path / "numname"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: 123
            description: Valid description
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        # 123 is parsed as int by YAML
        assert valid is False
        assert "string" in msg.lower()

    def test_name_with_digits(self, tmp_path):
        """Kebab-case names can contain digits."""
        skill_dir = tmp_path / "my-skill-2"
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(textwrap.dedent("""\
            ---
            name: my-skill-2
            description: Valid description
            ---
        """))
        valid, msg = validate_skill(skill_dir)
        assert valid is True
