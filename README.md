#  Host Bluetooth Integration for Home Assistant in LXC

[![Proxmox](https://img.shields.io/badge/Platform-Proxmox-blue)](https://www.proxmox.com)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Bluetooth%20Enabled-green)](https://www.home-assistant.io)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

Expose your host's Bluetooth stack to a Home Assistant container running inside LXC. This setup enables full access to BLE sensors, pairing, scanning, and device management—without privileged access or hardware passthrough.

### Frequently Asked Questions (not really, but let's just say they are...)

Q: Wouldn't this be easier to just use a VM?    
A: Yes, probably. However, on my machine, resources are limited.    

Q: Why not just pass the USB device through Proxmox?    
A: Because it's an LXC container and not a VM.    

Q: How do you handle the USB address changing on reboot or unplugging/replugging the bluetooth adapter?   
A: I don't have to, unlike other setups, that's not a concern.    

---
## My Setup
```
    Proxmox Host    
    ├── LXC Container: Home Assistant    
    │   ├── Docker: homeassistant/home-assistant    
    │   ├── Docker: MQTT Bridge    
    │   └── Docker: Node-RED    
    ├── LXC Container: Jellyfin    
    └── LXC Container: other server...    
```

- **Proxmox Host**: Manages all containers and hardware resources
- **Home Assistant LXC**: Runs Dockerized Home Assistant and supporting services
- **MQTT Bridge**: Facilitates communication between Zigbee/MQTT and other services
- **Node-RED**: Handles automation logic and flows

---

##  Features

- Full access to host Bluetooth via D-Bus and HCI proxy
- Compatible with Home Assistant Docker or native installs
- Works with BLE sensors, presence tracking, and pairing
- No need for privileged containers or USB passthrough

---

#  Setup Instructions

While you can just run the installation script to complete the first two steps, though you may need to make adjustments for your setup, so full setup directions are provided.

```bash
chmod +x install.sh
./install.sh
```

---

### 1. Proxy HCI Access from Host

Create `/opt/bluetooth-proxy/hci-proxy.sh`:

```bash
#!/bin/bash
SOCKET="/tmp/bluetooth_proxy.sock"
rm -f "$SOCKET"
exec socat UNIX-LISTEN:"$SOCKET",fork,reuseaddr EXEC:/bin/bash
```

Create systemd service `/etc/systemd/system/bluetooth-proxy.service`:

```bash
[Unit]
Description=Bluetooth HCI Proxy for LXC
After=bluetooth.target

[Service]
ExecStart=/opt/bluetooth-proxy/hci-proxy.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```

Enable and start:

```shell

systemctl daemon-reexec
systemctl enable --now bluetooth-proxy
```


---

### 2. Proxy D-Bus System Socket

Create `/opt/dbus-proxy/dbus-proxy.sh`:

```bash
#!/bin/bash
SOCKET="/tmp/dbus_proxy.sock"
rm -f "$SOCKET"
exec socat UNIX-LISTEN:"$SOCKET",fork,reuseaddr UNIX-CONNECT:/run/dbus/system_bus_socket
```

Create systemd service `/etc/systemd/system/dbus-proxy.service`:

```bash
[Unit]
Description=D-Bus Proxy for LXC
After=dbus.service

[Service]
Type=simple
Environment=DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbus_proxy.sock
ExecStart=/opt/dbus-proxy/dbus-proxy.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```

Enable and start:

```shell
systemctl daemon-reexec
systemctl enable --now dbus-proxy
```


---

### 3. Bind-Mount into LXC Container
Edit `/etc/pve/lxc/<vmid>.conf`:

```bash
lxc.mount.entry: /tmp/bluetooth_proxy.sock tmp/bluetooth_proxy.sock none bind,create=file
lxc.mount.entry: /tmp/dbus_proxy.sock tmp/dbus_proxy.sock none bind,create=file
lxc.mount.entry: /var/lib/bluetooth var/lib/bluetooth none bind,create=dir
```

Restart container:

```shell
pct restart <vmid>
```



---

### 4. Configure Container

Inside the container:

```shell
apt update
apt install bluetooth bluez dbus dbus-broker
systemctl enable dbus-broker
systemctl mask dbus
systemctl mask bluetooth
```

Reboot container:

```shell
reboot
```

---

### 5. Run Home Assistant with Bluetooth Support
If using Docker from the command line:

```shell
docker run \
  -v /tmp/dbus_proxy.sock:/tmp/dbus_proxy.sock \
  -v /var/lib/bluetooth:/var/lib/bluetooth \
  --network host \
  -e DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbus_proxy.sock \
  --cap-add=NET_ADMIN --cap-add=NET_RAW  \
  homeassistant/home-assistant:latest
```

If using Docker Compose:

```yaml
version: '3.8'

services:
  homeassistant:
    image: homeassistant/home-assistant:latest
    container_name: homeassistant
    network_mode: host
    environment:
      - DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/dbus_proxy.sock
    volumes:
      - /tmp/dbus_proxy.sock:/tmp/dbus_proxy.sock
      - /var/lib/bluetooth:/var/lib/bluetooth
    cap_add:
      - NET_ADMIN
      - NET_RAW
    restart: unless-stopped
```

If using Portainer:    

![Volumes in Portainer](assets/screenshot_vol.png)

![Network Settings in Portainer](assets/screenshot_net.png)

![Environment Variables in Portainer](assets/screenshot_env.png)

![Capabilities in Portainer](assets/screenshot_cap.png)



### In Home Assistant UI:

- Go to Settings → Devices & Services
- Add Bluetooth integration
- Scan and pair devices

### Testing

Inside the container:

```shell
bluetoothctl
scan on
devices
```

### Notes

- Pairing info is stored in /var/lib/bluetooth on the host
- Multiple containers can share the same adapter via separate proxies
- Works with BLE sensors like Xiaomi, Inkbird, and more

### License

This project is licensed under the MIT License.

### Credits

Inspired by community efforts to bridge host hardware with containerized automation platforms.

---

Let me know if you'd like to add provisioning scripts, systemd templates, or Docker Compose examples.
