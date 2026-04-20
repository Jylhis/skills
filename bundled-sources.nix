# Upstream skill / agent / command repos bundled as first-class content.
#
# This file is a function of the flake's input attrset so it can resolve
# each source to a concrete store path and support multiple sources per
# flake input (useful for plugin monorepos like trailofbits/skills).
#
# Each entry key is a stable identifier used internally; it does not
# have to match a flake input name. Each entry sets:
#   src      — resolved source path (typically `inputs.<name>`)
#   skills   = { subdir | paths | include | exclude | namespace | maxDepth };
#   agents   = { subdir | paths | include | exclude };
#   commands = { subdir | paths | include | exclude };
#
# `subdir` — single directory walked for auto-discovery of *.md files or
#            skill directories.
# `paths`  — attrset of `<name> = <relative-path>` for explicit selection
#            (use when content is scattered across the repo).
#
# Any sub-attr (skills/agents/commands) may be omitted if that source
# does not contribute that kind of content.
inputs:

let
  # Helper for trailofbits-style plugin monorepos where each plugin is
  # `plugins/<plugin>/{skills,agents,commands}/`. Produces one source
  # entry covering all three content kinds under a stable namespace.
  tobPlugin = name: {
    src = inputs.trailofbits-skills;
    skills.subdir = "plugins/${name}/skills";
    skills.namespace = "tob";
    agents.subdir = "plugins/${name}/agents";
    commands.subdir = "plugins/${name}/commands";
  };

  tobcPlugin = name: {
    src = inputs.trailofbits-skills-curated;
    skills.subdir = "plugins/${name}/skills";
    skills.namespace = "tobc";
    agents.subdir = "plugins/${name}/agents";
    commands.subdir = "plugins/${name}/commands";
  };
in
{
  # ── Anthropic / OpenAI / etc — single-namespace sources ────────────
  promptfoo = {
    src = inputs.promptfoo;
    skills = {
      namespace = "promptfoo";
      subdir = ".claude/skills";
    };
  };

  cc-skills-golang = {
    src = inputs.cc-skills-golang;
    skills = {
      namespace = "golang";
      subdir = "skills";
    };
  };

  obsidian-skills = {
    src = inputs.obsidian-skills;
    skills = {
      namespace = "obsidian";
      subdir = "skills";
    };
  };

  rust-skills = {
    src = inputs.rust-skills;
    skills = {
      namespace = "rust";
      subdir = "skills";
    };
    agents.subdir = "agents";
    commands.subdir = "commands";
  };

  # Selective import from anthropics/claude-plugins-official.
  # (skill-creator is intentionally omitted here — replaced by a locally
  # maintained merged version at skills/skill-creator.)
  claude-plugins-official = {
    src = inputs.claude-plugins-official;
    skills = {
      namespace = "anthropic";
      paths.claude-md-improver = "plugins/claude-md-management/skills/claude-md-improver";
    };
    agents.paths = {
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
    commands.paths = {
      revise-claude-md = "plugins/claude-md-management/commands/revise-claude-md.md";
      code-review = "plugins/code-review/commands/code-review.md";
      feature-dev = "plugins/feature-dev/commands/feature-dev.md";
      review-pr = "plugins/pr-review-toolkit/commands/review-pr.md";
    };
  };

  # ── hashicorp/agent-skills — selected Terraform skills ────────────
  hashicorp-agent-skills = {
    src = inputs.hashicorp-agent-skills;
    skills = {
      namespace = "terraform";
      paths = {
        terraform-test = "terraform/code-generation/skills/terraform-test";
        terraform-style-guide = "terraform/code-generation/skills/terraform-style-guide";
        refactor-module = "terraform/module-generation/skills/refactor-module";
        terraform-stacks = "terraform/module-generation/skills/terraform-stacks";
      };
    };
  };

  # ── openai/skills — curated picks (skill-creator merged locally) ──
  openai-skills = {
    src = inputs.openai-skills;
    skills = {
      namespace = "openai";
      paths = {
        aspnet-core = "skills/.curated/aspnet-core";
        frontend-skill = "skills/.curated/frontend-skill";
        gh-address-comments = "skills/.curated/gh-address-comments";
        gh-fix-ci = "skills/.curated/gh-fix-ci";
        security-best-practices = "skills/.curated/security-best-practices";
        security-ownership-map = "skills/.curated/security-ownership-map";
        security-threat-model = "skills/.curated/security-threat-model";
      };
    };
  };

  # ── microsoft/skills — cloud + docs skills (skill-creator merged locally) ──
  microsoft-skills = {
    src = inputs.microsoft-skills;
    skills = {
      namespace = "ms";
      paths = {
        cloud-solution-architect = ".github/skills/cloud-solution-architect";
        microsoft-docs = ".github/skills/microsoft-docs";
      };
    };
  };

  # All azure-skills from the azure-skills plugin.
  microsoft-azure-skills = {
    src = inputs.microsoft-skills;
    skills = {
      namespace = "azure";
      subdir = ".github/plugins/azure-skills/skills";
    };
  };

  # ── cloudflare/skills ─────────────────────────────────────────────
  cloudflare-skills = {
    src = inputs.cloudflare-skills;
    skills = {
      namespace = "cloudflare";
      paths = {
        cloudflare = "skills/cloudflare";
        durable-objects = "skills/durable-objects";
        workers-best-practices = "skills/workers-best-practices";
        wrangler = "skills/wrangler";
      };
    };
  };

  # ── trailofbits/skills — security plugin monorepo ─────────────────
  tob-agentic-actions-auditor = tobPlugin "agentic-actions-auditor";
  tob-audit-context-building = tobPlugin "audit-context-building";
  tob-differential-review = tobPlugin "differential-review";
  tob-dimensional-analysis = tobPlugin "dimensional-analysis";
  tob-insecure-defaults = tobPlugin "insecure-defaults";
  tob-semgrep-rule-creator = tobPlugin "semgrep-rule-creator";
  tob-semgrep-rule-variant-creator = tobPlugin "semgrep-rule-variant-creator";
  tob-sharp-edges = tobPlugin "sharp-edges";
  tob-static-analysis = tobPlugin "static-analysis";
  tob-supply-chain-risk-auditor = tobPlugin "supply-chain-risk-auditor";
  tob-testing-handbook-skills = tobPlugin "testing-handbook-skills";
  tob-trailmark = tobPlugin "trailmark";
  tob-variant-analysis = tobPlugin "variant-analysis";
  tob-yara-authoring = tobPlugin "yara-authoring";
  tob-constant-time-analysis = tobPlugin "constant-time-analysis";
  tob-mutation-testing = tobPlugin "mutation-testing";
  tob-zeroize-audit = tobPlugin "zeroize-audit";
  tob-dwarf-expert = tobPlugin "dwarf-expert";
  tob-gh-cli = tobPlugin "gh-cli";
  tob-modern-python = tobPlugin "modern-python";
  tob-skill-improver = tobPlugin "skill-improver";
  tob-workflow-skill-design = tobPlugin "workflow-skill-design";
  tob-culture-index = tobPlugin "culture-index";

  # ── trailofbits/skills-curated — prefer these over originals only
  # when the original upstream isn't available. Several entries here
  # mirror other upstreams; we keep only those that add net-new
  # content or lack a clear upstream we're already pulling.
  tobc-ffuf-web-fuzzing = tobcPlugin "ffuf-web-fuzzing";
  tobc-ghidra-headless = tobcPlugin "ghidra-headless";
  tobc-humanizer = tobcPlugin "humanizer";
  tobc-last30days = tobcPlugin "last30days";
  tobc-openai-cloudflare-deploy = tobcPlugin "openai-cloudflare-deploy";
  tobc-openai-develop-web-game = tobcPlugin "openai-develop-web-game";
  tobc-openai-pdf = tobcPlugin "openai-pdf";
  tobc-planning-with-files = tobcPlugin "planning-with-files";
  tobc-python-code-simplifier = tobcPlugin "python-code-simplifier";
  tobc-react-pdf = tobcPlugin "react-pdf";
  tobc-scv-scan = tobcPlugin "scv-scan";
  tobc-security-awareness = tobcPlugin "security-awareness";
  tobc-skill-extractor = tobcPlugin "skill-extractor";
  tobc-wooyun-legacy = tobcPlugin "wooyun-legacy";

  # ── addyosmani/agent-skills — general agent-skills collection ─────
  # `using-agent-skills` is intentionally omitted (replaced by a local
  # meta skill pointing at this repo's full skill catalog).
  addyosmani-agent-skills = {
    src = inputs.addyosmani-agent-skills;
    skills = {
      namespace = "addy";
      subdir = "skills";
      exclude = [ "using-agent-skills" ];
    };
  };

  # ── MiniMax-AI/skills — single shader-dev skill ───────────────────
  minimax-skills = {
    src = inputs.minimax-skills;
    skills = {
      namespace = "minimax";
      paths.shader-dev = "skills/shader-dev";
    };
  };

  # ── Leonxlnx/taste-skill — UI design taste skills ─────────────────
  taste-skill = {
    src = inputs.taste-skill;
    skills = {
      namespace = "taste";
      subdir = "skills";
    };
  };

  # ── Orchestra-Research/AI-Research-SKILLs — ML research skills ────
  ai-research-skills = {
    src = inputs.ai-research-skills;
    skills = {
      namespace = "ai-research";
      subdir = ".";
    };
  };
}
