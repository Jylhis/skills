{
  pkgs,
  catalogue,
  repoRoot,
}:
let
  catalogueJson = pkgs.writeText "ai-tooling-catalogue.json" (builtins.toJSON catalogue);
in
{
  # Exposed so `checks.<sys>.catalogue` can prove the catalogue evaluates
  # *and* serialises (the latter would fail on stray derivations or thunks).
  skills-catalogue-json = catalogueJson;

  skills-list = pkgs.writeShellApplication {
    name = "skills-list";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      kind=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --kind)
            [ $# -ge 2 ] || { echo "--kind requires a value" >&2; exit 2; }
            kind="$2"; shift 2 ;;
          -h|--help)
            cat <<EOF
      Usage: skills-list [--kind KIND]

      Dump the jylhis-skills catalogue as JSON.

        KIND ∈ { skills, agents, commands, mcpServers, lspServers, plugins }
      EOF
            exit 0 ;;
          *) echo "unknown argument: $1" >&2; exit 2 ;;
        esac
      done

      if [ -z "$kind" ]; then
        jq '.' ${catalogueJson}
      else
        jq --arg k "$kind" 'if has($k) then .[$k] else error("no such kind: " + $k) end' ${catalogueJson}
      fi
    '';
  };

  skills-show = pkgs.writeShellApplication {
    name = "skills-show";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      kind=""
      name=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --kind)
            [ $# -ge 2 ] || { echo "--kind requires a value" >&2; exit 2; }
            kind="$2"; shift 2 ;;
          -h|--help)
            cat <<EOF
      Usage: skills-show [--kind KIND] <artefact-name>

      Print one artefact as JSON.

        KIND ∈ { skills, agents, commands, mcpServers, lspServers, plugins }

      Without --kind, every kind is searched. If the same name lives in more
      than one kind (e.g. "python" is both a skill and an lspServer), the
      result is an object keyed by kind.
      EOF
            exit 0 ;;
          *)
            [ -z "$name" ] || { echo "unexpected argument: $1" >&2; exit 2; }
            name="$1"; shift ;;
        esac
      done
      [ -n "$name" ] || { echo "missing artefact name" >&2; exit 2; }

      if [ -n "$kind" ]; then
        result=$(jq --arg k "$kind" --arg n "$name" '
          if has($k) | not then error("no such kind: " + $k)
          elif .[$k] | has($n) then .[$k][$n]
          else null end
        ' ${catalogueJson})
      else
        result=$(jq --arg n "$name" '
          [.skills, .agents, .commands, .mcpServers, .lspServers, .plugins]
          as $kinds
          | ["skills","agents","commands","mcpServers","lspServers","plugins"]
          as $names
          | [range(0; $kinds | length) | select($kinds[.] | has($n))
             | {key: $names[.], value: $kinds[.][$n]}]
          | if length == 0 then null
            elif length == 1 then .[0].value
            else from_entries end
        ' ${catalogueJson})
      fi

      if [ "$result" = "null" ]; then
        if [ -n "$kind" ]; then
          echo "no artefact named: $name (in kind $kind)" >&2
        else
          echo "no artefact named: $name" >&2
        fi
        exit 1
      fi
      echo "$result"
    '';
  };

  skills-install = pkgs.writeShellApplication {
    name = "skills-install";
    runtimeInputs = [ pkgs.bash ];
    text = ''
      # Prefer an explicitly set checkout; otherwise the working directory if
      # it looks like a jylhis-skills checkout; otherwise the flake's source
      # path in the Nix store (read-only, but install.sh only reads from it).
      root="''${JYLHIS_SKILLS_ROOT:-}"
      if [ -z "$root" ]; then
        if [ -f "./scripts/install.sh" ] && [ -f "./.claude-plugin/marketplace.json" ]; then
          root="$(pwd)"
        else
          root="${toString repoRoot}"
        fi
      fi
      if [ ! -f "$root/scripts/install.sh" ]; then
        echo "cannot locate scripts/install.sh under '$root'" >&2
        echo "set JYLHIS_SKILLS_ROOT to a jylhis-skills checkout" >&2
        exit 2
      fi
      exec bash "$root/scripts/install.sh" "$@"
    '';
  };
}
