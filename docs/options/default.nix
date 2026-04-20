# Options documentation derivation — renders the programs.jstack option
# tree into a GitHub Pages-ready static site using pkgs.nixosOptionsDoc +
# pandoc. Exposed via flake.nix as packages.${system}.options-doc.
{ pkgs, lib }:

let
  eval = lib.evalModules {
    modules = [
      ../../modules
      {
        _module.check = false;
        _module.args.jstackBundledSources = { };
        programs.jstack.enable = true;
      }
    ];
    specialArgs = { inherit pkgs; };
  };

  # Rewrite option declaration paths to GitHub source links.
  transformOptions =
    opt:
    opt
    // {
      declarations = map (
        decl:
        let
          s = toString decl;
          prefix = toString ../../.;
          rel = lib.removePrefix (prefix + "/") s;
        in
        {
          url = "https://github.com/jylhis/jstack/blob/main/${rel}";
          name = rel;
        }
      ) opt.declarations;
    };

  optionsDoc = pkgs.nixosOptionsDoc {
    options = removeAttrs eval.options [ "_module" ];
    inherit transformOptions;
    documentType = "none";
  };
in
pkgs.runCommand "jstack-options-doc"
  {
    nativeBuildInputs = [ pkgs.pandoc ];
    preamble = ./README.md;
    css = ./style.css;
    options = optionsDoc.optionsCommonMark;
  }
  ''
    mkdir -p $out
    cp "$css" $out/style.css

    cat "$preamble" "$options" > combined.md

    pandoc \
      --standalone \
      --toc --toc-depth=3 \
      --metadata title="jstack module options" \
      --from=commonmark \
      --to=html5 \
      --css=style.css \
      --output=$out/index.html \
      combined.md

    cp combined.md $out/options.md
  ''
