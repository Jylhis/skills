# NixOS Testing Reference

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Basic Test Example](#basic-test-example)
- [Multi-VM Test Example](#multi-vm-test-example)
- [Container Machines (systemd-nspawn)](#container-machines-systemd-nspawn)
- [Python Test Driver API](#python-test-driver-api)
- [Interactive Test Driver](#interactive-test-driver)
- [Running Tests](#running-tests)
- [Integration with Flake Checks](#integration-with-flake-checks)
- [CI Considerations](#ci-considerations)

## Overview

NixOS VM tests run services inside QEMU virtual machines (and, since 26.05, optionally `systemd-nspawn` containers) controlled by a Python test driver. Tests are fully reproducible -- the VM images are built from NixOS module configurations, and the test script exercises them deterministically. No network access or elevated privileges are needed at test time (beyond KVM for hardware acceleration).

Key properties:

- Each test spins up one or more QEMU VMs defined as NixOS configurations.
- The Python test driver boots VMs, waits for services, runs assertions.
- Tests produce a `result/` directory with logs and optional screenshots.
- The entire test (VM images + execution) is a single Nix derivation.

## Test Structure

A NixOS test is a module evaluated by `runTest`. Outside nixpkgs, call it with `pkgs.testers.runNixOSTest`, which uses your `pkgs` and makes `nixpkgs.*` read-only in the nodes. The old top-level `pkgs.nixosTest` alias throws since 25.11 ("renamed to `testers.nixosTest`"); `pkgs.testers.nixosTest` still exists for the legacy `make-test-python.nix` interface, but new code should use `runNixOSTest`. Inside nixpkgs, tests are registered in `nixos/tests/all-tests.nix` as `runTest ./foo.nix`.

| Field | Description |
|-------|-------------|
| `name` | Test identifier (used in derivation name and logs) |
| `nodes` | Attribute set of machine names to NixOS configurations (QEMU VMs) |
| `containers` | Same, but run as `systemd-nspawn` containers (26.05+) |
| `defaults` | NixOS config applied to every machine (`nodeDefaults` / `containerDefaults` target one kind) |
| `testScript` | Python script that drives the machines |

Optional fields: `skipLint` (skip linting of testScript, done with `ruff check --select F` in 26.05), `skipTypeCheck` (skip type checking, done with `ty` in 26.05), `extraPythonPackages` (`p: [ p.numpy ]`), `enableOCR` (enable OCR for screenshot assertions), `globalTimeout` (seconds before the test is killed, default 3600), `sshBackdoor.enable` and `enableDebugHook` (see [Debugging in the sandbox](#debugging-in-the-sandbox)).

The returned derivation supports `.driverInteractive`, `.nodes` (evaluated configs), `.extendNixOS { module = ...; }` (add a module to every machine, handy in `passthru.tests`) and `.overrideTestDerivation`.

## Basic Test Example

```nix
{ pkgs, ... }:
pkgs.testers.runNixOSTest {
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

Every node becomes a Python variable named after its attribute (`nodes.machine` is `machine`; characters invalid in Python names become `_`, so `nodes.machine-a` is `machine_a`). A test with exactly one machine also gets a `machine` alias, whatever the node is called. Machines start implicitly on their first action, so `machine.start()` is optional. The variable `t` exposes `unittest.TestCase` assertions, e.g. `t.assertIn("Linux", machine.succeed("uname"))`.

## Multi-VM Test Example

Multiple nodes communicate over a virtual network. Each node gets a hostname matching its attribute name.

```nix
{ pkgs, ... }:
pkgs.testers.runNixOSTest {
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
    start_all()

    server.wait_for_unit("myservice.service")
    server.wait_for_open_port(8080)

    # Client connects to server by hostname
    client.wait_for_unit("network-online.target")
    client.succeed("curl -f http://server:8080")
  '';
}
```

`start_all()` boots every machine in parallel, which is faster than letting each one start lazily on first use. The virtual network resolves hostnames between VMs.

## Container Machines (systemd-nspawn)

Since 26.05 a test can declare `containers.<name>` next to (or instead of) `nodes.<name>`. Containers share the host kernel, start much faster, run on builders without KVM (including CI VMs), and can bind-mount host devices for GPU/CUDA tests:

```nix
pkgs.testers.runNixOSTest {
  name = "fast-test";
  containers.machine = { ... }: {
    services.myservice.enable = true;
  };
  testScript = ''
    machine.wait_for_unit("myservice.service")
  '';
}
```

Use VMs instead when the test needs its own kernel or kernel modules, X11, systemd sandboxing options (`ProtectSystem=`, `MountAPIVFS=`), specialisations, or setuid binaries. The builder needs:

```nix
{
  nix.settings = {
    auto-allocate-uids = true;
    extra-system-features = [ "uid-range" ];
    experimental-features = [ "auto-allocate-uids" "cgroups" ];
  };
}
```

Mixing containers and VMs on one VLAN additionally needs `nix.settings.sandbox-paths = [ "/dev/net" ];`. Extra nspawn flags go in `virtualisation.systemd-nspawn.options`.

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
| `wait_until_fails(cmd)` | Retry a shell command until it exits non-zero |
| `wait_for_file(path)` | Block until a file exists |
| `wait_for_open_unix_socket(path)` | Block until a Unix socket accepts connections |
| `wait_for_console_text(regex)` | Wait until the serial console output matches regex |
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
| `copy_from_machine(source, target_dir)` | Copy a file out of the machine into `$out/<target_dir>` (`copy_from_vm` is a deprecated alias) |
| `copy_from_host(source, target)` | Copy a file from the build host (the sandbox) into the machine |
| `get_screen_text()` | OCR the current VM screen (needs `enableOCR`) |

### Debugging

| Method | Description |
|--------|-------------|
| `screenshot(name)` | Save a screenshot of the VM display to `result/name.png` |
| `get_tty_text(tty)` | Return the text content of a virtual TTY (`dump_tty_contents` logs it instead) |
| `send_key(key)` | Send a key press (e.g., `"ctrl-alt-delete"`) |
| `send_chars(text)` | Type text into the VM |
| `shell_interact()` | Open an interactive shell (only in interactive driver) |
| `get_unit_info(unit)` / `require_unit_state(unit, state)` | Inspect systemd unit properties |

### Subtest grouping

```python
with subtest("description of what we are testing"):
    machine.succeed("systemctl is-active myservice")
    machine.succeed("curl -f http://localhost:8080/health")
```

Subtests provide labeled sections in test output for easier debugging.

### Fail early with polling conditions

```python
@polling_condition
def foo_running():
    machine.succeed("pgrep -x foo")

with foo_running:
    ...  # the test fails as soon as foo dies, instead of timing out later
```

## Interactive Test Driver

Build the interactive driver to get a REPL for debugging test failures:

```bash
# Build the interactive driver
nix build .#checks.x86_64-linux.mytest.driverInteractive

# Launch it -- drops you into a Python REPL with the VMs
./result/bin/nixos-test-driver
```

Inside the REPL you can call any test driver method interactively (`test_script()` runs the whole script and returns to the prompt):

```python
>>> start_all()
>>> test_script()
>>> machine.wait_for_unit("myservice.service")
>>> machine.succeed("journalctl -u myservice --no-pager")
>>> machine.screenshot("debug")
>>> machine.shell_interact()  # opens a shell inside the VM
```

This is invaluable for iterating on test scripts without rebuilding the entire test each time. Container machines need `sudo ./result/bin/nixos-test-driver`.

Useful extras for the interactive driver:

- **SSH backdoor.** Set `interactive.sshBackdoor.enable = true;` in the test. Each VM gets an AF_VSOCK SSH endpoint (root, empty password); the driver prints commands like `ssh -o User=root vsock-mux//tmp/.../machine_host.socket`, and `dump_machine_ssh()` prints them again. Needs `systemd-ssh-proxy(1)` on the host (default on NixOS 25.05+).
- **Keep state.** `./result/bin/nixos-test-driver --keep-machine-state` reuses VM disks from the last run.
- **Port forwarding.** For a single VM, `QEMU_NET_OPTS="hostfwd=tcp:127.0.0.1:2222-:22" ./result/bin/nixos-test-driver`.
- **Interactive-only config.** Anything under the test's `interactive` submodule only applies to `.driverInteractive`.

### Debugging in the sandbox

For failures that only happen in `nix build`, set `enableDebugHook = true;` (optionally with `sshBackdoor.enable = true;`). The test pauses on the first failure and prints `sudo .../bin/attach <PID>` to enter the build sandbox; from there `telnet 127.0.0.1 4444` reaches a `pdb` session and the printed SSH command reaches the machines. `debug.breakpoint()` sets a breakpoint in the test script.

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
        mytest = pkgs.testers.runNixOSTest {
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

Use a self-hosted runner with KVM, or use `cachix/install-nix-action` with a runner that exposes `/dev/kvm`. Standard GitHub-hosted runners have KVM available on Linux; `install-nix-action` enables it by default (`enable_kvm: true`).

```yaml
- uses: cachix/install-nix-action@v31
- run: nix flake check -L
```

Builders without KVM (for example CI jobs that are themselves VMs) can still run tests that use `containers` instead of `nodes`.

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
pkgs.testers.runNixOSTest {
  name = "slow-test";
  globalTimeout = 600;  # 10 minutes max (default is 3600)
  # ...
};
```
