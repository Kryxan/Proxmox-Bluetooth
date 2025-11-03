#!/bin/bash
SOCKET="/tmp/dbus_proxy.sock"
rm -f "$SOCKET"
exec socat UNIX-LISTEN:"$SOCKET",fork,reuseaddr UNIX-CONNECT:/run/dbus/system_bus_socket
