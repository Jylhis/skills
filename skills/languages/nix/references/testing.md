# Nix Testing

## Overview

NixOS provides a VM-based integration testing framework. Tests run in isolated QEMU virtual machines with full NixOS systems. Tests are reproducible, hermetic, and can orchestrate multiple VMs.

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
pkgs.nixosTest {
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
pkgs.nixosTest {
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

Machines can address each other by node name. Network is set up automatically.

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
| `copy_from_vm(src, dst)` | Copy file from VM to host |
| `copy_to_vm(src, dst)` | Copy file from host to VM |
| `shell_interact()` | Drop into interactive shell (for debugging) |
| `shutdown()` | Gracefully shut down the VM |
| `crash()` | Simulate power loss |
| `reboot()` | Reboot the VM |

## Integration with Flake Checks

```nix
# flake.nix
{
  outputs = { self, nixpkgs, ... }: {
    checks.x86_64-linux.mytest = nixpkgs.legacyPackages.x86_64-linux.nixosTest {
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

This drops you into a Python REPL with machine objects. You can run commands, inspect state, take screenshots.

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
| nix-unit | yes | no | no (use lix-unit) |
| namaka | no | yes | yes |
| runTests | no | no | yes |
| nixt | no | no | yes |

Choose nix-unit when you need to catch evaluation errors as test failures (not just wrong values). Choose namaka for snapshot-based testing of evaluation output. Choose nixt for simple struct-based tests with watch mode.

### Usage

```nix
# tests/default.nix
{ ... }:
{
  my-test = {
    "adds two numbers" = {
      expected = 3;
      actual = 1 + 2;
    };
  };
}
```

Run with the `nix-unit` CLI or as a flake check.

```bash
nix run github:nix-community/nix-unit -- --help
nix-unit --test nixpkgs#lib.tests.my-test
```

### Lix fork

If you use Lix instead of Nix, use [lix-unit](https://github.com/adisbladis/lix-unit) — nix-unit does not support Lix.

## nixt (Simple Unit Testing)

A simple unit-testing tool for Nix using a suite/case structure. Supports watch mode for iterative development.

### Usage

```bash
nixt ./tests/                    # run tests
nixt ./tests/ -v                 # verbose (show passing cases)
nixt ./tests/ -w                 # watch mode (re-run on file change)
nixt ./tests/ -l                 # list tests without running
```

Test files use a nested attrset structure:

```nix
# tests/utils.test.nix
{
  "string utils" = {
    "concat" = {
      expected = "hello world";
      actual = "hello" + " world";
    };
  };
}
```

## CI Considerations

- NixOS VM tests require KVM support. GitHub Actions runners support this with `runs-on: ubuntu-latest` (nested virtualization is enabled).
- For cross-architecture testing (e.g., aarch64 tests on x86_64), use binfmt emulation.
- Tests can be slow — consider running only affected tests in PRs.
- Set `virtualisation.memorySize` and `virtualisation.cores` in test nodes to control resource usage.

## Related Skills

- nixos-modules — writing modules that tests validate
- nix-linting — CI pipeline integration
