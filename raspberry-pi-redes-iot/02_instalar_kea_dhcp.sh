#!/bin/bash
set -u
SERVER_IP="192.168.10.1"; PREFIX="24"; SUBNET="192.168.10.0/24"
POOL_START="192.168.10.100"; POOL_END="192.168.10.200"
BACKUP="/root/backup_kea_$(date +%Y%m%d_%H%M%S)"
ok(){ echo "[OK] $*"; }; warn(){ echo "[AVISO] $*"; }; fail(){ echo "[ERROR] $*" >&2; exit 1; }
[ "$EUID" -eq 0 ] || fail "Ejecute: sudo ./02_instalar_kea_dhcp.sh"
IFACE=""
if ip link show eth0 >/dev/null 2>&1; then IFACE="eth0"; else IFACE=$(ls /sys/class/net 2>/dev/null | grep -E '^(eth|en)' | head -n1 || true); fi
[ -n "$IFACE" ] || fail "No se encontró una interfaz Ethernet."
echo "Servidor: $SERVER_IP/$PREFIX | Pool: $POOL_START - $POOL_END"
read -r -p "¿Continuar? [S/n]: " R; R=${R:-S}; case "$R" in s|S|si|SI|Si) ;; *) exit 0;; esac
mkdir -p "$BACKUP"; [ -d /etc/kea ] && cp -a /etc/kea "$BACKUP/" 2>/dev/null || true
if ! command -v kea-dhcp4 >/dev/null 2>&1; then apt-get update || fail "Falló apt-get update."; apt-get install -y kea-dhcp4-server || fail "No fue posible instalar Kea."; fi
if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager; then
 CONN=$(nmcli -t -f NAME,DEVICE connection show | awk -F: -v d="$IFACE" '$2==d {print $1; exit}')
 if [ -z "$CONN" ]; then CONN="LAB-KEA-$IFACE"; nmcli connection add type ethernet ifname "$IFACE" con-name "$CONN" ipv4.method manual ipv4.addresses "$SERVER_IP/$PREFIX" ipv6.method disabled >/dev/null || fail "No se pudo crear la conexión.";
 else nmcli connection modify "$CONN" ipv4.method manual ipv4.addresses "$SERVER_IP/$PREFIX" ipv4.gateway "" ipv4.never-default yes ipv6.method disabled || fail "No se pudo modificar la conexión."; fi
 nmcli connection up "$CONN" >/dev/null || fail "No se pudo activar $CONN."
elif command -v dhcpcd >/dev/null 2>&1 && [ -f /etc/dhcpcd.conf ]; then
 sed -i '/# BEGIN LAB-KEA/,/# END LAB-KEA/d' /etc/dhcpcd.conf
 cat >> /etc/dhcpcd.conf <<EOF
# BEGIN LAB-KEA
interface $IFACE
static ip_address=$SERVER_IP/$PREFIX
nogateway
# END LAB-KEA
EOF
 systemctl restart dhcpcd || fail "No se pudo reiniciar dhcpcd."
else fail "Gestor de red no reconocido."; fi
KEA_CONF="/etc/kea/kea-dhcp4.conf"; mkdir -p /etc/kea /var/lib/kea
cat > "$KEA_CONF" <<EOF
{"Dhcp4":{"interfaces-config":{"interfaces":["$IFACE"]},"lease-database":{"type":"memfile","persist":true,"name":"/var/lib/kea/kea-leases4.csv"},"valid-lifetime":3600,"renew-timer":900,"rebind-timer":1800,"subnet4":[{"subnet":"$SUBNET","pools":[{"pool":"$POOL_START - $POOL_END"}]}]}}
EOF
kea-dhcp4 -t "$KEA_CONF" || fail "Configuración Kea inválida."
systemctl enable kea-dhcp4-server >/dev/null; systemctl restart kea-dhcp4-server || fail "Kea no pudo iniciar."
ok "Kea DHCP4 activo. Raspberry Pi: $SERVER_IP/$PREFIX. Pool: $POOL_START - $POOL_END"
