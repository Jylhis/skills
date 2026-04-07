let
  sources = import ./npins;
in
{
  homeManagerModules.default = ./modules/home-manager.nix;
  inherit sources;
}
