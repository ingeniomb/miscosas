#include <WiFi.h>
#include <Wire.h>
#include <U8g2lib.h>
#define LM35_PIN 4
#define SDA_PIN 8
#define SCL_PIN 9
const char* ssid = "NOMBRE_DE_TU_WIFI";
const char* password = "TU_CONTRASENA";
U8G2_SH1106_128X64_NONAME_F_HW_I2C oled(U8G2_R0, U8X8_PIN_NONE);
WiFiServer servidor(80);
float temperatura=0.0, voltaje_mV=0.0;
unsigned long tiempoAnterior=0;
const unsigned long intervaloSensor=500;
void actualizarSensor(){uint32_t suma=0;for(int i=0;i<20;i++){suma+=analogReadMilliVolts(LM35_PIN);delay(2);}voltaje_mV=suma/20.0;temperatura=voltaje_mV/10.0;}
void actualizarOLED(){char texto[25];oled.clearBuffer();oled.setFont(u8g2_font_7x13B_tf);oled.drawStr(16,13,"TEMPERATURA");oled.setFont(u8g2_font_logisoso20_tf);snprintf(texto,sizeof(texto),"%.1f C",temperatura);oled.drawStr(25,43,texto);oled.setFont(u8g2_font_6x10_tf);snprintf(texto,sizeof(texto),"LM35: %.0f mV",voltaje_mV);oled.drawStr(25,59,texto);oled.sendBuffer();}
void setup(){Serial.begin(115200);delay(1000);analogReadResolution(12);Wire.begin(SDA_PIN,SCL_PIN);oled.begin();WiFi.mode(WIFI_STA);WiFi.begin(ssid,password);while(WiFi.status()!=WL_CONNECTED){delay(500);Serial.print(".");}Serial.println();Serial.print("Direccion IP: ");Serial.println(WiFi.localIP());servidor.begin();actualizarSensor();actualizarOLED();}
void loop(){if(millis()-tiempoAnterior>=intervaloSensor){tiempoAnterior=millis();actualizarSensor();actualizarOLED();}WiFiClient cliente=servidor.accept();if(!cliente)return;String peticion=cliente.readStringUntil('\r');while(cliente.available())cliente.read();if(peticion.indexOf("GET /datos")>=0){cliente.println("HTTP/1.1 200 OK");cliente.println("Content-Type: application/json");cliente.println("Cache-Control: no-cache");cliente.println("Connection: close");cliente.println();cliente.print("{");cliente.print("\"temperatura\":");cliente.print(temperatura,1);cliente.print(",\"voltaje\":");cliente.print(voltaje_mV,0);cliente.print(",\"rssi\":");cliente.print(WiFi.RSSI());cliente.print(",\"uptime\":");cliente.print(millis()/1000);cliente.print("}");}else{cliente.println("HTTP/1.1 200 OK");cliente.println("Content-Type: text/html; charset=UTF-8");cliente.println("Connection: close");cliente.println();cliente.println(R"rawliteral(
<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ESP32-S3 IoT</title><style>body{font-family:Arial;background:#071426;color:#eaf2ff;padding:25px}main{max-width:850px;margin:auto}.card{background:#111927;padding:22px;border-radius:18px;margin:15px 0}.valor{font-size:54px;font-weight:bold}canvas{width:100%;height:260px}</style></head><body><main><h1>ESP32-S3 IoT Dashboard</h1><div class="card"><div>Temperatura actual</div><div class="valor"><span id="temp">--.-</span> °C</div></div><div class="card">LM35: <span id="voltaje">---</span> mV · Wi-Fi: <span id="rssi">---</span> dBm · Activo: <span id="uptime">---</span> s</div><div class="card"><canvas id="grafica"></canvas></div><script>
let valores=[];const c=document.getElementById("grafica"),ctx=c.getContext("2d");
function dibujar(){const w=c.clientWidth,h=c.clientHeight,dpr=devicePixelRatio||1;c.width=w*dpr;c.height=h*dpr;ctx.setTransform(dpr,0,0,dpr,0,0);ctx.clearRect(0,0,w,h);if(valores.length<2)return;let mn=Math.min(...valores)-2,mx=Math.max(...valores)+2;ctx.beginPath();valores.forEach((v,i)=>{let x=20+i*(w-40)/(valores.length-1),y=20+(mx-v)*(h-40)/(mx-mn);i?ctx.lineTo(x,y):ctx.moveTo(x,y)});ctx.strokeStyle="#00d4ff";ctx.lineWidth=3;ctx.stroke();}
async function actualizar(){try{const r=await fetch("/datos?x="+Date.now());const d=await r.json();document.getElementById("temp").textContent=Number(d.temperatura).toFixed(1);document.getElementById("voltaje").textContent=d.voltaje;document.getElementById("rssi").textContent=d.rssi;document.getElementById("uptime").textContent=d.uptime;valores.push(Number(d.temperatura));if(valores.length>60)valores.shift();dibujar();}catch(e){}}
actualizar();setInterval(actualizar,1000);addEventListener("resize",dibujar);
</script></main></body></html>)rawliteral");}delay(5);cliente.stop();}
