#!/bin/bash
set -u
IP="192.168.10.1"; WEB="/var/www/html"; CGI="/usr/lib/cgi-bin"; VENV="/opt/rpi-lab-venv"
BACKUP="/root/backup_practica04_$(date +%Y%m%d_%H%M%S)"
ok(){ echo "[OK] $*"; }; err(){ echo "[ERROR] $*" >&2; exit 1; }
[ "$EUID" -eq 0 ] || err "Ejecute: sudo ./04_led_dht11_dashboard.sh"
systemctl is-active --quiet apache2 || err "Apache no está activo."
mkdir -p "$BACKUP"; [ -f "$WEB/index.html" ] && cp -a "$WEB/index.html" "$BACKUP/index.html"
apt-get update || err "Falló apt-get update."
apt-get install -y python3 python3-pip python3-venv python3-dev build-essential swig curl || err "Falló instalación."
rm -rf "$VENV"; python3 -m venv "$VENV" || err "No se pudo crear venv."
"$VENV/bin/pip" install --upgrade pip setuptools wheel
"$VENV/bin/pip" install adafruit-circuitpython-dht gpiozero lgpio || err "No se instalaron librerías."
mkdir -p "$CGI"
cat > "$CGI/sensor.py" <<'PY'
#!/opt/rpi-lab-venv/bin/python
import json,time
print("Content-Type: application/json");print("Cache-Control: no-store");print()
try:
 import board,adafruit_dht
 dht=adafruit_dht.DHT11(board.D4,use_pulseio=False);t=h=None;msg=None
 for _ in range(4):
  try:
   t=dht.temperature;h=dht.humidity
   if t is not None and h is not None: break
  except RuntimeError as e: msg=str(e);time.sleep(.7)
 try:dht.exit()
 except Exception:pass
 print(json.dumps({"temperatura":t,"humedad":h,"error":msg}))
except Exception as e: print(json.dumps({"temperatura":None,"humedad":None,"error":str(e)}))
PY
cat > "$CGI/led.py" <<'PY'
#!/opt/rpi-lab-venv/bin/python
import json,os,urllib.parse
from pathlib import Path
print("Content-Type: application/json");print("Cache-Control: no-store");print()
STATE=Path("/tmp/rpi_lab_led");q=urllib.parse.parse_qs(os.environ.get("QUERY_STRING",""));accion=q.get("estado",["consultar"])[0].lower()
try:
 from gpiozero import LED
 from gpiozero.pins.lgpio import LGPIOFactory
 factory=LGPIOFactory();led=LED(17,pin_factory=factory);estado=STATE.read_text().strip()=="1" if STATE.exists() else False
 if accion in ("1","on","encender"):led.on();estado=True;STATE.write_text("1")
 elif accion in ("0","off","apagar"):led.off();estado=False;STATE.write_text("0")
 elif estado:led.on()
 else:led.off()
 print(json.dumps({"led":estado,"error":None}));led.close();factory.close()
except Exception as e:print(json.dumps({"led":False,"error":str(e)}))
PY
chmod 755 "$CGI/sensor.py" "$CGI/led.py"
if getent group gpio >/dev/null; then usermod -aG gpio www-data || true; fi
cat > "$WEB/index.html" <<'HTML'
<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Laboratorio IoT</title>
<style>body{font-family:Arial;background:#090d14;color:#f4f7fb;margin:0}main{max-width:900px;margin:auto;padding:28px}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:17px}.card{background:#111927;border-radius:18px;padding:23px}.value{font-size:42px;font-weight:bold}.led{width:58px;height:58px;border-radius:50%;background:#273344;margin:16px 0}.led.on{background:#58e79f;box-shadow:0 0 28px #58e79faa}button{padding:11px;border:0;border-radius:9px;margin-right:7px}@media(max-width:720px){.grid{grid-template-columns:1fr}}</style></head>
<body><main><h1>Raspberry Pi · Laboratorio IoT</h1><div class="grid">
<div class="card">TEMPERATURA<div class="value"><span id="t">--</span> °C</div></div>
<div class="card">HUMEDAD<div class="value"><span id="h">--</span> %</div></div>
<div class="card">CONTROL LED<div id="lamp" class="led"></div><button onclick="setLed(1)">ENCENDER</button><button onclick="setLed(0)">APAGAR</button><p id="ls">Estado: --</p></div>
</div><p id="msg">Consultando sensor...</p></main><script>
async function sensor(){try{let r=await fetch('/cgi-bin/sensor.py?x='+Date.now(),{cache:'no-store'});let d=await r.json();t.textContent=d.temperatura??'--';h.textContent=d.humedad??'--';msg.textContent=d.error?'DHT11: '+d.error:'Sensor funcionando.'}catch(e){msg.textContent='Error consultando DHT11.'}}
async function setLed(v){try{let r=await fetch('/cgi-bin/led.py?estado='+v+'&x='+Date.now(),{cache:'no-store'});let d=await r.json();lamp.classList.toggle('on',d.led);ls.textContent='Estado: '+(d.led?'ENCENDIDO':'APAGADO')}catch(e){}}
sensor();setInterval(sensor,5000);
</script></body></html>
HTML
a2enmod cgi >/dev/null;systemctl restart apache2 || err "No se pudo reiniciar Apache."
ok "Dashboard: http://$IP | DHT11 GPIO4 | LED GPIO17"
