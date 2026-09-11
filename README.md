![cups-airprint-lite banner](/logo.png)

# cups-airprint-lite

A lightweight Docker image that shares USB printers through CUPS and makes
them discoverable by AirPrint clients on the local network.

The image targets Raspberry Pi and other Linux hosts. Supported platforms are
`linux/arm/v6`, `linux/arm/v7` (the default), `linux/arm64`, `linux/386`, and
`linux/amd64`. It includes CUPS, Avahi, common open-source printer drivers, and
persistent storage for printer configuration and queued jobs.

## Quick start

Requirements: Docker Compose on a Linux host and a connected USB printer.
Docker Desktop is not supported because AirPrint discovery relies on host
networking and multicast DNS.

1. In `compose.yaml`, replace `change-me-to-a-strong-password` with a strong
   CUPS administrator password before starting the container.
2. Create the persistent directories and start the service:

   ```sh
   mkdir -p data/cups-config data/cups-spool
   docker compose up -d --build
   ```

3. Open `http://<docker-host>:631/admin`, sign in with the credentials from
   `compose.yaml`, and select **Add Printer**.
4. Choose the printer and its driver, then enable **Share This Printer**.

The printer should now appear in the print dialogs on iOS, iPadOS, and macOS.

To build for a different supported platform, set `DOCKER_PLATFORM`:

```sh
DOCKER_PLATFORM=linux/arm64 docker compose up -d --build
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
- `docker/cupsd.conf` is image-managed and restored on every start. Edit it in
  the repository and rebuild instead of changing it through the web UI.
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
