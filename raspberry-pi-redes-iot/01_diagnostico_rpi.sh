#!/bin/bash
set -u
linea() { printf '%s
' "============================================================"; }
linea
echo " DIAGNOSTICO RASPBERRY PI - KEA DHCP + APACHE"
linea
echo; echo "[1] MODELO"
if [ -r /proc/device-tree/model ]; then tr -d '\0' < /proc/device-tree/model; echo; else echo "No se pudo leer /proc/device-tree/model"; fi
echo; echo "[2] SISTEMA OPERATIVO"
if [ -r /etc/os-release ]; then . /etc/os-release; echo "${PRETTY_NAME:-Desconocido}"; else echo "No identificado"; fi
echo; echo "[3] ARQUITECTURA"; uname -m
echo; echo "[4] INTERFACES DE RED"; ip -br link 2>/dev/null || ip link
echo; echo "[5] DIRECCIONES IPv4 ACTUALES"; ip -br -4 addr 2>/dev/null || ip -4 addr
echo; echo "[6] INTERFAZ ETHERNET PROPUESTA"
IFACE=""
if ip link show eth0 >/dev/null 2>&1; then IFACE="eth0"; else IFACE=$(ls /sys/class/net 2>/dev/null | grep -E '^(eth|en)' | head -n1 || true); fi
if [ -n "$IFACE" ]; then echo "$IFACE"; else echo "No se encontró interfaz Ethernet."; fi
echo; echo "[7] GESTOR DE RED"
if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager 2>/dev/null; then echo "NetworkManager: ACTIVO"; else echo "NetworkManager: no activo/no instalado"; fi
if command -v dhcpcd >/dev/null 2>&1; then echo "dhcpcd: instalado"; else echo "dhcpcd: no instalado"; fi
echo; echo "[8] CONEXION A INTERNET"
if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then echo "Acceso IP a Internet: SI"; else echo "Acceso IP a Internet: NO"; fi
if getent hosts deb.debian.org >/dev/null 2>&1; then echo "Resolución DNS: SI"; else echo "Resolución DNS: NO"; fi
echo; echo "[9] KEA DHCP"
if command -v kea-dhcp4 >/dev/null 2>&1; then echo "kea-dhcp4: instalado"; else echo "kea-dhcp4: no instalado"; fi
if systemctl is-active --quiet kea-dhcp4-server 2>/dev/null; then echo "Servicio kea-dhcp4-server: ACTIVO"; else echo "Servicio kea-dhcp4-server: no activo"; fi
echo; echo "[10] APACHE"
if command -v apache2 >/dev/null 2>&1; then echo "Apache2: instalado"; else echo "Apache2: no instalado"; fi
if systemctl is-active --quiet apache2 2>/dev/null; then echo "Servicio apache2: ACTIVO"; else echo "Servicio apache2: no activo"; fi
echo; echo "[11] PUERTOS DE INTERES"
if command -v ss >/dev/null 2>&1; then
 echo "DHCP/UDP 67:"; ss -lunp 2>/dev/null | grep -E '(:67[[:space:]])' || echo "Sin proceso escuchando detectado."
 echo "HTTP/TCP 80:"; ss -ltnp 2>/dev/null | grep -E '(:80[[:space:]])' || echo "Sin proceso escuchando detectado."
fi
echo; linea; echo "DIAGNOSTICO TERMINADO. No se modificó ninguna configuración."; linea
