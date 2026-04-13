---
name: nix-containers
description: "Use for building container images with Nix including dockerTools, buildImage, buildLayeredImage, streamLayeredImage, nix2container, OCI images, Docker images, devenv container, minimal container images, layer optimization, closure analysis for containers, or running containers with NixOS virtualisation.oci-containers."
user-invocable: false
---

### Overview
Nix builds container images without Docker — images are reproducible derivations. No Dockerfile needed. Images are minimal by default: only the exact runtime closure is included.

### dockerTools.buildImage
Basic image builder. Produces a Docker-loadable tarball:
```nix
pkgs.dockerTools.buildImage {
  name = "my-app";
  tag = "latest";
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [ pkgs.myapp pkgs.cacert ];
    pathsToLink = [ "/bin" "/etc" ];
  };
  config = {
    Cmd = [ "${pkgs.myapp}/bin/myapp" ];
    ExposedPorts."8080/tcp" = {};
    Env = [ "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
  };
}
```

### dockerTools.buildLayeredImage
Produces a layered image. Nix store paths are split into layers — stable deps become lower layers (cached), frequently-changing code becomes upper layers:
```nix
pkgs.dockerTools.buildLayeredImage {
  name = "my-app";
  tag = "latest";
  contents = [ pkgs.myapp pkgs.cacert ];
  config.Cmd = [ "${pkgs.myapp}/bin/myapp" ];
  maxLayers = 120;  # Docker max is 128
}
```
The `layers` parameter lets you explicitly control which store paths go into which layers.

### dockerTools.streamLayeredImage
Like buildLayeredImage but doesn't materialize the full image in the store. Streams directly to docker load or a registry:
```nix
pkgs.dockerTools.streamLayeredImage {
  name = "my-app";
  tag = "latest";
  contents = [ pkgs.myapp ];
  config.Cmd = [ "${pkgs.myapp}/bin/myapp" ];
}
```
Usage: `$(nix build .#dockerImage --print-out-paths) | docker load`
Saves disk space and is faster for large images.

### nix2container (alternative)
Archive-less image builder using Skopeo. Faster incremental pushes:
```nix
let
  nix2container = inputs.nix2container.packages.${system}.nix2container;
in nix2container.buildImage {
  name = "my-app";
  config.entrypoint = [ "${pkgs.myapp}/bin/myapp" ];
  layers = [
    (nix2container.buildLayer { deps = [ pkgs.cacert ]; })
    (nix2container.buildLayer { deps = [ pkgs.myapp ]; })
  ];
}
```

### devenv container
devenv can build OCI images from the developer environment:
```nix
# devenv.nix
{ pkgs, ... }: {
  containers.app = {
    name = "my-app";
    copyToRoot = [ pkgs.myapp ];
    startupCommand = "${pkgs.myapp}/bin/myapp";
  };
}
```
Build: `devenv container app`

### Layer Optimization
- Separate stable deps (runtime, cacert, timezone) into lower layers
- Put application code in the top layer
- Use `layers` parameter to explicitly assign store paths to layers
- Binary size: use `removeReferencesTo` to strip build-time deps
- Use `pkgsStatic` for statically linked binaries (single-file closures)

### Closure Analysis for Containers
Before building an image, analyze what's going into it:
```bash
nix path-info -rsSh .#myapp       # Total closure size
nix why-depends .#myapp nixpkgs#gcc  # Why is gcc in the closure?
nix-tree .#myapp                   # Interactive browser
```
See the nix-performance skill for detailed closure optimization.

### initializeNixDatabase
For CI images that need to run Nix commands:
```nix
pkgs.dockerTools.buildLayeredImage {
  name = "nix-ci";
  contents = [ pkgs.nix pkgs.cacert pkgs.git ];
  config.Cmd = [ "${pkgs.bash}/bin/bash" ];
  fakeRootCommands = ''
    ${pkgs.dockerTools.shadowSetup}
  '';
  enableFakechroot = true;
  initializeNixDatabase = true;  # Populate /nix/var/nix/db
}
```

### Running Containers on NixOS
```nix
virtualisation.oci-containers = {
  backend = "podman";  # or "docker"
  containers.myapp = {
    image = "my-app:latest";
    ports = [ "8080:8080" ];
    environment = { DATABASE_URL = "..."; };
    volumes = [ "/data:/var/lib/myapp" ];
  };
};
```

### Related Skills
- nix-performance — closure analysis and optimization
- devenv — devenv container subcommand
