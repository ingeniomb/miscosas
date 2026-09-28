# Raspberry Pi · Redes e IoT

Paquete para Raspberry Pi 2 B+ / Raspberry Pi 3.

## Orden recomendado
1. `01_diagnostico_rpi.sh`: diagnóstico sin modificar configuración.
2. `02_instalar_kea_dhcp.sh`: configura Kea DHCP4.
3. `03_instalar_apache_dashboard.sh`: instala Apache, CGI Python y dashboard.
4. `04_led_dht11_dashboard.sh`: añade DHT11 y control de LED.

Red de laboratorio: Raspberry Pi `192.168.10.1/24`; pool DHCP `192.168.10.100 - 192.168.10.200`.

## Ejecución
```bash
chmod +x *.sh
./01_diagnostico_rpi.sh
sudo ./02_instalar_kea_dhcp.sh
sudo ./03_instalar_apache_dashboard.sh
sudo ./04_led_dht11_dashboard.sh
```

Los scripts están pensados para una red Ethernet aislada de laboratorio. Kea no convierte por sí solo la Raspberry Pi en router/NAT.
