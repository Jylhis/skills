# nixpkgs-style derivation for the OpenViking `ov` CLI.
#
# This file is written to nixpkgs conventions so it can be dropped into
# nixpkgs at pkgs/by-name/op/openviking/package.nix unchanged. The sibling
# flake.nix wires it up for local installation via `callPackage`.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "openviking";
  version = "0.3.24";

  src = fetchFromGitHub {
    owner = "volcengine";
    repo = "OpenViking";
    tag = "cli@${finalAttrs.version}";
    hash = "sha256-rD5LosriJGU0bIBRx46kmOGM4MJBvx0o0swB8gcBxw4=";
  };

  cargoHash = "sha256-l1dwyNO+DiKdeo1Oe+vf6iuJZ1OqBMfmqzT6QM/2OSU=";

  # The repo is a Cargo workspace (crates/ov_cli, crates/ragfs,
  # crates/ragfs-python). Build and test only the CLI crate so we never
  # touch the pyo3 `ragfs-python` member.
  buildAndTestSubdir = "crates/ov_cli";

  # crates/ov_cli/build.rs reads OPENVIKING_VERSION to stamp `ov --version`;
  # without it the binary reports the placeholder 0.0.0.
  env.OPENVIKING_VERSION = finalAttrs.version;

  # reqwest is built with rustls-tls (aws-lc-rs backend), which needs cmake
  # at build time. No OpenSSL.
  nativeBuildInputs = [ cmake ];

  # The crate's tests expect a running OpenViking server / network access.
  doCheck = false;

  meta = {
    description = "Command-line client for OpenViking, a context filesystem for AI agents";
    homepage = "https://openviking.ai";
    changelog = "https://github.com/volcengine/OpenViking/releases/tag/cli@${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "ov";
    maintainers = [ ];
    platforms = lib.platforms.unix;
  };
})
