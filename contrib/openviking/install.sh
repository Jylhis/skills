#!/usr/bin/env bash
# Install the OpenViking `ov` CLI into your Nix profile from this flake.
#
# Nix-native replacement for the (now deprecated) openviking.ai install
# script. Requires Nix with flakes; see README.md for details.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec nix --extra-experimental-features 'nix-command flakes' \
  profile install "${here}#openviking"
