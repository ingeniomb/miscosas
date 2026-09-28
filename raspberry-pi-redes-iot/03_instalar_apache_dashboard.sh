#!/bin/bash
set -u
SERVER_IP="192.168.10.1"
BACKUP="/root/backup_apache_$(date +%Y%m%d_%H%M%S)"
ok(){ echo "[OK] $*"; }; fail(){ echo "[ERROR] $*" >&2; exit 1; }
[ "$EUID" -eq 0 ] || fail "Ejecute: sudo ./03_instalar_apache_dashboard.sh"
mkdir -p "$BACKUP"
[ -f /var/www/html/index.html ] && cp -a /var/www/html/index.html "$BACKUP/" || true
if ! command -v apache2 >/dev/null 2>&1; then apt-get update || fail "Falló apt-get update."; apt-get install -y apache2 python3 curl || fail "No fue posible instalar Apache/Python/curl."; fi
a2enmod cgi >/dev/null || fail "No se pudo habilitar CGI."
systemctl enable apache2 >/dev/null; systemctl restart apache2 || fail "No se pudo iniciar Apache."
mkdir -p /usr/lib/cgi-bin
cat > /usr/lib/cgi-bin/datos.py <<'PY'
#!/usr/bin/python3
import json, socket, subprocess
print("Content-Type: application/json"); print()
def temperatura_cpu():
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f: return round(float(f.read().strip())/1000.0,1)
    except Exception: return None
def tiempo_activo():
    try: return subprocess.check_output(["uptime","-p"],text=True).strip()
    except Exception: return "No disponible"
def direccion_ip():
    try:
        s=subprocess.check_output(["hostname","-I"],text=True).strip()
        return s.split()[0] if s else "No disponible"
    except Exception: return "No disponible"
print(json.dumps({"hostname":socket.gethostname(),"ip":direccion_ip(),"temperatura":temperatura_cpu(),"uptime":tiempo_activo()}))
PY
chmod 755 /usr/lib/cgi-bin/datos.py
cat > /var/www/html/index.html <<'HTML'
<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Raspberry Pi - Laboratorio</title>
<style>body{font-family:Arial;margin:0;background:#f3f3f3;color:#222}header{background:#222;color:white;padding:24px;text-align:center}main{max-width:760px;margin:28px auto;padding:15px}.card{background:white;border-radius:10px;padding:18px;margin:15px 0;box-shadow:0 2px 7px #0002}.valor{font-size:1.5rem;font-weight:bold}</style></head>
<body><header><h1>Raspberry Pi - Laboratorio de Redes</h1><p>Apache + Python CGI</p></header><main>
<div class="card">Servidor web: <b>Apache activo</b></div><div class="card">Servidor DHCP: <b>Kea DHCP4</b></div>
<div class="card">Equipo: <span class="valor" id="hostname">...</span></div><div class="card">IP: <span id="ip">...</span></div>
<div class="card">Temperatura CPU: <span id="temperatura">...</span></div><div class="card">Tiempo activo: <span id="uptime">...</span></div>
</main><script>
async function actualizar(){try{const r=await fetch('/cgi-bin/datos.py?ts='+Date.now(),{cache:'no-store'});const d=await r.json();hostname.textContent=d.hostname;ip.textContent=d.ip;uptime.textContent=d.uptime;temperatura.textContent=d.temperatura==null?'No disponible':Number(d.temperatura).toFixed(1)+' °C'}catch(e){hostname.textContent='Error CGI'}}
actualizar();setInterval(actualizar,5000);
</script></body></html>
HTML
systemctl restart apache2 || fail "Apache no pudo reiniciarse."
curl -fsS http://127.0.0.1/ >/dev/null || fail "Dashboard no responde."
ok "Dashboard disponible en http://$SERVER_IP"
