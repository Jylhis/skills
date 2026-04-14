# Third-party skill source configuration.
#
# Each key must match a flake input name in flake.nix (with flake = false).
# Add sources by adding a non-flake input to flake.nix and running nix flake lock.
#
# Example:
#   1. Add to flake.nix inputs:
#      anthropic-skills = { url = "github:anthropics/skills"; flake = false; };
#   2. Run: nix flake lock
#   3. Add entry below:
#      anthropic-skills = {
#        namespace = "anthropic";
#        skillsRoot = "skills";
#        maxDepth = 4;
#      };
#   4. Skills are auto-discovered and available for selection.
{
  promptfoo = {
    namespace = "promptfoo";
    skillsRoot = ".claude/skills";
  };
}
