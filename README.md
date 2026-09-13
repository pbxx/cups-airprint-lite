![cups-airprint-lite banner](/logo.png)

# cups-airprint-lite

A lightweight Docker image that shares USB printers through CUPS and makes
them discoverable by IPP and AirPrint clients on the local network.

It includes CUPS, Avahi, common open-source printer drivers, and
persistent storage for printer configuration and queued jobs.

The image targets a wide variety of platforms, including the Raspberry Pi.

| Platform       | Typical hardware                              |
| -------------- | --------------------------------------------- |
| `linux/arm/v6` | Raspberry Pi Zero/Zero W and first-generation Pi |
| `linux/arm/v7` | Raspberry Pi 2/3 and other 32-bit ARM boards  |
| `linux/arm64`  | 64-bit Raspberry Pi and other ARM64 boards    |
| `linux/386`    | Older 32-bit Intel/AMD PCs                    |
| `linux/amd64`  | Modern 64-bit Intel/AMD PCs and servers       |

## Quick start

Requirements: Docker Compose on a Linux host and a connected USB printer.
Docker Desktop is not supported because AirPrint discovery relies on host
networking and multicast DNS.

1. In `compose.yaml`, replace `change-me-to-a-strong-password` with a strong
   CUPS administrator password before starting the container.
2. Create the persistent directories and start the service:

   ```sh
   mkdir -p data/cups-config data/cups-spool
   docker compose up -d
   ```

3. Open `http://<docker-host>:631/admin`, sign in with the credentials from
   `compose.yaml`, and select **Add Printer**.
4. Choose the printer and its driver, then enable **Share This Printer**.

The printer should now appear in the print dialogs on iOS, iPadOS, and macOS.

Docker automatically pulls the image variant matching the host architecture.

## Local development

Use `compose.dev.yaml` together with the ready-to-run Compose file to build the
image from the local checkout instead of using the Docker Hub image:

```sh
docker compose -f compose.yaml -f compose.dev.yaml up -d --build
```

Local development builds default to the project's primary ARMv7 target. Set
`DOCKER_PLATFORM` to build for another supported platform. For example:

```sh
DOCKER_PLATFORM=linux/amd64 docker compose -f compose.yaml -f compose.dev.yaml up -d --build
```

## Configuration notes

- Host networking is required for reliable AirPrint/mDNS discovery.
- Privileged mode and `/dev/bus/usb` provide USB access and hotplug support.
- CUPS accepts connections only from local subnets (`@LOCAL`). Do not expose
  port 631 to the public internet.
- Administrator credentials are stored as plain text in `compose.yaml`.
  Alternatively, set `CUPS_ADMIN_PASSWORD_FILE` in a secret-managed setup.
- Printer definitions and PPDs persist in `data/cups-config`; pending jobs
  persist in `data/cups-spool`.
- On first start, a `docker/cupsd.conf` is copied to the persistent
  `data/cups-config` directory if one isn't present already. Later changes made through the CUPS web UI or
  directly in `data/cups-config/cupsd.conf` survive restarts and image upgrades.
  file while the container is stopped so it is recreated on the next start.
- Serial and parallel printers require their device node to be added to
  `compose.yaml`.

## Useful commands

```sh
# Follow startup and service logs
docker compose logs --tail=100 -f cups

# Confirm that the USB printer is visible
docker compose exec cups lsusb

# List configured queues
docker compose exec cups lpstat -t
```

To back up or move an installation, stop the service and copy the repository
together with the entire `data` directory.
