# Flake inputs for non-flake consumers (via flake-compat).
#
# Evaluates flake.nix with edolstra/flake-compat and re-exports the
# input attrset. Each attr coerces to its source path (.outPath) when
# imported, so `import sources.nixpkgs {}` keeps working unchanged.
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  fc = lock.nodes.flake-compat.locked;
  flake-compat = builtins.fetchTarball {
    url = "https://github.com/${fc.owner}/${fc.repo}/archive/${fc.rev}.tar.gz";
    sha256 = fc.narHash;
  };
  inputs = (import flake-compat { src = ./.; }).defaultNix.inputs;
in
{
  inherit (inputs)
    nixpkgs
    promptfoo
    cc-skills-golang
    obsidian-skills
    rust-skills
    claude-plugins-official
    ;
}
