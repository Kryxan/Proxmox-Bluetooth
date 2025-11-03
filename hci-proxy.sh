#!/bin/bash
SOCKET="/tmp/bluetooth_proxy.sock"
rm -f "$SOCKET"
exec socat UNIX-LISTEN:"$SOCKET",fork,reuseaddr EXEC:/bin/bash
