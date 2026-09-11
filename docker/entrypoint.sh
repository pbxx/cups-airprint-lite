#!/bin/sh
set -eu

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

admin_user="${CUPS_ADMIN_USER:-admin}"
admin_password="${CUPS_ADMIN_PASSWORD:-}"

case "$admin_user" in
    ''|*[!a-zA-Z0-9_-]*)
        echo "CUPS_ADMIN_USER may only contain letters, numbers, underscores, and hyphens." >&2
        exit 1
        ;;
esac

if [ -n "${CUPS_ADMIN_PASSWORD_FILE:-}" ]; then
    if [ ! -r "$CUPS_ADMIN_PASSWORD_FILE" ]; then
        echo "Cannot read CUPS_ADMIN_PASSWORD_FILE: $CUPS_ADMIN_PASSWORD_FILE" >&2
        exit 1
    fi
    admin_password="$(cat "$CUPS_ADMIN_PASSWORD_FILE")"
fi

if [ -z "$admin_password" ]; then
    echo "Set CUPS_ADMIN_PASSWORD or CUPS_ADMIN_PASSWORD_FILE." >&2
    exit 1
fi

if ! id -u "$admin_user" >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /sbin/nologin "$admin_user"
fi
usermod -a -G lpadmin "$admin_user"
printf '%s:%s\n' "$admin_user" "$admin_password" | chpasswd

mkdir -p /run/cups /run/dbus /run/avahi-daemon /var/spool/cups /var/log/cups
rm -f /run/cups/cupsd.pid /run/dbus/pid /run/avahi-daemon/pid

# /etc/cups is persistent, so install the image-managed server configuration
# and Alpine's packaged file/directory configuration on every start. The bind
# mount otherwise hides cups-files.conf and the TLS keychain directory, which
# makes CUPS advertise IPPS without being able to create a certificate.
# Printer definitions and PPDs remain untouched in storage.
install -m 0644 /usr/local/share/cups-container/cupsd.conf /etc/cups/cupsd.conf
install -m 0644 /usr/local/share/cups-container/cups-files.conf /etc/cups/cups-files.conf
mkdir -p /etc/cups/ssl
chown root:lp /etc/cups/ssl
chmod 0700 /etc/cups/ssl

dbus-uuidgen --ensure=/etc/machine-id

echo "Checking the CUPS configuration..."
cupsd -t

shutdown() {
    trap - INT TERM EXIT
    for pid in ${cups_pid:-} ${avahi_pid:-} ${dbus_pid:-}; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    wait 2>/dev/null || true
}
trap shutdown INT TERM EXIT

echo "Starting the system D-Bus..."
dbus-daemon --system --nofork --nopidfile &
dbus_pid=$!

# Avahi needs the system bus socket before it starts. Usually this exists
# immediately, but slower ARM boards can take a moment under load.
attempt=0
while [ ! -S /run/dbus/system_bus_socket ]; do
    if ! kill -0 "$dbus_pid" 2>/dev/null; then
        echo "The system D-Bus exited during startup." >&2
        exit 1
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 100 ]; then
        echo "Timed out waiting for the system D-Bus socket." >&2
        exit 1
    fi
    sleep 0.1
done

echo "Starting Avahi/mDNS..."
avahi-daemon --no-drop-root --no-chroot &
avahi_pid=$!

echo "Starting CUPS..."
cupsd -f &
cups_pid=$!

# Keep all three required services supervised. Their stderr remains connected
# to `docker compose logs`, which makes startup failures actionable.
while
    kill -0 "$dbus_pid" 2>/dev/null \
        && kill -0 "$avahi_pid" 2>/dev/null \
        && kill -0 "$cups_pid" 2>/dev/null
do
    sleep 2
done

if ! kill -0 "$dbus_pid" 2>/dev/null; then
    echo "The system D-Bus exited unexpectedly." >&2
elif ! kill -0 "$avahi_pid" 2>/dev/null; then
    echo "Avahi exited unexpectedly." >&2
else
    echo "CUPS exited unexpectedly." >&2
fi
exit 1
