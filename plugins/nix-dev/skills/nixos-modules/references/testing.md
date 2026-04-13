# NixOS Testing Reference

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Basic Test Example](#basic-test-example)
- [Multi-VM Test Example](#multi-vm-test-example)
- [Python Test Driver API](#python-test-driver-api)
- [Interactive Test Driver](#interactive-test-driver)
- [Running Tests](#running-tests)
- [Integration with Flake Checks](#integration-with-flake-checks)
- [CI Considerations](#ci-considerations)

## Overview

NixOS VM tests run services inside QEMU virtual machines controlled by a Python test driver. Tests are fully reproducible -- the VM images are built from NixOS module configurations, and the test script exercises them deterministically. No network access or elevated privileges are needed at test time (beyond KVM for hardware acceleration).

Key properties:

- Each test spins up one or more QEMU VMs defined as NixOS configurations.
- The Python test driver boots VMs, waits for services, runs assertions.
- Tests produce a `result/` directory with logs and optional screenshots.
- The entire test (VM images + execution) is a single Nix derivation.

## Test Structure

A NixOS test is created with `nixosTest` (from `nixpkgs/nixos/lib/testing-python.nix`) and has three main parts:

| Field | Description |
|-------|-------------|
| `name` | Test identifier (used in derivation name and logs) |
| `nodes` | Attribute set of machine names to NixOS configurations |
| `testScript` | Python script that drives the VMs |

Optional fields: `skipLint` (skip Python linting of testScript), `enableOCR` (enable OCR for screenshot assertions), `globalTimeout` (seconds before the test is killed).

## Basic Test Example

```nix
{ pkgs, ... }:
pkgs.nixosTest {
  name = "my-service-test";

  nodes.machine = { pkgs, ... }: {
    services.myservice.enable = true;
    # Any NixOS configuration you need:
    networking.firewall.allowedTCPPorts = [ 8080 ];
  };

  testScript = ''
    machine.wait_for_unit("myservice.service")
    machine.wait_for_open_port(8080)
    result = machine.succeed("curl -f http://localhost:8080")
    assert "Welcome" in result, f"Unexpected response: {result}"
  '';
}
```

When a single node is named `machine`, the test driver creates a variable called `machine` in the Python scope automatically.

## Multi-VM Test Example

Multiple nodes communicate over a virtual network. Each node gets a hostname matching its attribute name.

```nix
{ pkgs, ... }:
pkgs.nixosTest {
  name = "client-server-test";

  nodes.server = { pkgs, ... }: {
    services.myservice = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = 8080;
    };
    networking.firewall.allowedTCPPorts = [ 8080 ];
  };

  nodes.client = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.curl ];
  };

  testScript = ''
    server.start()
    client.start()

    server.wait_for_unit("myservice.service")
    server.wait_for_open_port(8080)

    # Client connects to server by hostname
    client.wait_for_unit("network-online.target")
    client.succeed("curl -f http://server:8080")
  '';
}
```

Nodes are not started automatically in multi-VM tests -- call `.start()` explicitly. The virtual network resolves hostnames between VMs.

## Python Test Driver API

All methods are called on machine objects (e.g., `machine.method(...)`).

### Lifecycle

| Method | Description |
|--------|-------------|
| `start()` | Boot the VM |
| `shutdown()` | Graceful shutdown |
| `crash()` | Kill the VM immediately (simulate power loss) |
| `reboot()` | Reboot (shutdown + start) |

### Waiting

| Method | Description |
|--------|-------------|
| `wait_for_unit(unit)` | Block until a systemd unit reaches `active` state |
| `wait_for_open_port(port)` | Block until a TCP port accepts connections |
| `wait_for_closed_port(port)` | Block until a TCP port stops accepting connections |
| `wait_until_succeeds(cmd)` | Retry a shell command until it exits 0 (with timeout) |
| `wait_for_file(path)` | Block until a file exists |
| `wait_for_text(regex)` | Wait until OCR output from screen matches regex (needs `enableOCR`) |

### Commands

| Method | Description |
|--------|-------------|
| `succeed(cmd)` | Run a shell command; fail the test if exit code is non-zero. Returns stdout. |
| `fail(cmd)` | Run a shell command; fail the test if exit code **is** zero. |
| `execute(cmd)` | Run a command and return `(status, stdout)` tuple without failing. |
| `wait_until_succeeds(cmd)` | Retry until success, with default 900s timeout. |

### File Operations

| Method | Description |
|--------|-------------|
| `copy_from_vm(source, target)` | Copy a file out of the VM to the test result directory |
| `copy_from_host(source, target)` | Copy a file from the build host into the VM |
| `get_screen_text()` | OCR the current VM screen (needs `enableOCR`) |

### Debugging

| Method | Description |
|--------|-------------|
| `screenshot(name)` | Save a screenshot of the VM display to `result/name.png` |
| `dump_tty_contents(tty)` | Return the text content of a virtual TTY |
| `send_key(key)` | Send a key press (e.g., `"ctrl-alt-delete"`) |
| `send_chars(text)` | Type text into the VM |
| `shell_interact()` | Open an interactive shell (only in interactive driver) |

### Subtest grouping

```python
with subtest("description of what we are testing"):
    machine.succeed("systemctl is-active myservice")
    machine.succeed("curl -f http://localhost:8080/health")
```

Subtests provide labeled sections in test output for easier debugging.

## Interactive Test Driver

Build the interactive driver to get a REPL for debugging test failures:

```bash
# Build the interactive driver
nix build .#checks.x86_64-linux.mytest.driverInteractive

# Launch it -- drops you into a Python REPL with the VMs
./result/bin/nixos-test-driver
```

Inside the REPL you can call any test driver method interactively:

```python
>>> machine.start()
>>> machine.wait_for_unit("myservice.service")
>>> machine.succeed("journalctl -u myservice --no-pager")
>>> machine.screenshot("debug")
>>> machine.shell_interact()  # opens a shell inside the VM
```

This is invaluable for iterating on test scripts without rebuilding the entire test each time.

## Running Tests

### Direct build

```bash
# Build and run a test from nixpkgs
nix build -L .#checks.x86_64-linux.mytest
```

The `-L` flag streams build logs so you can watch test progress. Results (logs, screenshots) are in `./result/`.

### Via flake check

```bash
# Run all checks (including all NixOS tests registered as checks)
nix flake check -L
```

### Single test from nixpkgs

```bash
nix build -L nixpkgs#nixosTests.nginx
```

## Integration with Flake Checks

Register NixOS tests as flake checks so `nix flake check` runs them:

```nix
{
  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      checks.${system} = {
        mytest = pkgs.nixosTest {
          name = "mytest";
          nodes.machine = { ... }: {
            imports = [ self.nixosModules.myservice ];
            services.myservice.enable = true;
          };
          testScript = ''
            machine.wait_for_unit("myservice.service")
            machine.succeed("curl -f http://localhost:8080")
          '';
        };
      };

      nixosModules.myservice = ./modules/myservice.nix;
    };
}
```

This pattern lets you test your NixOS modules in isolation as part of CI.

## CI Considerations

### KVM requirement

NixOS VM tests use QEMU with KVM acceleration. CI runners need:

- **Linux host** with KVM support (`/dev/kvm` must be accessible).
- The build user must be in the `kvm` group (or `/dev/kvm` must have open permissions).
- Without KVM, tests fall back to software emulation and are extremely slow (10-100x slower).

### GitHub Actions

Use a self-hosted runner with KVM, or use `cachix/install-nix-action` with a runner that exposes `/dev/kvm`. Standard GitHub-hosted runners have KVM available on Linux.

```yaml
- uses: cachix/install-nix-action@v24
- run: nix flake check -L
```

### Cross-architecture testing

To run tests for a different architecture (e.g., `aarch64-linux` tests on `x86_64-linux`):

- Configure binfmt-misc with QEMU user-mode emulation on the host.
- On NixOS: `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`
- Performance is significantly reduced under emulation.

### Caching

Test derivations are regular Nix store paths. Use binary caches (Cachix or self-hosted) to avoid rebuilding VM images on every CI run. Only the test execution itself cannot be cached (it is the build).

### Timeout management

Long tests may exceed CI job limits. Use `globalTimeout` in the test definition:

```nix
pkgs.nixosTest {
  name = "slow-test";
  globalTimeout = 600;  # 10 minutes max
  # ...
};
```
