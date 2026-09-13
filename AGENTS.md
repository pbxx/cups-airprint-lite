# Project guidance

## Purpose

This repository builds a small CUPS print server that exposes physical USB
printers to Apple AirPrint clients using CUPS DNS-SD announcements and Avahi.
The primary deployment target is a 32-bit ARMv7 Raspberry Pi running Docker on
Linux. Keep `linux/arm/v6`, `linux/arm/v7`, `linux/arm64`, `linux/386`, and
`linux/amd64` support working; do not introduce packages or binaries limited
to only one of these architectures.

## Runtime architecture

- `Dockerfile` is based on the multi-architecture Alpine image. All installed
  packages must exist for Alpine `armhf`, `armv7`, `aarch64`, `x86`, and
  `x86_64`.
- `compose.yaml` is the user-facing deployment file and lets Docker select the
  matching platform from the published multi-platform image.
- `compose.dev.yaml` defaults local builds to `linux/arm/v7`;
  `DOCKER_PLATFORM` can select another supported platform.
- Host networking is required so multicast DNS reaches the physical LAN with a
  usable address. Do not replace it with ordinary port publishing unless the
  complete mDNS behavior is redesigned and tested.
- Privileged mode and `/dev/bus/usb` passthrough provide USB access and hotplug.
- `docker/entrypoint.sh` supervises D-Bus, Avahi, and CUPS. All three are
  required, and their output should remain visible through Compose logs.
- `docker/cupsd.conf` explicitly publishes `_cups`, `_print`, and `_universal`
  DNS-SD subtypes. `_universal` is required for AirPrint discovery.
- Printer definitions, PPDs, and `cupsd.conf` persist in the
  `./data/cups-config` bind mount; pending jobs persist in
  `./data/cups-spool`. The image-managed `cupsd.conf` is copied into the
  configuration directory only when no persisted file exists.

## Security and compatibility constraints

- Keep CUPS limited to `@LOCAL` clients and require an `@SYSTEM` user for
  administrative routes.
- `compose.yaml` contains obvious placeholder administrator credentials to keep
  initial setup self-contained. Documentation must tell users to replace the
  placeholder before starting the container. Never commit a real deployment
  password or replace the placeholder with a usable default credential.
- Do not add `ipp-usb` without accounting for its exclusive ownership of some
  USB printer interfaces and its interaction with the CUPS USB backend.
- Treat `docker/cupsd.conf` as the first-run default. Keep the conditional
  entrypoint copy into `/etc/cups`, but do not overwrite an existing file:
  web-UI and manual edits to the persisted `cupsd.conf` must survive restarts.
  Document configuration changes that existing installations may need to
  merge when upgrading.

## Validation

Before handing off changes, run what the environment supports:

```sh
docker compose -f compose.yaml config
docker buildx build --platform linux/arm/v7 --load -t cups-airprint-lite:test .
docker run --rm --platform linux/arm/v7 cups-airprint-lite:test cupsd -t
git diff --check
```

An x86 development machine needs binfmt/QEMU configured to execute the ARMv7
image. On the target Pi, the development Compose override builds the native
ARMv7 platform. For runtime failures, capture
`docker compose logs --tail=100 cups`; do not diagnose from the restart status
alone.
