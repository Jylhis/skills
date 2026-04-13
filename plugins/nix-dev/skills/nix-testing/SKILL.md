---
name: nix-testing
description: "Use for NixOS integration testing including VM tests, nixosTest, test driver, Python test scripts, multi-VM tests, NixOS VM test framework, nix flake check tests, interactive test driver, namaka snapshot testing, or CI integration for NixOS tests."
user-invocable: false
---

### Overview
NixOS provides a VM-based integration testing framework. Tests run in isolated QEMU virtual machines with full NixOS systems. Tests are reproducible, hermetic, and can orchestrate multiple VMs.

### Basic Test Structure
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

### Multi-VM Tests
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

### Python Test Driver API
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

### Integration with Flake Checks
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

### Interactive Test Driver
Debug failing tests interactively:
```bash
nix build .#checks.x86_64-linux.mytest.driverInteractive
./result/bin/nixos-test-driver
```
This drops you into a Python REPL with machine objects. You can run commands, inspect state, take screenshots.

### namaka (Snapshot Testing)
For testing Nix expressions (not VMs):
```nix
namaka.lib.load {
  src = ./tests;
  inputs = { inherit (inputs) nixpkgs; };
};
```
Captures evaluation results as snapshots. On subsequent runs, compares against snapshots. `namaka review` to accept changes.

### CI Considerations
- NixOS VM tests require KVM support. GitHub Actions runners support this with `runs-on: ubuntu-latest` (nested virtualization is enabled).
- For cross-architecture testing (e.g., aarch64 tests on x86_64), use binfmt emulation.
- Tests can be slow — consider running only affected tests in PRs.
- Set `virtualisation.memorySize` and `virtualisation.cores` in test nodes to control resource usage.

### Related Skills
- nixos-modules — writing modules that tests validate
- nix-linting — CI pipeline integration
