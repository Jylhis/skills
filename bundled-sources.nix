# Upstream skill / agent / command repos bundled as first-class jstack
# content. Each key MUST match a `flake = false` input in flake.nix.
#
# Schema per source:
#   skills   = { subdir | paths | include | exclude | namespace | maxDepth };
#   agents   = { subdir | paths | include | exclude };
#   commands = { subdir | paths | include | exclude };
#
# `subdir`   — single directory walked for auto-discovery
# `paths`    — attrset of `<name> = <relative-path>` for explicit selection
#              (use this when content is scattered across plugin dirs)
# `include` / `exclude` operate on the discovered names.
#
# Bundled content is injected via modules/bundled.nix; downstream
# consumers can append more via programs.jstack.{skillSources,
# agentSources, commandSources, skills, agents, commands}.
{
  promptfoo = {
    skills = {
      namespace = "promptfoo";
      subdir = ".claude/skills";
    };
  };

  cc-skills-golang = {
    skills = {
      namespace = "golang";
      subdir = "skills";
    };
  };

  obsidian-skills = {
    skills = {
      namespace = "obsidian";
      subdir = "skills";
    };
  };

  rust-skills = {
    skills = {
      namespace = "rust";
      subdir = "skills";
    };
    agents = {
      subdir = "agents";
    };
    commands = {
      subdir = "commands";
    };
  };

  # Selective import from anthropics/claude-plugins-official. The repo
  # is a monorepo of plugins with mixed content types; we cherry-pick
  # individual skills/agents/commands via explicit `paths` maps so
  # jstack-shipped entries get stable names independent of upstream
  # directory layout.
  claude-plugins-official = {
    skills = {
      namespace = "anthropic";
      paths = {
        claude-md-improver = "plugins/claude-md-management/skills/claude-md-improver";
        skill-creator = "plugins/skill-creator/skills/skill-creator";
      };
    };
    agents = {
      paths = {
        code-architect = "plugins/feature-dev/agents/code-architect.md";
        code-explorer = "plugins/feature-dev/agents/code-explorer.md";
        code-reviewer = "plugins/feature-dev/agents/code-reviewer.md";
        code-simplifier = "plugins/code-simplifier/agents/code-simplifier.md";
        pr-code-reviewer = "plugins/pr-review-toolkit/agents/code-reviewer.md";
        pr-code-simplifier = "plugins/pr-review-toolkit/agents/code-simplifier.md";
        pr-comment-analyzer = "plugins/pr-review-toolkit/agents/comment-analyzer.md";
        pr-test-analyzer = "plugins/pr-review-toolkit/agents/pr-test-analyzer.md";
        pr-silent-failure-hunter = "plugins/pr-review-toolkit/agents/silent-failure-hunter.md";
        pr-type-design-analyzer = "plugins/pr-review-toolkit/agents/type-design-analyzer.md";
      };
    };
    commands = {
      paths = {
        revise-claude-md = "plugins/claude-md-management/commands/revise-claude-md.md";
        code-review = "plugins/code-review/commands/code-review.md";
        feature-dev = "plugins/feature-dev/commands/feature-dev.md";
        review-pr = "plugins/pr-review-toolkit/commands/review-pr.md";
      };
    };
  };
}
