# Resolve flake inputs for non-flake consumers.
# Reads flake.lock to provide the same source paths the flake uses.
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);

  fetchNode =
    name:
    let
      ref = lock.nodes.root.inputs.${name};
      nodeName = if builtins.isString ref then ref else builtins.head ref;
      node = lock.nodes.${nodeName};
      locked = node.locked;
    in
    if locked.type == "github" then
      builtins.fetchTarball {
        url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
        sha256 = locked.narHash;
      }
    else
      throw "_sources.nix: unsupported locked type '${locked.type}'";
in
{
  nixpkgs = fetchNode "nixpkgs";
  promptfoo = fetchNode "promptfoo";
}
