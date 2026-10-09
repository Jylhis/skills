# Nix Testing

## Overview

NixOS provides a VM-based integration testing framework. Tests run in isolated QEMU virtual machines with full NixOS systems (since 26.05 also in lighter `systemd-nspawn` containers via `containers.<name>`). Tests are reproducible, hermetic, and can orchestrate multiple machines.

Outside nixpkgs, build tests with `pkgs.testers.runNixOSTest`. The top-level `pkgs.nixosTest` alias throws since 25.11; see `nixos-modules/testing.md` for the full test-module options.

## Where Tests Live (RFC 119)

Nixpkgs conventions split package tests by speed:

| Mechanism | When it runs | Use for |
|-----------|-------------|---------|
| `doCheck = true` + `checkPhase` in a derivation | During the package build | Fast in-tree unit tests |
| `passthru.tests = { ... }` on a package | Separate derivations, discovered by `nixpkgs-review` + Hydra | Slow / integration / VM / cross-package tests |
| `nixos/tests/<name>.nix` + `nixosTests.<name>` | Separate VM invocation | Full-system integration tests |

The NixOS VM test framework documented below produces the VM tests you reference from `passthru.tests` via `nixosTests.<name>`. See the nixpkgs skill for the `passthru.tests` attrset shape.

## Basic Test Structure

```nix
# checks/my-test.nix
{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "my-service-test";
  
  nodes.machine = { pkgs, ... }: {
    services.myservice.enable = true;
    services.myservice.port = 8080;
  };
  
  testScript = ''
    machine.start()
    machine.wait_for_unit("myservice.service")
    machine.wait_for_open_port(8080)
    result = machine.succeed("curl -f http://localhost:8080/health")
    assert "ok" in result, f"Health check failed: {result}"
  '';
}
```

## Multi-VM Tests

```nix
pkgs.testers.runNixOSTest {
  name = "client-server-test";
  
  nodes.server = { pkgs, ... }: {
    services.myservice.enable = true;
    networking.firewall.allowedTCPPorts = [ 8080 ];
  };
  
  nodes.client = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.curl ];
  };
  
  testScript = ''
    server.start()
    server.wait_for_unit("myservice.service")
    server.wait_for_open_port(8080)
    
    client.start()
    client.wait_for_unit("multi-user.target")
    client.succeed("curl -f http://server:8080/health")
  '';
}
```

Machines can address each other by node name. Network is set up automatically. Machines also start implicitly on their first command, and `start_all()` boots them all in parallel.

## Python Test Driver API

Test scripts are Python. Available methods on each machine:

| Method | Purpose |
|--------|---------|
| `start()` | Boot the VM |
| `wait_for_unit(unit)` | Wait for systemd unit to be active |
| `wait_for_open_port(port)` | Wait for TCP port to accept connections |
| `succeed(cmd)` | Run command, assert exit code 0, return stdout |
| `fail(cmd)` | Run command, assert exit code non-zero |
| `execute(cmd)` | Run command, return (status, stdout) tuple |
| `wait_until_succeeds(cmd)` | Retry command until it succeeds (with timeout) |
| `wait_until_fails(cmd)` | Retry command until it fails |
| `screenshot(name)` | Save VM screenshot (useful for debugging) |
| `copy_from_machine(src, target_dir)` | Copy file from the machine into `$out/<target_dir>` (`copy_from_vm` is a deprecated alias) |
| `copy_from_host(src, dst)` | Copy file from the host (build sandbox) into the machine |
| `shell_interact()` | Drop into interactive shell (for debugging) |
| `shutdown()` | Gracefully shut down the VM |
| `crash()` | Simulate power loss |
| `reboot()` | Reboot the VM |

## Integration with Flake Checks

```nix
# flake.nix
{
  outputs = { self, nixpkgs, ... }: {
    checks.x86_64-linux.mytest = nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest {
      name = "mytest";
      nodes.machine = { ... }: { imports = [ self.nixosModules.default ]; };
      testScript = ''machine.wait_for_unit("myservice.service")'';
    };
  };
}
```

Run: `nix flake check` or `nix build .#checks.x86_64-linux.mytest`

## Interactive Test Driver

Debug failing tests interactively:

```bash
nix build .#checks.x86_64-linux.mytest.driverInteractive
./result/bin/nixos-test-driver
```

This drops you into a Python REPL with machine objects. You can run commands, inspect state, take screenshots; `test_script()` runs the whole script. Add `interactive.sshBackdoor.enable = true;` to the test to get SSH access to each VM over vsock.

## namaka (Snapshot Testing)

For testing Nix expressions (not VMs):

```nix
namaka.lib.load {
  src = ./tests;
  inputs = { inherit (inputs) nixpkgs; };
};
```

Captures evaluation results as snapshots. On subsequent runs, compares against snapshots. `namaka review` to accept changes.

### Test File Structure

```
tests/
├── foo/
│   └── expr.nix        # expression to test
└── bar/
    ├── expr.nix
    └── format.nix      # optional: "json" (default), "pretty", or "string"
```

`namaka check` wraps `nix flake check` to prepare snapshots for failed tests. `namaka clean` removes unused snapshots.

## nix-unit (Unit Testing)

A unit-testing framework that runs attribute sets of tests compatible with `lib.debug.runTests`, while allowing individual attributes to fail independently (unlike `runTests` which aborts on first error). Uses the Nix evaluator C++ API for fast, fine-grained test reporting.

### When to choose nix-unit over namaka

| Tool | Can test eval failures | Snapshot testing | Lix support |
|------|----------------------|-------------------|-------------|
| nix-unit | yes | no | no |
| namaka | no | yes | yes |
| runTests | no | no | yes |
| nixt | no | no | yes |

Choose nix-unit when you need to catch evaluation errors as test failures (not just wrong values). Choose namaka for snapshot-based testing of evaluation output. nixt is largely dormant (no code changes on master since 2023), so prefer nix-unit or `lib.debug.runTests` for new suites.

### Usage

Test names must start with `test`; each test has `expr` and `expected`:

```nix
# tests/default.nix
{
  testAddsTwoNumbers = {
    expr = 1 + 2;
    expected = 3;
  };
  testThrows = {
    expr = throw "boom"; # reported as an eval failure, other tests still run
    expected = 0;
  };
}
```

Run with the `nix-unit` CLI or as a flake check.

```bash
nix run github:nix-community/nix-unit -- tests/default.nix
nix-unit --flake '.#libTests'   # tests exposed as a flake output attrset
```

As a flake check, run `nix-unit --eval-store "$HOME" --override-input nixpkgs ${nixpkgs} --flake ${self}#tests` inside a `runCommand` (inputs must already be in the store). The flake-parts module (`nix flake init -t github:nix-community/nix-unit#flake-parts`) sets this up from `flake.tests` / `perSystem.nix-unit.tests`. Release tags track Nix versions (latest v2.35.1, July 2026).

### Lix fork

nix-unit does not support Lix. Its Lix fork, [lix-unit](https://github.com/adisbladis/lix-unit), is now archived (last push September 2025), so on Lix fall back to `lib.debug.runTests` or namaka.

## nixt (Simple Unit Testing)

A simple unit-testing tool for Nix using a suite/case structure. Supports watch mode for iterative development. Still unarchived under nix-community, but master has had no code changes since 2023 (only a README fix in 2024).

### Usage

```bash
nixt ./tests/                    # run tests
nixt ./tests/ -v                 # verbose (show passing cases)
nixt ./tests/ -w                 # watch mode (re-run on file change)
nixt ./tests/ -l                 # list tests without running
```

Test files are functions taking `nixt` (and optionally `pkgs`) that return a block of suites; each case is a boolean expression (or list of them):

```nix
# tests/utils.test.nix
{ nixt, pkgs ? import <nixpkgs> { } }:
nixt.block' ./utils.test.nix {
  "string utils" = {
    "concat" = ("hello" + " world") == "hello world";
  };
}
```

## CI Considerations

- NixOS VM tests require KVM support. GitHub Actions runners support this with `runs-on: ubuntu-latest` (nested virtualization is enabled; `cachix/install-nix-action@v31` turns on KVM by default). Tests that use `containers` instead of `nodes` need no KVM but do need `auto-allocate-uids`, the `uid-range` system feature and the `cgroups` experimental feature on the builder.
- For cross-architecture testing (e.g., aarch64 tests on x86_64), use binfmt emulation.
- Tests can be slow — consider running only affected tests in PRs.
- Set `virtualisation.memorySize` and `virtualisation.cores` in test nodes to control resource usage.

## Related Skills

- nixos-modules — writing modules that tests validate
- nix-linting — CI pipeline integration
