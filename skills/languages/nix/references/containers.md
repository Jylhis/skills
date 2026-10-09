### Overview

Nix builds container images without Docker — images are reproducible derivations. No Dockerfile needed. Images are minimal by default: only the exact runtime closure is included.

### "Container" Disambiguation

The Nix ecosystem uses "container" for two unrelated things — don't conflate them:

| Term | What it is | Covered in |
|------|-----------|-----------|
| **OCI image** (dockerTools, nix2container) | A tarball loadable by Docker / podman / Kubernetes runtimes | This skill |
| **NixOS container** (`containers.<name>` option) | A local lightweight system container using `systemd-nspawn` | nixos-modules skill (RFC 108) |

RFC 108 rewrites the NixOS `containers.<name>` subsystem on top of `systemd-nspawn` + `systemd-networkd`, fixing networking-during-boot bugs. That's orthogonal to `dockerTools` OCI image builders described below — the latter produce images consumed by external OCI runtimes, not local NixOS containers.

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
  maxLayers = 120;  # default 100; stay under the runtime's layer limit
}
```

`buildLayeredImage` is `streamLayeredImage` plus a step that writes the compressed tarball into the store, so both take the same arguments. Since 25.11 the default layering gives each of the largest store paths its own layer and folds in dependencies not shared elsewhere, which shares far more layers between images once the closure exceeds `maxLayers`. For explicit control there is `layeringPipeline` (it replaces `maxLayers`); the source marks that interface as highly experimental. dockerTools has no `layers` argument; that is nix2container.

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

It is not in Nixpkgs; take it as a flake input (`github:nlewo/nix2container`). Images are never written as tarballs to the store. Push or load with the generated apps: `nix run .#image.copyToDockerDaemon`, `.copyToPodman`, `.copyToRegistry`. `maxLayers` defaults to 1 here (popularity-based splitting applies only to the image's own layer, not to `layers`), and `perms` sets file modes without root or a VM.

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

Build: `devenv container build app`. Run with `devenv container run app`; push with `devenv container --registry docker://<registry>/ copy app` (devenv 2.0 removed the old `devenv container --copy <name>` form).

### Layer Optimization

- Separate stable deps (runtime, cacert, timezone) into lower layers
- Put application code in the top layer
- Explicit layer assignment: `layers = [ (buildLayer { deps = ...; }) ]` in nix2container; `layeringPipeline` (experimental) in dockerTools
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

### includeNixDB (Nix inside the image)

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
  includeNixDB = true;  # Register the image's store paths in /nix/var/nix/db
}
```

dockerTools calls this `includeNixDB` (also on `buildImage`; `buildImageWithNixDb`/`buildLayeredImageWithNixDb` are shorthands). It registers the closure of `contents`/`copyToRoot` only and does not combine well with `fromImage`. nix2container's equivalent is `initializeNixDatabase = true`. To get a shell image of a package's build environment, use `dockerTools.buildNixShellImage { drv = pkgs.hello; }` (or `streamNixShellImage`).

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
