# ESP32-S3 + LM35 + OLED + Dashboard

Proyecto IoT probado con ESP32-S3, sensor LM35 y OLED SH1106.

## Hardware
- ESP32-S3
- LM35: salida en GPIO4
- OLED SH1106 128x64 I2C
- SDA: GPIO8
- SCL: GPIO9

## Funcionamiento
El ESP32 mide el LM35, muestra la temperatura en la OLED y levanta un servidor HTTP en el puerto 80. El navegador consulta `/datos` y recibe JSON con temperatura, voltaje, RSSI y tiempo activo.

## Configuración
Antes de cargar el sketch sustituya `NOMBRE_DE_TU_WIFI` y `TU_CONTRASENA` localmente. No publique credenciales reales en GitHub.
