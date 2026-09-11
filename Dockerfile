FROM alpine:3.24

# Keep this list architecture-neutral so the same Dockerfile builds for
# linux/arm/v6, linux/arm/v7, linux/arm64, linux/386, and linux/amd64. The
# driver packages cover common PostScript/PCL, Canon, Epson, HP, Brother, and
# Samsung printers without installing proprietary, glibc-only vendor binaries.
RUN apk add --no-cache \
        avahi \
        brlaser \
        cups \
        cups-client \
        cups-filters \
        dbus \
        epson-inkjet-printer-escpr \
        ghostscript \
        gutenprint-cups \
        hplip \
        shadow \
        splix \
        tini \
        usbutils

COPY docker/cupsd.conf /usr/local/share/cups-container/cupsd.conf
COPY docker/avahi-daemon.conf /etc/avahi/avahi-daemon.conf
COPY docker/entrypoint.sh /usr/local/bin/container-entrypoint

RUN install -m 0644 /etc/cups/cups-files.conf \
        /usr/local/share/cups-container/cups-files.conf \
    && install -m 0644 /usr/local/share/cups-container/cupsd.conf \
        /etc/cups/cupsd.conf \
    && mkdir -p /run/cups /run/dbus /var/spool/cups /var/log/cups \
    && cupsd -t \
    && chmod 0755 /usr/local/bin/container-entrypoint

EXPOSE 631/tcp 5353/udp

VOLUME ["/etc/cups", "/var/spool/cups"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD lpstat -r | grep -q "scheduler is running" || exit 1

ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/local/bin/container-entrypoint"]
