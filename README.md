
![Logo UNAN-Managua](logo-unan.jpeg)
# Manual de implementación de Infraestructura Telemática

AdGuard Home, Squid, Prometheus y Grafana sobre Docker · Versión 2.1 para principiantes · 06-11-2026

**Proyecto de laboratorio:** servidor Ubuntu con Docker que filtra el DNS de una red local (AdGuard Home), intercepta y guarda en caché el tráfico web (Squid) y muestra todo en una consola central de métricas (Prometheus y Grafana) para la institución modelo `srv-colegio.lan`.

| Rol | Nombre |
| --- | --- |
| Elaborado por | Br. Junior Antonio Cortez Ramírez |
| Elaborado por | Br. Jason Alejandro Calero Sánchez |
| Elaborado por | Br. Perfecto Tadeo Castillo |
| Revisado por (Asesor / Tutor) | MSc. Yamil José Durán Sanabria |
| Lugar y fecha | Nicaragua, noviembre de 2026 |

| Versión | Fecha | Cambios |
| --- | --- | --- |
| 1.0 | — | Guía de proyecto de tesis original (anexo técnico de implementación). |
| 2.0 | 02-11-2026 | Reescrita para principiantes: teoría, diseño, pasos numerados con verificación, construcción del dashboard panel por panel, solución de problemas y correcciones a los archivos originales (ver 2.3). |
| 2.1 | 06-11-2026 | Integrantes y tutor actualizados; node-exporter con acceso a /proc y /sys del servidor anfitrión (Fase 4); nuevo Panel 9 «Tráfico de Red WAN» (Fase 12 y Anexo A) y dashboard de 9 paneles; capturas 10 y 11 señaladas en la Fase 13; mejoras de redacción. |

## Índice

- Instrucciones de uso del manual
- Equipos, herramientas y software utilizados
- 1. Objetivo y alcance
- 2. Hoja de ruta (fases, checklist y correcciones respecto a la guía original)
- 3. Teoría (DNS, proxy, Docker, Prometheus, Grafana)
- 4. Diseño (topología, puertos, carpetas)
- 5. Implementación (Fases 0 a 14)
- 6. Evidencias y verificación integral
- Anexo A. Dashboard: referencia de los 9 paneles y consultas PromQL
- Anexo B. Solución de problemas
- Anexo C. Comandos útiles
- Anexo D. Glosario
- Bibliografía

## Instrucciones de uso del manual

Este manual sirve para dos cosas: **reproducir el laboratorio desde cero** sin conocimientos previos de Docker, y **entender qué hace cada pieza** para poder defender el proyecto. Está pensado para estudiantes de Ingeniería en Sistemas, Computación o Telemática que ya manejan lo básico de redes.

**Orden de lectura recomendado**

| Si quieres… | Lee |
| --- | --- |
| Entender qué es cada herramienta | 3. Teoría |
| Ver cómo está armada la red y los puertos | 4. Diseño |
| Construir el laboratorio paso a paso | 5. Implementación, Fase 0 a Fase 14, en orden |
| Construir el dashboard de Grafana desde cero | Fase 11 (importar) o Fase 12 (construir) |
| Entender qué mide cada panel | Anexo A |
| Resolver un error | Anexo B |
| Comprobar que todo quedó bien | 6. Evidencias y verificación integral |

**Cómo trabajar con el manual**

1. Avanza **una fase a la vez** y no pases a la siguiente hasta que su verificación esté en ✔.
2. Escribe los comandos tal cual aparecen. Si algo falla, lo más probable es un error de escritura, de sangría (espacios) en un archivo YAML o un archivo que falta.
3. Compara siempre tu resultado con la **salida esperada** que se muestra después de cada verificación.
4. Ante un error, ve al Anexo B antes de repetir pasos al azar.

**Convenciones**

| Elemento | Significado |
| --- | --- |
| `texto en código` | Comando, nombre de archivo o valor que se escribe tal cual |
| `<IP_SERVIDOR>` | Valor que cambia según tu red, por ejemplo `192.168.1.58` |
| Bloques grises | Comandos (se escriben en la terminal) o contenido de archivos (se pegan en `nano`) |
| ✔ / ✘ | Verificación correcta / incorrecta |
| Menú > Opción | Ruta en una interfaz web (por ejemplo, Dashboards > New > Import) |
| \[Captura N\] | Lugar donde debes pegar una captura de pantalla como evidencia |

**Requisitos previos:** saber abrir una terminal en Linux, usar `cd`, `ls` y `nano`; conocer qué es una dirección IP, una máscara y un puerto; tener acceso a Internet en el servidor.

**Advertencias**

- Las credenciales de este manual (`jr-admin` / `linux1234`) son **solo de laboratorio**. En un entorno real se usan contraseñas robustas.
- Varios comandos usan `sudo`. Léelos antes de ejecutarlos: puedes cambiar la red del servidor y detener servicios.
- Si trabajas en una red de la institución, pide autorización antes de interceptar tráfico o cambiar el DNS de otros equipos.

## Equipos, herramientas y software utilizados

**Servidor del laboratorio (mínimos)**

| Componente | Especificación mínima | Para qué sirve |
| --- | --- | --- |
| Procesador (CPU) | 2 núcleos | Procesar reglas de filtrado y métricas al mismo tiempo |
| Memoria RAM | 4 GB | Squid guarda páginas frecuentes en RAM (caché activa) y Prometheus y Grafana necesitan memoria |
| Disco duro | 25 GB | Evita que los registros (logs) y la caché llenen el disco y detengan el sistema |
| Adaptador de red | Modo puente (Bridged) si es máquina virtual | La VM obtiene una IP de la red local real y los clientes pueden alcanzarla |

**Software**

| Software | Uso en el proyecto |
| --- | --- |
| Ubuntu (Desktop o Server, versión LTS reciente) | Sistema operativo del servidor |
| Docker Engine y Docker Compose (v2, comando `docker compose`) | Ejecutar todos los servicios como contenedores |
| `adguard/adguardhome` | Servidor DNS con filtrado y panel web |
| `b4tman/squid` | Proxy caché HTTP |
| `prom/prometheus` | Base de datos de métricas |
| `grafana/grafana` | Paneles gráficos |
| `ebrianne/adguard-exporter`, `boynux/squid-exporter`, `prom/node-exporter` | Convierten las métricas de AdGuard, Squid y del servidor al formato de Prometheus |
| Cliente Windows | Equipo de prueba: cambiar DNS, `ping`, `nslookup`, navegador |
| `nano`, `curl`, navegador web | Editar archivos, probar servicios, abrir los paneles |

## 1. Objetivo y alcance

### 1.1 Objetivo general

Implementar una infraestructura telemática contenerizada que filtre el DNS, controle y cachee el tráfico web de una red local y muestre su estado en tiempo real en una consola central de telemetría.

### 1.2 Objetivos específicos

1. Instalar Docker y preparar la estructura de carpetas del laboratorio.
2. Desplegar AdGuard Home como servidor DNS con listas de bloqueo, servicios bloqueados y un dominio local (`srv-colegio.lan`).
3. Desplegar Squid como proxy caché, en modo explícito (puerto 3128) y transparente (puerto 3129).
4. Desplegar Prometheus, tres exportadores (AdGuard, Squid, servidor) y Grafana.
5. Construir el dashboard **Consola Central de Telemetría** con 9 paneles.
6. Validar el funcionamiento con pruebas desde un cliente Windows y capturas de evidencia.

### 1.3 Alcance y límites

- Solo se intercepta tráfico **HTTP (puerto 80)**. El tráfico **HTTPS (443)** no se descifra: pasa como túnel. Por eso la caché de Squid casi no tiene aciertos con sitios modernos (ver Fase 13).
- La intercepción transparente solo funciona si el tráfico del cliente **pasa por el servidor** (el servidor es su puerta de enlace). Si no, se usa el proxy explícito (ver Fase 12).
- Es un laboratorio: no incluye alta disponibilidad, certificados propios ni autenticación de usuarios del proxy.

## 2. Hoja de ruta

### 2.1 Fases del proyecto

| Fase | Nombre | Resultado esperado |
| --- | --- | --- |
| 0 | Preparar el servidor | Ubuntu actualizado, IP conocida |
| 1 | Instalar Docker | `docker --version` y `docker compose version` responden |
| 2 | Crear carpetas | Estructura `laboratorio-tesis` lista |
| 3 | Configurar AdGuard (YAML) | `AdGuardHome.yaml` creado |
| 4 | Crear `docker-compose.yml` | Archivo de orquestación listo |
| 5 | Crear `squid.conf` | Proxy configurado |
| 6 | Crear `prometheus.yml` | Prometheus sabe qué servicios medir |
| 7 | Crear los scripts | `auto_update_ip.sh`, `02_iniciar_lab.sh`, `03_firewall.sh` |
| 8 | Iniciar el laboratorio | 7 contenedores en estado Up |
| 9 | Verificar Prometheus | Los 4 targets en UP |
| 10 | Resolución DNS en el cliente | `ping srv-colegio.lan` responde |
| 11 | Grafana: fuente de datos e importación del dashboard | Dashboard con datos |
| 12 | Grafana: construir el dashboard desde cero | Los 9 paneles creados a mano |
| 13 | Probar tráfico y generar métricas | Los paneles se mueven |
| 14 | Intercepción transparente (firewall) | Tráfico HTTP redirigido a Squid |

### 2.2 Checklist de avance

- [ ] Fase 0 a 2 completas
- [ ] Archivos de las fases 3 a 7 creados
- [ ] Contenedores en Up (Fase 8)
- [ ] Targets de Prometheus en UP (Fase 9)
- [ ] Ping a `srv-colegio.lan` correcto (Fase 10)
- [ ] Dashboard con datos (Fase 11 o 12)
- [ ] Pruebas de tráfico hechas (Fase 13)
- [ ] Intercepción probada (Fase 14, opcional)

### 2.3 Correcciones respecto a la guía original

Al revisar la guía y el archivo JSON del dashboard se encontraron puntos que podían hacer fallar el laboratorio a un principiante. Esta versión los corrige y los explica donde aparecen:

| # | Problema en la guía original | Corrección en este manual |
| --- | --- | --- |
| 1 | `chmod 777` sobre el script de instalación | Se usa `chmod +x` (basta con dar permiso de ejecución) |
| 2 | `version: '3.8` con comilla sin cerrar en el compose | Se elimina la línea `version`, que ya no se usa en Compose v2 |
| 3 | Falta el `#` en `#!/bin/bash` de `auto_update_ip.sh` | Corregido; el script ahora detecta la IP con `ip route` y se detiene antes de editar el YAML |
| 4 | `03_firewall.sh` ejecuta `iptables -t nat -F PREROUTING`, que borra también las reglas que Docker necesita | El script agrega reglas solo si no existen y no vacía la tabla |
| 5 | Se dice que se interceptan HTTP y HTTPS, pero solo se redirige el puerto 80 | Se aclara en 1.3 y en la Fase 14 |
| 6 | La intercepción transparente requiere que el servidor sea la puerta de enlace del cliente; no se mencionaba | Se explica en la Fase 14 y se ofrece el proxy explícito como alternativa |
| 7 | La sección 5 pide crear el usuario en el asistente web, pero el YAML ya lo trae | Se aclara: con el YAML cargado no aparece asistente (Fase 3) |
| 8 | El datasource usaba `srv-colegio.lan:9090`; dentro de Docker ese nombre puede no resolverse | Se usa `http://prometheus:9090` (nombre del servicio) |
| 9 | El JSON apunta a un datasource con identificador fijo (`efzh5rtmm718ga`) que no existe en otro Grafana | Se explican dos formas de resolverlo (Fase 11) |
| 10 | El JSON incluye una variable vacía `query0` que ensucia el dashboard | Se indica cómo eliminarla |
| 11 | Los paneles «Tasa de Aciertos» y «Byte Hit Ratio» usan exactamente la misma consulta, y esa consulta mide aciertos por **petición**, no por **byte** | Se explica y se propone una consulta alternativa para bytes (Anexo A) |
| 12 | El panel «Estado de Servicios» muestra siempre color verde aunque el valor sea 0 | Se añade una mejora opcional con colores por valor (Fase 12) |
| 13 | El contenedor de node-exporter no tenía acceso a /proc y /sys del servidor anfitrión | Se montan en solo lectura y se indican con --path.procfs y --path.sysfs (Fase 4); se añade el Panel 9 de tráfico de red (Fase 12) |

## 3. Teoría

### 3.1 Infraestructura telemática y monitoreo

Una infraestructura telemática combina redes y servicios (DNS, proxy, firewall) para que los usuarios accedan a información de forma controlada. **Monitorear** es medir continuamente esos servicios (¿están activos? ¿cuántas consultas atienden? ¿cuánto bloquean?) y mostrarlo de forma visual para detectar problemas y justificar decisiones.

### 3.2 Docker y Docker Compose

- **Imagen:** el «molde» de un programa ya instalado y configurado (por ejemplo, `grafana/grafana`).
- **Contenedor:** una imagen en ejecución. Es ligero y aislado, y se puede borrar y recrear sin ensuciar el sistema.
- **Volumen / carpeta montada:** carpeta del servidor conectada a una carpeta dentro del contenedor. Sirve para que los datos y configuraciones no se pierdan al recrear el contenedor. En el compose, `./squid.conf:/etc/squid/squid.conf` significa «el archivo `squid.conf` de mi carpeta aparece como `/etc/squid/squid.conf` dentro del contenedor».
- **Puerto publicado:** `3001:80` significa «el puerto 3001 del servidor lleva al puerto 80 del contenedor».
- **Docker Compose:** un archivo (`docker-compose.yml`) que describe todos los contenedores y se levanta con un solo comando: `docker compose up -d`.
- **Red de Compose:** los contenedores del mismo compose se ven entre sí **por el nombre del servicio o del contenedor** (por ejemplo, Prometheus llega a `squid_exporter:9301`). Fuera de Docker (desde otro PC) se usa la IP del servidor y el puerto publicado.

### 3.3 DNS y AdGuard Home

El **DNS** traduce nombres (`google.com`) a direcciones IP. **AdGuard Home** actúa como servidor DNS de la red: recibe las consultas de los clientes y

1. si el dominio está en una lista de bloqueo, un servicio bloqueado o una regla personalizada, **no lo resuelve** (lo bloquea);
2. si hay una **reescritura DNS** (como `srv-colegio.lan` → IP del servidor), responde con esa IP;
3. si no, pregunta a un DNS externo (en este laboratorio, Quad9 por HTTPS cifrado) y guarda la respuesta en caché.

En el YAML de este laboratorio se activan listas contra anuncios, malware, phishing, piratería y apuestas, se bloquean servicios completos (redes sociales, streaming, videojuegos, etc.) y se activa la búsqueda segura (*Safe Search*).

### 3.4 Proxy Squid y caché

Un **proxy** es un intermediario: el cliente pide una página al proxy y este la pide a Internet.

| Modo | Puerto | Cómo funciona |
| --- | --- | --- |
| Explícito | 3128 | El navegador del cliente está configurado para usar el proxy |
| Transparente (`intercept`) | 3129 | El cliente no sabe que existe; el firewall del servidor le redirige el tráfico del puerto 80 |

Squid puede **guardar copias** de objetos en RAM (`cache_mem`) y en disco (`cache_dir`) y servirlas sin volver a Internet. Una petición atendida desde la copia se llama **acierto de caché (hit)**. El control de quién puede navegar se hace con **ACL** y reglas `http_access`, que se evalúan **de arriba hacia abajo** y se detienen en la primera que coincide.

**Limitación importante:** en HTTPS el contenido va cifrado. Squid solo ve un «túnel» (`CONNECT`) y no puede guardar su contenido sin técnicas adicionales (*SSL Bump*), que este laboratorio no usa.

### 3.5 Redirección con iptables (DNAT y NAT)

`iptables` es el firewall de Linux. En este proyecto se usan tres ideas:

- **DNAT en PREROUTING:** cambia el destino de un paquete que llega al servidor (por ejemplo, «todo lo que vaya al puerto 80 envíalo al puerto 3129 de Squid»).
- **MASQUERADE en POSTROUTING:** hace que los paquetes reenviados salgan con la IP del servidor (NAT).
- **`ip_forward=1`:** permite que el servidor reenvíe paquetes de una red a otra.

La clave: PREROUTING solo ve paquetes que **llegan al servidor**. Si el cliente tiene como puerta de enlace otro router, su tráfico nunca pasa por estas reglas.

### 3.6 Prometheus, exportadores y PromQL

- **Métrica:** un número que cambia en el tiempo (por ejemplo, `squid_client_http_requests_total`).
- **Exportador:** programa que lee las estadísticas de un servicio y las publica como métricas en una página `/metrics`. AdGuard y Squid no hablan «Prometheus» por sí solos, por eso existen `adguard_exporter` y `squid_exporter`.
- **Prometheus:** cada 15 segundos visita (*scrape*) cada exportador y guarda los números con su hora. Cada servicio visitado es un **target** y cada grupo de targets un **job**.
- **Métrica `up`:** Prometheus la crea sola para cada target: vale **1** si pudo leerlo y **0** si no.
- **Contador (*counter*):** número que solo sube (peticiones totales). Se analiza con `rate()` (por segundo) o `increase()` (cuánto subió en un intervalo).
- **PromQL:** lenguaje de consultas de Prometheus. Ejemplos de este proyecto: `up`, `sum(...)`, `rate(...[5m])`, `increase(...[5m])`.

### 3.7 Grafana

**Grafana** dibuja los datos. Sus piezas son: **Data source** (de dónde salen los datos, aquí Prometheus), **Dashboard** (el tablero) y **Panel** (cada recuadro con una consulta y un tipo de visualización: *Stat* para un número grande, *Gauge* para un medidor). Un dashboard completo se puede guardar y compartir como archivo **JSON**; importar ese JSON recrea todos los paneles de una vez.

## 4. Diseño

### 4.1 Topología lógica

```
  Cliente Windows ──DNS (53)────────────► AdGuard Home ──DoH──► Quad9 (Internet)
        │
        ├──HTTP por proxy explícito (3128)──┐
        └──HTTP interceptado (80→3129)──────┴► Squid ───────────► Internet

  Servidor Ubuntu (Docker): adguard_dns · squid_proxy · prometheus_db · grafana_dashboard
                            adguard_exporter · squid_exporter · node_exporter

  Prometheus ──cada 15 s──► adguard_exporter:9617 · squid_exporter:9301 · node_exporter:9100
  Grafana ──PromQL──► Prometheus:9090        Navegador ──► Grafana:3000
```

### 4.2 Servicios y puertos

| Contenedor | Puerto en el servidor | Protocolo | Función |
| --- | --- | --- | --- |
| `adguard_dns` | 53 | TCP y UDP | Servidor DNS |
| `adguard_dns` | 3001 (lleva al 80 interno) | TCP | Panel web de AdGuard |
| `squid_proxy` | 3128 | TCP | Proxy explícito |
| `squid_proxy` | 3129 | TCP | Proxy transparente (`intercept`) |
| `prometheus_db` | 9090 | TCP | Base de datos de métricas y su interfaz |
| `grafana_dashboard` | 3000 | TCP | Paneles gráficos |
| `adguard_exporter` | 9617 | TCP | Métricas de AdGuard |
| `squid_exporter` | 9301 | TCP | Métricas de Squid |
| `node_exporter` | 9100 | TCP | Métricas del servidor (CPU, RAM, disco, red) |

### 4.3 Estructura de carpetas

```
laboratorio-tesis/
├── adguard_conf/
│   └── AdGuardHome.yaml
├── adguard_work/
├── squid_cache/
├── docker-compose.yml
├── squid.conf
├── prometheus.yml
├── 01_instalar_docker.sh
├── 02_iniciar_lab.sh
├── 03_firewall.sh
└── auto_update_ip.sh
```

### 4.4 Flujo de datos de la telemetría

1. El cliente usa AdGuard y Squid y genera estadísticas dentro de ellos.
2. Cada exportador lee esas estadísticas y las expone en `/metrics`.
3. Prometheus las recolecta cada 15 s y las almacena.
4. Grafana consulta a Prometheus con PromQL y dibuja los paneles.

Si un panel sale vacío (*No data*), el fallo está en uno de estos cuatro eslabones. El Anexo B enseña a revisarlos en orden.

## 5. Implementación

Todos los comandos de esta sección se ejecutan en la **terminal del servidor Ubuntu**. Cada fase tiene: objetivo, pasos numerados, una tabla que explica los comandos y una verificación. **No avances si la verificación falla.**

**Mini guía de `nano` (editor de texto de la terminal):** `nano archivo` abre o crea el archivo; pega el contenido con clic derecho o `Ctrl+Shift+V`; guarda con `Ctrl+O` y `Enter`; sal con `Ctrl+X`.

### Fase 0: Preparar el servidor

**Objetivo:** tener Ubuntu al día, conocer la IP del servidor y comprobar que hay Internet.

**Paso 0.1. Actualizar el sistema**

```bash
sudo apt update && sudo apt upgrade -y
```

| Comando | Función |
| --- | --- |
| `sudo` | Ejecuta el comando con permisos de administrador |
| `apt update` | Actualiza la lista de paquetes disponibles |
| `apt upgrade -y` | Instala las actualizaciones (`-y` responde "sí" automáticamente) |

**Paso 0.2. Anotar la IP del servidor**

```bash
ip a
hostname -I
ip route get 8.8.8.8
```

Busca la IP de tu red local (por ejemplo `192.168.1.58`). En el resultado de `ip route get 8.8.8.8` aparece después de la palabra `src`. En este manual la llamamos `<IP_SERVIDOR>`.

**Paso 0.3. Probar Internet**

```bash
ping -c 3 google.com
```

✔ **Verificación:** aparecen 3 respuestas y `0% packet loss`. ✘ Si falla, revisa el cable o, en una máquina virtual, que el adaptador esté en **modo puente (Bridged)**.

&#91;Captura 1: salida de `ip a` con la IP del servidor\]

### Fase 1: Instalar Docker

**Objetivo:** dejar instalados Docker y Docker Compose.

**Paso 1.1. Crear el script de instalación**

```bash
nano 01_instalar_docker.sh
```

Pega este contenido, guarda y sal:

```bash
#!/bin/bash
echo "🚀 Actualizando el sistema operativo..."
sudo apt update && sudo apt upgrade -y

echo "🐳 Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo "🔑 Asignando permisos a tu usuario..."
sudo usermod -aG docker $USER
rm get-docker.sh

echo "✅ ¡Instalación base completada!"
```

**Paso 1.2. Darle permiso de ejecución y ejecutarlo**

```bash
chmod +x 01_instalar_docker.sh
sudo ./01_instalar_docker.sh
```

**Paso 1.3. Activar el grupo `docker` sin reiniciar**

```bash
newgrp docker
```

| Comando | Función |
| --- | --- |
| `chmod +x archivo` | Marca el archivo como ejecutable. (La guía original usaba `chmod 777`, que da permisos a todo el mundo y no hace falta) |
| `curl -fsSL ... -o get-docker.sh` | Descarga el instalador oficial de Docker |
| `usermod -aG docker $USER` | Añade tu usuario al grupo `docker` para usar Docker sin `sudo` |
| `newgrp docker` | Aplica el nuevo grupo en la terminal actual |

✔ **Verificación:**

```bash
docker --version
docker compose version
docker run --rm hello-world
```

Deben mostrarse las versiones y el mensaje `Hello from Docker!`. ✘ Si dice `permission denied`, cierra sesión y vuelve a entrar, o ejecuta de nuevo `newgrp docker`.

&#91;Captura 2: `docker --version` y `docker compose version`\]

### Fase 2: Crear la estructura de carpetas

**Objetivo:** crear la carpeta del proyecto y las subcarpetas que usarán los contenedores.

```bash
mkdir laboratorio-tesis
cd laboratorio-tesis
mkdir adguard_conf adguard_work squid_cache
chmod 777 squid_cache
```

| Comando | Función |
| --- | --- |
| `mkdir` | Crea carpetas |
| `cd` | Entra a una carpeta |
| `adguard_conf` | Aquí vivirá la configuración de AdGuard (`AdGuardHome.yaml`) |
| `adguard_work` | Datos de trabajo de AdGuard (registros, estadísticas) |
| `squid_cache` | Donde Squid guarda su caché en disco |
| `chmod 777 squid_cache` | Permite que el usuario interno de Squid escriba en la carpeta. **Solo para laboratorio**; sin este permiso Squid no puede crear su caché |

✔ **Verificación:** `ls -l` muestra las tres carpetas y `squid_cache` aparece como `drwxrwxrwx`.

> A partir de aquí, **todos los archivos se crean dentro de `laboratorio-tesis`**. Si abres una terminal nueva, entra de nuevo con `cd laboratorio-tesis`.

### Fase 3: Configurar AdGuard Home (archivo YAML)

**Objetivo:** dejar listo el archivo `AdGuardHome.yaml` para que AdGuard arranque ya configurado (usuario, listas de bloqueo, servicios bloqueados, DNS externo cifrado y dominio local).

**Por qué se hace así:** AdGuard, la primera vez, abre un asistente de instalación en su puerto 3000 interno. En este laboratorio ese puerto no está publicado (el panel se publica en el 3001 → 80). Si el archivo YAML ya existe, AdGuard lo lee, **se salta el asistente** y arranca directamente con el usuario `jr-admin`.

**Paso 3.1. Crear el archivo**

```bash
nano adguard_conf/AdGuardHome.yaml
```

**Paso 3.2. Pegar el contenido completo.** Cuida la **sangría** (los espacios al inicio de cada línea): en YAML la sangría es parte de la sintaxis. Usa **espacios, nunca tabulaciones**.

```yaml
http:
  pprof:
    port: 6060
    enabled: false
  doh:
    routes:
      - GET /dns-query
      - POST /dns-query
      - GET /dns-query/{ClientID}
      - POST /dns-query/{ClientID}
    insecure_enabled: false
  address: 0.0.0.0:80
  session_ttl: 30d
users:
  - name: jr-admin
    password: $2a$10$fpsgiGgHFEXECXg7c331u.S1CNL4jSFfVpJAkZ79N15Dkw8Ag5U0i
auth_attempts: 5
block_auth_min: 15
http_proxy: ""
language: es
theme: auto
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  anonymize_client_ip: false
  ratelimit: 20
  ratelimit_subnet_len_ipv4: 24
  ratelimit_subnet_len_ipv6: 56
  ratelimit_whitelist: []
  refuse_any: true
  upstream_dns:
    - https://dns10.quad9.net/dns-query
  upstream_dns_file: ""
  bootstrap_dns:
    - 9.9.9.10
    - 149.112.112.10
    - 2620:fe::10
    - 2620:fe::fe:10
  fallback_dns: []
  upstream_mode: load_balance
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts:
    - version.bind
    - id.server
    - hostname.bind
  trusted_proxies:
    - 127.0.0.0/8
    - ::1/128
  cache_enabled: true
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: false
  cache_optimistic_answer_ttl: 30s
  cache_optimistic_max_age: 12h
  bogus_nxdomain: []
  aaaa_disabled: false
  enable_dnssec: true
  edns_client_subnet:
    custom_ip: ""
    enabled: false
    use_custom: false
  max_goroutines: 300
  handle_ddr: true
  ipset: []
  ipset_file: ""
  bootstrap_prefer_ipv6: false
  upstream_timeout: 10s
  private_networks: []
  use_private_ptr_resolvers: false
  local_ptr_upstreams: []
  use_dns64: false
  dns64_prefixes: []
  serve_http3: false
  use_http3_upstreams: false
  serve_plain_dns: true
  hostsfile_enabled: true
  pending_requests:
    enabled: true
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  port_dns_over_quic: 853
  port_dnscrypt: 0
  dnscrypt_config_file: ""
  certificate_chain: ""
  private_key: ""
  certificate_path: ""
  private_key_path: ""
  strict_sni_check: false
querylog:
  dir_path: ""
  ignored: []
  interval: 90d
  size_memory: 1000
  enabled: true
  file_enabled: true
  ignored_enabled: false
statistics:
  dir_path: ""
  ignored: []
  interval: 1d
  enabled: true
  ignored_enabled: false
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: false
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
    name: AdAway Default Blocklist
    id: 2
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_27.txt
    name: OISD Blocklist Big
    id: 1792462318
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_33.txt
    name: Steven Black's List
    id: 1792462319
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt
    name: Malicious URL Blocklist (URLHaus)
    id: 1792462320
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_46.txt
    name: HaGeZi's Anti-Piracy Blocklist
    id: 1792462321
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_47.txt
    name: HaGeZi's Gambling Blocklist
    id: 1792462322
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_30.txt
    name: Phishing URL Blocklist (PhishTank and OpenPhish)
    id: 1792462323
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_12.txt
    name: Dandelion Sprout's Anti-Malware List
    id: 1792462324
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_52.txt
    name: HaGeZi's Encrypted DNS/VPN/TOR/Proxy Bypass
    id: 1792462325
whitelist_filters: []
user_rules:
  - '||*cuevana*^'
  - '||*pelisplus*^'
  - '||*animeflv*^'
  - '||*repelis*^'
  - '||*zoro.to*^'
  - '||*torrent*^'
  - '||*piratebay*^'
  - '||*1337x*^'
  - '||*fitgirl*^'
dhcp:
  enabled: false
  interface_name: ""
  local_domain_name: lan
  dhcpv4:
    gateway_ip: ""
    subnet_mask: ""
    range_start: ""
    range_end: ""
    lease_duration: 86400
    icmp_timeout_msec: 1000
    options: []
  dhcpv6:
    range_start: ""
    lease_duration: 86400
    ra_slaac_only: false
    ra_allow_slaac: false
filtering:
  blocking_ipv4: ""
  blocking_ipv6: ""
  blocked_services:
    schedule:
      time_zone: UTC
    ids:
      - 4chan
      - 500px
      - 9gag
      - activision_blizzard
      - aliexpress
      - amazon
      - amazon_streaming
      - amino
      - apple_streaming
      - battle_net
      - betano
      - betfair
      - betway
      - bigo_live
      - bilibili
      - blaze
      - blizzard_entertainment
      - bluesky
      - canais_globo
      - claro
      - clubhouse
      - coolapk
      - crunchyroll
      - dailymotion
      - deezer
      - directvgo
      - discord
      - discoveryplus
      - disneyplus
      - douban
      - ebay
      - electronic_arts
      - epic_games
      - espn
      - facebook
      - fdj_united
      - fifa
      - globoplay
      - gog
      - grindr
      - hbomax
      - hulu
      - iheartradio
      - instagram
      - io_interactive
      - iqiyi
      - kook
      - lazada
      - leagueoflegends
      - line
      - linkedin
      - lionsgateplus
      - looke
      - mail_ru
      - mastodon
      - mercado_libre
      - minecraft
      - nebula
      - netflix
      - nintendo
      - nvidia
      - odysee
      - ok
      - onlyfans
      - origin
      - paramountplus
      - peacock_tv
      - pinterest
      - playstation
      - playstore
      - plenty_of_fish
      - plex
      - pluto_tv
      - qq
      - rakuten_viki
      - reddit
      - riot_games
      - roblox
      - rockstar_games
      - samsung_tv_plus
      - shein
      - shell_shockers
      - shopee
      - snapchat
      - soundcloud
      - spotify
      - spotify_video
      - steam
      - temu
      - tidal
      - tiktok
      - tinder
      - tumblr
      - twitch
      - twitter
      - ubisoft
      - valorant
      - vimeo
      - vivo_play
      - vk
      - voot
      - wargaming
      - warnerbrosgames
      - weibo
      - wizz
      - xboxlive
      - xiaohongshu
      - youtube
      - yy
      - zhihu
  protection_disabled_until: null
  safe_search:
    enabled: true
    bing: true
    duckduckgo: true
    ecosia: true
    google: true
    pixabay: true
    yandex: true
    youtube: true
  blocking_mode: default
  parental_block_host: family-block.dns.adguard.com
  safebrowsing_block_host: standard-block.dns.adguard.com
  rewrites:
    - domain: srv-colegio.lan
      answer: 192.168.1.63
      enabled: true
  safe_fs_patterns:
    - /opt/adguardhome/work/userfilters/*
  max_http_size: 256MB
  safebrowsing_cache_size: 1048576
  safesearch_cache_size: 1048576
  parental_cache_size: 1048576
  cache_time: 30
  filters_update_interval: 24
  blocked_response_ttl: 10
  filtering_enabled: true
  rewrites_enabled: true
  parental_enabled: true
  safebrowsing_enabled: false
  protection_enabled: true
clients:
  runtime_sources:
    whois: true
    arp: true
    rdns: true
    dhcp: true
    hosts: true
  persistent: []
log:
  enabled: true
  file: ""
  max_backups: 0
  max_size: 100
  max_age: 3
  compress: false
  local_time: false
  verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 34
```

**Qué contiene cada bloque (para que puedas explicarlo en la defensa)**

| Bloque | Qué hace en el laboratorio |
| --- | --- |
| `http` | El panel web escucha en el puerto 80 del contenedor (publicado como 3001 en el servidor) |
| `users` | Crea el usuario administrador `jr-admin`. La contraseña está guardada como *hash* (bcrypt), no en texto plano |
| `dns` | El servidor DNS escucha en el puerto 53, limita a 20 consultas por segundo por subred `/24`, activa DNSSEC y consulta a Quad9 por HTTPS cifrado (`upstream_dns`). `bootstrap_dns` solo sirve para encontrar la IP de Quad9 al arrancar |
| `querylog` y `statistics` | Guardan el historial de consultas (90 días) y las estadísticas (ventana de 1 día). De estas estadísticas leen los números que muestra Grafana |
| `filters` | Listas de bloqueo: anuncios, malware, phishing, piratería, apuestas y evasión (VPN, TOR, proxies) |
| `user_rules` | Reglas propias: bloquean cualquier dominio que contenga `cuevana`, `torrent`, `piratebay`, etc. |
| `filtering.blocked_services` | Bloquea servicios completos (redes sociales, streaming, videojuegos, tiendas) |
| `filtering.safe_search` | Obliga a los buscadores a usar la búsqueda segura |
| `filtering.rewrites` | Reescritura DNS: `srv-colegio.lan` responde con la IP del servidor |

**Paso 3.3. Corregir la IP de la reescritura (opcional ahora).** La línea `answer: 192.168.1.63` es la IP del servidor del autor. El script `auto_update_ip.sh` (Fase 7) la reemplaza automáticamente por la tuya cada vez que inicies el laboratorio, así que no es obligatorio cambiarla a mano.

**Sobre el usuario y la contraseña.** El hash del archivo corresponde a las credenciales del laboratorio (`jr-admin` / `linux1234`), y esas mismas credenciales están en el `docker-compose.yml` para el exportador de AdGuard. Si usas otro usuario o contraseña, el exportador no podrá leer las estadísticas y los paneles de DNS saldrán en blanco. Si no puedes iniciar sesión, genera un hash nuevo:

```bash
sudo apt install -y apache2-utils
htpasswd -nbB jr-admin linux1234
```

Copia lo que aparece después de `jr-admin:` (empieza con `$2y$`), cambia ese `$2y$` por `$2a$` y reemplaza la línea `password:` del YAML.

✔ **Verificación:** `head -20 adguard_conf/AdGuardHome.yaml` muestra las primeras líneas con su sangría (`http:` pegado al margen y `pprof:` con 2 espacios).

### Fase 4: Crear el archivo de orquestación (`docker-compose.yml`)

**Objetivo:** describir los 7 contenedores para levantarlos juntos.

```bash
nano docker-compose.yml
```

```yaml
services:
  adguard:
    image: adguard/adguardhome
    container_name: adguard_dns
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "3001:80/tcp"
    volumes:
      - ./adguard_work:/opt/adguardhome/work
      - ./adguard_conf:/opt/adguardhome/conf
    restart: unless-stopped

  squid:
    image: b4tman/squid
    container_name: squid_proxy
    ports:
      - "3128:3128"
      - "3129:3129"
    volumes:
      - ./squid.conf:/etc/squid/squid.conf
      - ./squid_cache:/var/spool/squid
    dns:
      - 8.8.8.8
    restart: unless-stopped

  prometheus:
    image: prom/prometheus
    container_name: prometheus_db
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    restart: unless-stopped

  grafana:
    image: grafana/grafana
    container_name: grafana_dashboard
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped

  adguard-exporter:
    image: ebrianne/adguard-exporter:latest
    container_name: adguard_exporter
    restart: unless-stopped
    environment:
      - 'ADGUARD_PROTOCOL=http'
      - 'ADGUARD_HOSTNAME=adguard_dns'
      - 'ADGUARD_PORT=80'
      - 'ADGUARD_USERNAME=jr-admin'
      - 'ADGUARD_PASSWORD=linux1234'
      - 'SERVER_PORT=9617'
    ports:
      - "9617:9617"

  squid-exporter:
    image: boynux/squid-exporter:latest
    container_name: squid_exporter
    restart: unless-stopped
    environment:
      - SQUID_HOSTNAME=squid_proxy
      - SQUID_PORT=3128
    ports:
      - "9301:9301"

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
    restart: unless-stopped

volumes:
  grafana_data:
```

**Cómo leer este archivo**

| Elemento | Qué significa |
| --- | --- |
| `services:` | Lista de contenedores. Cada nombre (`adguard`, `squid`…) es un servicio |
| `image:` | Imagen que se descarga de Docker Hub |
| `container_name:` | Nombre fijo del contenedor. Los demás contenedores lo usan como dirección (por ejemplo, `adguard_dns`) |
| `ports: "3001:80"` | Puerto del servidor : puerto del contenedor |
| `volumes:` | Archivos o carpetas del servidor que el contenedor puede ver. `grafana_data` es un volumen administrado por Docker donde Grafana guarda sus dashboards |
| `dns: 8.8.8.8` | Squid usa el DNS de Google para resolver sitios web (así no depende de AdGuard) |
| `restart: unless-stopped` | Si el contenedor se cae o el servidor se reinicia, Docker lo levanta de nuevo |
| `environment:` | Variables de configuración. El exportador de AdGuard necesita el usuario y la contraseña del panel |

**Sobre `node-exporter`:** monta `/proc` y `/sys` del servidor en modo solo lectura (`:ro`) y, con `--path.procfs` y `--path.sysfs`, le indica que lea las estadísticas del sistema desde esas rutas. Con esto obtiene las métricas del anfitrión (CPU, memoria, disco y contadores de red) que usa el Panel 9. Qué interfaces de red aparecen se comprueba en la Fase 9.

✔ **Verificación de sintaxis** (aún sin iniciar nada):

```bash
docker compose config -q
```

Si no imprime nada, el archivo es válido. Si muestra un error, revisa la línea indicada (casi siempre es la sangría).

### Fase 5: Configurar el proxy Squid (`squid.conf`)

**Objetivo:** definir los puertos del proxy, el tamaño de la caché y quién puede navegar.

> **Importante:** `squid.conf` y `prometheus.yml` deben existir **antes** de `docker compose up`. Si no existen, Docker crea una *carpeta* con ese nombre y el contenedor falla.

```bash
nano squid.conf
```

```
# --- RESOLUCIÓN DNS INTERNA ---
dns_v4_first on
#dns_nameservers 1.1.1.1 8.8.8.8

# --- PUERTOS DE ESCUCHA DEL PROXY ---
http_port 3128
http_port 3129 intercept

# --- LIMITACIONES DE MEMORIA Y CACHÉ ---
cache_mem 256 MB
maximum_object_size_in_memory 4 MB
cache_dir ufs /var/spool/squid 2048 16 256
maximum_object_size 100 MB
cache_replacement_policy lru

# --- DEFINICIÓN DE PUERTOS Y ACLS ---
acl SSL_ports port 443
acl Safe_ports port 80    # http
acl Safe_ports port 443   # https
acl Safe_ports port 3000  # Grafana
acl Safe_ports port 9090  # Prometheus
acl Safe_ports port 9617  # AdGuard exporter
acl Safe_ports port 9301  # Squid exporter
acl Safe_ports port 9100  # Node exporter
acl CONNECT method CONNECT

# ACL para la interfaz de administración (requerido por squid-exporter / Grafana)
acl manager proto cache_object

# --- REDES LOCALES PERMITIDAS ---
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localhost src 127.0.0.1/32

# --- REGLAS DE ACCESO (en orden estricto) ---
# Permitir métricas al exporter y a localhost
http_access allow manager localhost
http_access allow manager

# Denegar accesos no seguros
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

# Permitir navegación a las redes locales
http_access allow localhost
http_access allow localnet

# Bloqueo por defecto
http_access deny all
```

| Directiva | Qué hace |
| --- | --- |
| `http_port 3128` | Puerto del proxy explícito (el navegador se configura para usarlo) |
| `http_port 3129 intercept` | Puerto del proxy transparente (recibe el tráfico redirigido por iptables) |
| `cache_mem 256 MB` | Cuánta RAM usa Squid para guardar objetos frecuentes |
| `cache_dir ufs /var/spool/squid 2048 16 256` | Caché en disco: tipo `ufs`, carpeta, **2048 MB** de tamaño, 16 carpetas de primer nivel y 256 de segundo nivel |
| `maximum_object_size 100 MB` | No guarda archivos mayores a 100 MB |
| `cache_replacement_policy lru` | Cuando se llena, elimina primero lo menos usado recientemente |
| `acl Safe_ports ...` | Lista de puertos de destino permitidos |
| `acl localnet src ...` | Redes privadas (10.x, 172.16-31.x, 192.168.x) a las que se permite navegar |
| `http_access allow/deny` | Reglas que se leen de arriba hacia abajo; la primera que coincide decide |

**Por qué importa el orden de `http_access`:** primero se deja pasar a las métricas, luego se bloquean los puertos raros y las conexiones `CONNECT` que no sean al 443, después se permite a las redes locales y al final se niega todo lo demás.

> **Nota de seguridad:** la regla `http_access allow manager` sin más condiciones deja abierta la página de estadísticas de Squid para cualquier origen que llegue al proxy. En el laboratorio es necesaria para que el exportador (que viene de la red de Docker) la lea. En producción conviene restringirla a la red local.

### Fase 6: Configurar Prometheus (`prometheus.yml`)

**Objetivo:** indicar a Prometheus qué servicios visitar y cada cuánto.

```bash
nano prometheus.yml
```

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'adguard'
    static_configs:
      - targets: ['adguard_exporter:9617']

  - job_name: 'squid'
    static_configs:
      - targets: ['squid_exporter:9301']

  - job_name: 'servidor_red'
    static_configs:
      - targets: ['node_exporter:9100']
```

| Elemento | Qué significa |
| --- | --- |
| `scrape_interval: 15s` | Cada 15 segundos Prometheus lee las métricas de cada servicio |
| `job_name` | Nombre del grupo. **Estos nombres aparecen en el panel "Estado de Servicios"** |
| `targets` | Dirección del exportador. Se usa el nombre del contenedor y el puerto interno |

✔ **Verificación de sintaxis (opcional):**

```bash
docker run --rm --entrypoint promtool -v "$PWD/prometheus.yml:/p.yml" prom/prometheus check config /p.yml
```

Debe terminar con `SUCCESS`. Si Docker aún no tiene la imagen, la descargará primero.

### Fase 7: Crear los scripts de automatización

**Objetivo:** crear tres scripts que detectan la IP del servidor, inician todo el laboratorio y (más adelante) redirigen el tráfico al proxy.

**Por qué hace falta `auto_update_ip.sh`:** la IP del servidor la entrega el DHCP del router y puede cambiar. El nombre `srv-colegio.lan` debe apuntar siempre a la IP vigente, así que el script la detecta y actualiza la reescritura DNS de AdGuard.

**Paso 7.1. Script `auto_update_ip.sh`**

```bash
nano auto_update_ip.sh
```

```bash
#!/bin/bash
# Entra a la carpeta del script para que las rutas relativas funcionen
cd "$(dirname "$0")" || exit 1

# 1. Detectar la IP actual de la interfaz de red principal
CURRENT_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')

if [ -z "$CURRENT_IP" ]; then
  echo "No se pudo obtener una dirección IP válida."
  exit 1
fi
echo "IP actual del servidor: $CURRENT_IP"

DOMAIN="srv-colegio.lan"
CONFIG_FILE="./adguard_conf/AdGuardHome.yaml"

if [ -f "$CONFIG_FILE" ]; then
  # 2. Detener AdGuard para que no sobrescriba el archivo mientras se edita
  docker stop adguard_dns > /dev/null 2>&1

  # 3. Cambiar la IP de la reescritura DNS del dominio
  sed -i -E "/domain: '?$DOMAIN'?/,/answer:/ s#answer: .*#answer: $CURRENT_IP#" "$CONFIG_FILE"
  echo "Configuración de AdGuard actualizada con la IP: $CURRENT_IP"

  # 4. Volver a iniciar solo AdGuard
  docker start adguard_dns > /dev/null 2>&1
else
  echo "No se encontró el archivo de configuración de AdGuard."
fi
```

| Parte del script | Qué hace |
| --- | --- |
| `cd "$(dirname "$0")"` | Se ubica en la carpeta donde está el script |
| `ip route get 8.8.8.8 ... src` | Pregunta al sistema "¿con qué IP salgo a Internet?" y toma el valor que sigue a `src`. Es más fiable que `hostname -I`, que puede devolver varias IP (incluida la de Docker) |
| `docker stop` / `docker start` | Apaga y enciende solo AdGuard, sin tocar los demás contenedores |
| `sed -i -E "/domain: .../,/answer:/ s#answer: .*#answer: IP#"` | Busca la línea `domain: srv-colegio.lan` y, en la línea `answer:` que le sigue, cambia la IP. Se usa `#` como separador para no confundirse con otros símbolos |

> El error `sed: opción desconocida para 's'` de la guía original aparecía cuando la variable de la IP traía caracteres inesperados (por ejemplo, varias IP o un salto de línea). Con la detección por `ip route` de este script no debería repetirse.

**Paso 7.2. Script iniciador `02_iniciar_lab.sh`**

```bash
nano 02_iniciar_lab.sh
```

```bash
#!/bin/bash
cd "$(dirname "$0")" || exit 1

echo "⚙️ Levantando la infraestructura del modelo telemático..."
docker compose up -d
sleep 3

sudo ./auto_update_ip.sh

docker compose ps

echo "----------------------------------------"
echo "✅ LABORATORIO EN LÍNEA (DOMINIO LOCAL)"
echo "🌐 RUTAS DE ACCESO DESDE TU NAVEGADOR:"
echo "➡️ Panel AdGuard   : http://srv-colegio.lan:3001"
echo "➡️ Panel Grafana   : http://srv-colegio.lan:3000"
echo "➡️ Panel Prometheus: http://srv-colegio.lan:9090"
echo "➡️ Monitor de Red  : http://srv-colegio.lan:9100/metrics"
echo "➡️ Puerto Proxy    : 3128"
echo "(Si el nombre no resuelve, usa la IP del servidor en lugar de srv-colegio.lan)"
echo "----------------------------------------"
```

**Paso 7.3. Script de intercepción `03_firewall.sh`** (se crea ahora y se ejecuta en la Fase 14)

```bash
nano 03_firewall.sh
```

```bash
#!/bin/bash
echo "🔍 Detectando la IP y la tarjeta de red del servidor..."
SERVER_IP=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
INTERFACE=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
echo "IP detectada: ${SERVER_IP} | Interfaz física: ${INTERFACE}"

echo "🛡️ Activando reenvío de paquetes e intercepción..."
sudo sysctl -w net.ipv4.ip_forward=1

# Agrega una regla solo si todavía no existe (evita duplicados)
add_rule() {
  sudo iptables -t nat -C "$@" 2>/dev/null || sudo iptables -t nat -A "$@"
}

# DNS (puerto 53) hacia AdGuard, excluyendo el tráfico de los contenedores Docker
add_rule PREROUTING -p udp --dport 53 ! -s 172.16.0.0/12 -j DNAT --to-destination ${SERVER_IP}:53
add_rule PREROUTING -p tcp --dport 53 ! -s 172.16.0.0/12 -j DNAT --to-destination ${SERVER_IP}:53

# Web (puerto 80) hacia Squid transparente, excluyendo a Docker
add_rule PREROUTING -p tcp --dport 80 ! -s 172.16.0.0/12 -j DNAT --to-destination ${SERVER_IP}:3129

# Enmascaramiento (NAT) por la interfaz detectada
add_rule POSTROUTING -o ${INTERFACE} -j MASQUERADE

echo "✅ Reglas aplicadas. Revísalas con: sudo iptables -t nat -L -n -v"
```

| Regla | Qué hace |
| --- | --- |
| `ip_forward=1` | Permite que el servidor reenvíe paquetes entre equipos |
| `PREROUTING ... --dport 53 ... DNAT` | Todo DNS que llegue al servidor se entrega a AdGuard, aunque el cliente haya pedido otro DNS (por ejemplo 8.8.8.8) |
| `PREROUTING ... --dport 80 ... --to-destination IP:3129` | Todo HTTP que llegue al servidor se entrega al puerto transparente de Squid |
| `! -s 172.16.0.0/12` | Excluye el tráfico que viene de los contenedores (Docker usa 172.x). Sin esta exclusión, Squid se redirigiría a sí mismo en un ciclo |
| `POSTROUTING ... MASQUERADE` | Hace que el tráfico reenviado salga con la IP del servidor |
| `add_rule` (función) | Comprueba con `-C` si la regla existe y solo la agrega si falta. La versión original usaba `iptables -t nat -F PREROUTING`, que **borra todas** las reglas de esa cadena, incluidas las que Docker necesita |

**Paso 7.4. Dar permiso de ejecución a todos los scripts**

```bash
chmod +x *.sh
ls -l *.sh
```

✔ **Verificación:** los cuatro archivos `.sh` muestran una `x` en los permisos (`-rwxr-xr-x`).

### Fase 8: Iniciar el laboratorio

**Objetivo:** descargar las imágenes y levantar los 7 contenedores.

```bash
./02_iniciar_lab.sh
```

La primera vez tarda varios minutos porque Docker descarga las imágenes.

✔ **Verificación:**

```bash
docker compose ps
```

| Contenedor | Estado esperado |
| --- | --- |
| `adguard_dns` | Up |
| `squid_proxy` | Up |
| `prometheus_db` | Up |
| `grafana_dashboard` | Up |
| `adguard_exporter` | Up |
| `squid_exporter` | Up |
| `node_exporter` | Up |

&#91;Captura 3: `docker compose ps` con los 7 contenedores en Up\]

**Si aparece el error `failed to bind host port 0.0.0.0:53/tcp: address already in use`**

Ubuntu tiene un servicio (`systemd-resolved`) que ya ocupa el puerto 53, y AdGuard necesita ese puerto. Solución:

1. Detén y deshabilita el servicio:

```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl status systemd-resolved
```

El último comando debe mostrar `inactive (dead)`.

2. Reemplaza el archivo de DNS del servidor para no quedarte sin Internet:

```bash
sudo rm /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
ping -c 3 google.com
```

3. Vuelve a ejecutar `./02_iniciar_lab.sh` y comprueba otra vez con `docker compose ps`.

**Si un contenedor aparece como `Restarting` o `Exited`:** mira su registro con `docker logs <nombre_del_contenedor>` y consulta el Anexo B.

### Fase 9: Verificar que los servicios responden y que Prometheus los ve

**Objetivo:** comprobar la cadena de datos antes de tocar Grafana.

**Paso 9.1. Probar los exportadores desde el servidor**

```bash
curl -s localhost:9617/metrics | grep adguard_num_dns_queries
curl -s localhost:9301/metrics | grep squid_client_http_requests_total
curl -s localhost:9100/metrics | grep node_network_transmit_bytes_total
```

Cada comando debe mostrar líneas con nombre de métrica y un número. En el de node\_exporter fíjate en el nombre del device (por ejemplo eth0, enp3s0 o ens33): ese es el nombre que usa el Panel 9. Si el de AdGuard no muestra nada, revisa el usuario y la contraseña del exportador (Fase 3 y Anexo B).

**Paso 9.2. Revisar los targets en Prometheus**

1. Abre en el navegador `http://<IP_SERVIDOR>:9090`.
2. Ve a **Status > Targets** (en versiones recientes puede llamarse *Target health*).
3. Deben aparecer 4 *jobs* (`prometheus`, `adguard`, `squid`, `servidor_red`) con estado **UP**.

**Paso 9.3. Probar una consulta**

1. En la pestaña **Query** (o *Graph*), escribe `up` y pulsa **Execute**.
2. Deben salir 4 filas con valor `1`.

✔ **Verificación:** 4 targets en UP y 4 resultados con valor 1. ✘ Si alguno está en DOWN, ese servicio o su exportador falló: no sigas a Grafana hasta resolverlo.

&#91;Captura 4: Prometheus, página Targets con los 4 jobs en UP\]

### Fase 10: Entrar a AdGuard y probar la resolución DNS desde un cliente

**Objetivo:** comprobar que un equipo de la red usa el servidor como DNS y resuelve `srv-colegio.lan`.

**Paso 10.1. Entrar al panel de AdGuard**

1. Abre `http://<IP_SERVIDOR>:3001`.
2. Inicia sesión con `jr-admin` y `linux1234`.

**Paso 10.2. Revisar (o crear) la reescritura DNS**

1. Ve a **Filtros > Reescrituras DNS**.
2. Debe existir la regla `srv-colegio.lan` con la IP del servidor (la deja lista el script). Si no aparece, pulsa **Añadir reescritura DNS** y completa:
   - **Dominio:** `srv-colegio.lan`
   - **IP:** la IP actual del servidor Ubuntu
3. Pulsa **Guardar**.

&#91;Captura 5: regla DNS `srv-colegio.lan` en AdGuard\]

**Paso 10.3. Configurar el cliente Windows para que use el servidor como DNS**

1. En el servidor, anota la IP con `hostname -I`.
2. En Windows: **Panel de control > Redes e Internet > Centro de redes > Cambiar configuración del adaptador**.
3. Clic derecho en tu adaptador > **Propiedades > Protocolo de Internet versión 4 (TCP/IPv4) > Propiedades**.
4. Marca **Usar las siguientes direcciones de servidor DNS** y escribe la IP del servidor en **Servidor DNS preferido**.
5. Acepta los cambios.

**Paso 10.4. Probar desde la consola de Windows (CMD o PowerShell)**

```
ipconfig /flushdns
ping srv-colegio.lan
nslookup srv-colegio.lan
```

✔ **Verificación:** el `ping` responde desde la IP del servidor (por ejemplo, `Respuesta desde 192.168.1.58: bytes=32 tiempo<1m TTL=64`) y `nslookup` muestra esa misma IP.

&#91;Captura 6: ping exitoso a `srv-colegio.lan` desde Windows\]

**Paso 10.5. Probar un bloqueo**

```
nslookup cuevana3.com
```

Debe responder con error o rechazo (por ejemplo, `Query refused`) o con la dirección `0.0.0.0`, porque la regla personalizada `||*cuevana*^` lo bloquea. En el panel de AdGuard, en **Registro de consultas**, verás esa consulta marcada como bloqueada.

> Si apagas el servidor mientras el cliente lo usa como DNS, el cliente se queda sin resolución de nombres. Para revertir, vuelve a marcar **Obtener la dirección del servidor DNS automáticamente**.

### Fase 11: Grafana, fuente de datos e importación del dashboard (método rápido)

**Objetivo:** conectar Grafana a Prometheus y cargar el dashboard **Consola Central de Telemetría** desde el archivo `dashboard-telemetria.json`.

**Paso 11.1. Entrar a Grafana**

1. Abre `http://<IP_SERVIDOR>:3000`.
2. Usuario `admin` y contraseña `admin`. Grafana pedirá cambiar la contraseña (puedes omitirlo en el laboratorio).

**Paso 11.2. Crear la fuente de datos (Data source)**

1. Menú lateral > **Connections > Data sources > Add data source**.
2. Elige **Prometheus**.
3. En **Prometheus server URL** escribe `http://prometheus:9090`.
4. Deja **Authentication method** en *No Authentication*.
5. Baja hasta el final y pulsa **Save & test**.

✔ **Verificación:** aparece un mensaje verde parecido a *Successfully queried the Prometheus API*.

**Por qué `http://prometheus:9090` y no `srv-colegio.lan:9090`:** la consulta la hace el contenedor de Grafana, no tu navegador. Dentro de la red de Docker, `prometheus` es el nombre del servicio y siempre se resuelve; `srv-colegio.lan` depende del DNS del servidor y puede fallar.

&#91;Captura 7: Data source Prometheus guardado con éxito\]

**Paso 11.3. Obtener el identificador (UID) de tu fuente de datos**

1. En **Connections > Data sources**, haz clic en `prometheus`.
2. Mira la dirección del navegador: termina en `/connections/datasources/edit/XXXXXXXX`. Ese `XXXXXXXX` es tu **UID**. Cópialo.

**Paso 11.4. Ajustar el JSON antes de importarlo**

El dashboard original fue exportado de otro Grafana y dentro del archivo cada panel apunta a la fuente de datos `efzh5rtmm718ga`. Esa fuente **no existe en tu Grafana**, y por eso, si importas el archivo sin ajustarlo, los paneles saldrán con *No data* hasta que cambies la fuente panel por panel.

La forma más rápida de evitarlo:

1. Abre `dashboard-telemetria.json` en el Bloc de notas (o cualquier editor de texto).
2. Pulsa `Ctrl+H` (Buscar y reemplazar).
3. Reemplaza **`efzh5rtmm718ga`** por **tu UID** en todas las apariciones.
4. Guarda el archivo.

**Paso 11.5. Importar el archivo**

1. Menú lateral > **Dashboards > New > Import**.
2. Pulsa **Upload dashboard JSON file** y elige el archivo ajustado (o pega su contenido en el cuadro de texto).
3. Pulsa **Load**.
4. Si Grafana muestra una lista desplegable de fuentes de datos, elige explícitamente `prometheus`. Revisa el nombre y la carpeta.
5. Pulsa **Import**.

**Paso 11.6. Limpiar y dejar el dashboard listo**

1. Arriba a la izquierda verás un selector extra llamado `query0`. Es una variable vacía creada por error en el original y no se usa en ningún panel. Para quitarla: **Edit > Settings > Variables**, abre `query0` y elige **Delete**.
2. En el selector de tiempo (arriba a la derecha) elige **Last 15 minutes**, y en el botón de refresco elige **10s**, para ver cómo se mueven los números.
3. Pulsa **Save dashboard**.

✔ **Verificación:** los paneles importados (8 en el archivo original; el Panel 9 se agrega en la Fase 12) muestran números (algunos pueden estar en 0 mientras no haya tráfico; eso no es un error). Si un panel dice **No data**, abre su menú > **Edit** y revisa en **Data source** que diga `prometheus`.

**Alternativa si prefieres arreglar panel por panel** (método de la guía original): para cada panel, **Edit**, despliega **Data source**, elige `prometheus`, **Back to dashboard**, y al final **Save**.

**Opción avanzada: fijar el UID desde el inicio.** Si vas a reinstalar el laboratorio muchas veces, puedes crear un archivo de aprovisionamiento para que Grafana cree la fuente de datos con el mismo UID del JSON (`efzh5rtmm718ga`) y no tengas que editar nada. Crea `grafana_prov/datasources/prometheus.yml` con este contenido:

```yaml
apiVersion: 1
datasources:
  - name: prometheus
    type: prometheus
    uid: efzh5rtmm718ga
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

En el `docker-compose.yml`, en el servicio `grafana`, añade bajo `volumes:` la línea `- ./grafana_prov:/etc/grafana/provisioning` y ejecuta `docker compose up -d`. Si lo haces, omite los pasos 11.2 a 11.4.

> **Compatibilidad:** el archivo `dashboard-telemetria.json` usa el formato nuevo de Grafana (`dashboard.grafana.app/v2`) y fue guardado desde Grafana v13.2. Si tu Grafana es antiguo y rechaza el archivo, usa la Fase 12 para construir el dashboard a mano. Esa fase sirve en cualquier versión.

### Fase 12: Construir el dashboard desde cero en Grafana (paso a paso)

**Objetivo:** crear a mano, panel por panel, el dashboard que contiene el JSON (8 paneles) más un noveno panel de tráfico de red. Sirve para (1) entender qué mide cada recuadro, (2) usarlo si la importación falla y (3) poder explicarlo en la defensa. Tiempo estimado: 35 a 45 minutos.

**Antes de empezar:** debe existir la fuente de datos `prometheus` (Paso 11.2) y los targets de Prometheus deben estar en UP (Fase 9).

**Paso 12.1. Crear el dashboard vacío**

1. Menú lateral > **Dashboards > New > New dashboard**.
2. Pulsa **+ Add visualization**.
3. Si te pide elegir fuente de datos, selecciona `prometheus`.

Se abre el **editor de panel**: arriba la vista previa, abajo las pestañas **Queries** y **Transformations**, y a la derecha las opciones de visualización.

**Paso 12.2. Receta general (se repite igual en los 9 paneles)**

| # | Acción | Dónde |
| --- | --- | --- |
| 1 | Verifica que **Data source** diga `prometheus` | Pestaña Queries, esquina superior izquierda |
| 2 | Cambia el modo de la consulta de **Builder** a **Code** | Selector a la derecha de la consulta A |
| 3 | Escribe (o pega) la consulta PromQL del panel | Cuadro de la consulta A |
| 4 | Despliega **Options** (bajo la consulta) y ajusta **Legend** y **Type** (*Range* o *Instant*) si la tabla del panel lo indica | Debajo de la consulta |
| 5 | Pulsa **Run queries** (o `Shift+Enter`). Debe aparecer un número o una gráfica | Parte superior de la consulta |
| 6 | Elige el tipo de visualización (**Stat** o **Gauge**) | Parte superior derecha del editor |
| 7 | Escribe el **Title** y ajusta las opciones indicadas (texto, color, unidad) | Panel derecho. Usa el buscador *Search options* si no encuentras una opción |
| 8 | Pulsa **Back to dashboard** | Arriba a la derecha |
| 9 | Para el siguiente panel: **Add > Visualization** | Barra superior del dashboard |

**Opciones que se mencionan en las tablas**

| Opción | Qué hace |
| --- | --- |
| **Calculation** (Value options) | Qué valor mostrar de la serie. Todos los paneles usan **Last \*** (último valor no nulo) |
| **Text mode** | Qué texto se dibuja: solo el valor, valor y nombre, etc. |
| **Color mode** | **Value** colorea el número; **Background** colorea el fondo |
| **Graph mode** | **Area** dibuja una pequeña gráfica de fondo; **None** no la dibuja |
| **Unit** | Formato del número. *Percent (0-100)* añade el símbolo % |
| **Color scheme** | **Single color** usa un solo color; **From thresholds (by value)** cambia de color según los umbrales |
| **Thresholds** | Umbrales: valor desde el cual el color cambia |
| **Type** (Query options) | **Range** consulta todo el intervalo de tiempo; **Instant** consulta solo el valor actual |

> Los nombres de menús pueden variar un poco entre versiones de Grafana. Si no encuentras una opción, escríbela en el buscador del panel derecho.

**Panel 1. Estado de Servicios**

| Campo | Valor |
| --- | --- |
| Consulta | `up` |
| Options > Legend | **Custom**, valor `{{job}}` (muestra el nombre del job en vez de una etiqueta larga) |
| Options > Type | **Instant** |
| Visualización | **Stat** |
| Title | `Estado de Servicios` |
| Text mode | **Value and name** |
| Color mode / Graph mode | **Value** / **None** |
| Calculation | **Last \*** |
| Color scheme | **Single color**, verde (`green`) |

Resultado: cuatro números grandes (`servidor_red`, `adguard`, `squid`, `prometheus`), cada uno en **1** si el servicio está activo.

*Mejora opcional:* con color verde fijo, un servicio caído (0) también se vería verde. Para que el panel alerte de verdad: **Color scheme** = *From thresholds (by value)*, **Thresholds** = base roja y `1` verde, y en **Value mappings** agrega `0` → texto `CAÍDO` y `1` → texto `ACTIVO`.

**Panel 2. Consultas DNS Totales**

| Campo | Valor |
| --- | --- |
| Consulta | `adguard_num_dns_queries` |
| Options > Type | **Range** (predeterminado) |
| Visualización | **Stat** |
| Title | `Consultas DNS Totales` |
| Text mode / Graph mode | **Value** / **None** |
| Color scheme | **Single color**, azul oscuro (`dark-blue`) |

Mide cuántas consultas DNS ha atendido AdGuard según sus estadísticas.

**Panel 3. Dominios Bloqueados**

| Campo | Valor |
| --- | --- |
| Consulta | `adguard_num_blocked_filtering{job="adguard"}` |
| Visualización | **Stat** |
| Title | `Dominios Bloqueados` |
| Text mode / Graph mode | **Auto** / **None** |
| Color scheme | **Single color**, rojo oscuro (`dark-red`) |

Las llaves `{job="adguard"}` son un **filtro**: solo toma la métrica del job llamado `adguard`.

**Panel 4. Tasa de Bloqueo (%)**

| Campo | Valor |
| --- | --- |
| Consulta | `(sum(adguard_num_blocked_filtering) / sum(adguard_num_dns_queries)) * 100` |
| Visualización | **Stat** |
| Title | `Tasa de Bloqueo (%)` |
| Graph mode | **Area** |
| Unit | **Percent (0-100)** |
| Color scheme | **From thresholds (by value)** |
| Thresholds | Base verde; `80` rojo |

Divide los bloqueados entre el total de consultas y multiplica por 100. En la captura de referencia daba 8,61 %.

**Panel 5. Peticiones Proxy (Squid)**

| Campo | Valor |
| --- | --- |
| Consulta | `sum(squid_client_http_requests_total)` |
| Options > Type | **Instant** |
| Visualización | **Stat** |
| Title | `Peticiones Proxy (Squid)` |
| Text mode / Graph mode | **Auto** / **Area** |
| Color scheme | **Single color**, naranja oscuro (`dark-orange`) |

`sum(...)` suma todas las series de esa métrica en un solo número: total de peticiones que ha atendido Squid.

**Panel 6. Aciertos de Caché (Hits)**

| Campo | Valor |
| --- | --- |
| Consulta | `sum(increase(squid_client_http_hits_total{job="squid"}[5m]))` |
| Visualización | **Stat** |
| Title | `Aciertos de Caché (Hits)` |
| Text mode / Graph mode | **Auto** / **Area** |
| Color scheme | **Single color**, morado (`semi-dark-purple`) |

`increase(...[5m])` calcula cuánto subió el contador en los últimos 5 minutos: aciertos de caché recientes.

**Panel 7. Tasa de Aciertos (%)**

| Campo | Valor |
| --- | --- |
| Consulta | `(sum(rate(squid_client_http_hits_total[5m])) / sum(rate(squid_client_http_requests_total[5m]))) * 100` |
| Visualización | **Gauge** |
| Title | `Tasa de Aciertos (%)` |
| Unit | **Percent (0-100)** (conviene fijar **Min** = 0 y **Max** = 100) |
| Color scheme | **Single color**, verde claro (`light-green`) |
| Opciones del medidor | Shape **Circle**; activar **Show threshold markers** |

`rate(...[5m])` es la velocidad por segundo en los últimos 5 minutos. Al dividir aciertos entre peticiones se obtiene el porcentaje de peticiones atendidas desde la caché.

**Panel 8. Byte Hit Ratio (porcentaje de ahorro de ancho de banda)**

| Campo | Valor |
| --- | --- |
| Consulta | `(sum(rate(squid_client_http_hits_total[5m])) / sum(rate(squid_client_http_requests_total[5m]))) * 100` |
| Visualización | **Stat** |
| Title | `Byte Hit Ratio (Porcentaje de Ahorro de Ancho de Banda)` |
| Graph mode | **Area** |
| Unit | **Percent (0-100)** |
| Color scheme | **From thresholds (by value)** |

> **Aviso técnico:** esta consulta es idéntica a la del Panel 7, así que mide aciertos **por petición** (*request hit ratio*), no **por bytes**. El nombre del panel promete ahorro de ancho de banda, que se calcula con los bytes servidos desde caché sobre los bytes totales. En el Anexo A se explica cómo corregirlo. Para la entrega puedes dejarlo igual que el original y mencionar esta limitación.

**Panel 9. Tráfico de Red WAN**

| Campo | Valor |
| --- | --- |
| Consulta A | `rate(node_network_transmit_bytes_total{device="eth0"}[$__rate_interval])` |
| Consulta B (opcional) | `rate(node_network_receive_bytes_total{device="eth0"}[$__rate_interval])`, que se agrega con el botón **+ Query** |
| Options > Type | **Range** |
| Options > Legend | Empieza en **Auto**; cámbialo a **Custom** y escribe `{{device}}` |
| Visualización | **Time series** |
| Title | `Tráfico de Red WAN` |
| Unit | **Data rate > bytes/sec(IEC)** |

`node_network_transmit_bytes_total` es un contador con los bytes enviados por la interfaz; `rate(...)` lo convierte en bytes por segundo. `$__rate_interval` es una variable de Grafana que ajusta la ventana de cálculo al intervalo de lectura de Prometheus (15 s), así que no hay que escribir un valor fijo. La consulta B muestra los bytes recibidos; si la agregas, distingue las curvas con leyendas como `{{device}} transmitido` y `{{device}} recibido`.

> **Nota técnica sobre `eth0`:** es el nombre de interfaz de este ejemplo. En Ubuntu la tarjeta física suele llamarse `enp3s0`, `ens33` o similar: averigua el tuyo con `ip route get 8.8.8.8` (aparece después de `dev`) y cámbialo en las consultas. Además, un contenedor con red propia puede ver solo las interfaces de su propio espacio de red aunque monte `/proc` y `/sys`. Comprueba qué dispositivos aparecen con `curl -s localhost:9100/metrics | grep node_network_transmit_bytes_total`. Si tu tarjeta física no aparece, la documentación de `node_exporter` indica ejecutar el contenedor con `network_mode: host`; en ese caso se ignora `ports:` y Prometheus debe apuntar a la IP del servidor en lugar de `node_exporter:9100`.

**Paso 12.3. Ordenar los paneles**

Arrastra cada panel por su título y redimensiona con la esquina inferior derecha. La cuadrícula de Grafana tiene 24 columnas. Esta es la disposición del dashboard original:

| Panel | Posición (columna, fila) | Tamaño (ancho × alto) |
| --- | --- | --- |
| Estado de Servicios | 0, 0 | 12 × 6 |
| Tasa de Aciertos (%) | 12, 0 | 12 × 8 |
| Tasa de Bloqueo (%) | 0, 6 | 12 × 6 |
| Byte Hit Ratio | 12, 8 | 11 × 6 |
| Peticiones Proxy (Squid) | 0, 12 | 12 × 8 |
| Dominios Bloqueados | 12, 14 | 12 × 8 |
| Consultas DNS Totales | 0, 20 | 12 × 8 |
| Aciertos de Caché (Hits) | 12, 22 | 12 × 7 |
| Tráfico de Red WAN (nuevo) | 0, 28 | 24 × 8 |

**Paso 12.4. Ajustes del dashboard y guardado**

1. Pulsa **Edit > Settings** (engranaje).
2. **Title:** `Consola Central de Telemetría`. **Description:** `Consola Central de Telemetría`.
3. Cierra los ajustes y fija arriba a la derecha el rango **Last 15 minutes** y el refresco automático en **10s**.
4. Pulsa **Save dashboard**.

**Paso 12.5. Exportar tu propio JSON (respaldo)**

1. Abre el dashboard y pulsa **Export > Export as JSON** (en algunas versiones, **Share > Export**).
2. Descarga el archivo. Con él puedes restaurar el panel en otro servidor usando la Fase 11.

✔ **Verificación:** los 9 paneles existen y muestran datos o ceros, sin el aviso **No data**. Compara con la captura de referencia (4 servicios en 1; ejemplo de valores: 1079 peticiones, 1684 consultas DNS, 145 bloqueados, 8,61 % de bloqueo).

&#91;Captura 8: dashboard completo con los 9 paneles\]

### Fase 13: Generar tráfico y leer los resultados

**Objetivo:** hacer que los paneles se muevan y entender por qué algunos valores pueden quedarse en 0.

**Paso 13.1. Generar consultas DNS (desde el cliente Windows con DNS = servidor)**

Navega varios sitios normales y prueba algunos bloqueados:

```
nslookup google.com
nslookup wikipedia.org
nslookup cuevana3.com
nslookup thepiratebay.org
```

Suben **Consultas DNS Totales** y **Dominios Bloqueados**.

&#91;Captura 10: Registro de consultas de AdGuard con una consulta bloqueada\]

**Paso 13.2. Generar tráfico por el proxy (método explícito, el más seguro para empezar)**

Opción A, en Windows: **Configuración > Red e Internet > Proxy > Configuración manual del proxy > Usar un servidor proxy**. Dirección: la IP del servidor. Puerto: `3128`. Guarda y navega por páginas **HTTP** (sin candado), por ejemplo `http://example.com`.

Opción B, desde la terminal del servidor:

```bash
for i in 1 2 3 4 5; do curl -s -o /dev/null -w "%{http_code}\n" -x http://localhost:3128 http://example.com/; done
curl -s -D - -o /dev/null -x http://localhost:3128 http://example.com/ | grep -i x-cache
```

El primer comando envía 5 peticiones por el proxy y muestra el código de respuesta (`200`). El segundo muestra la cabecera `X-Cache`: `MISS` significa que Squid fue a Internet; `HIT` significa que respondió desde su caché.

&#91;Captura 11: cabecera X-Cache de Squid (primero MISS y luego HIT)\]

**Paso 13.3. Esperar y leer los paneles**

Prometheus lee cada 15 segundos y varias consultas usan ventanas de 5 minutos, así que espera entre 30 segundos y 1 minuto antes de concluir que algo no funciona.

| Panel | Qué debe ocurrir | Si no se mueve |
| --- | --- | --- |
| Consultas DNS Totales | Aumenta con cada consulta DNS | Revisa que el cliente use la IP del servidor como DNS y las credenciales del exportador de AdGuard |
| Dominios Bloqueados / Tasa de Bloqueo | Aumentan al consultar dominios de las listas | Prueba con `cuevana3.com` y revisa el Registro de consultas de AdGuard |
| Peticiones Proxy (Squid) | Aumenta con el tráfico por el proxy | Confirma que el navegador usa el proxy o que las reglas de la Fase 14 están activas |
| Aciertos de Caché / Tasa de Aciertos / Byte Hit Ratio | Pueden permanecer en **0** | Es normal ver 0 (ver explicación) |

**Por qué los aciertos de caché suelen estar en 0:** (1) casi todo el Internet actual usa HTTPS y Squid no puede guardar contenido cifrado; (2) muchos sitios HTTP marcan su contenido como no almacenable; (3) un acierto solo ocurre cuando alguien pide **de nuevo** el mismo objeto. La captura de referencia también muestra 0 % de aciertos por esta razón. Para ver un acierto, repite varias veces una petición HTTP a un objeto estático.

### Fase 14: Intercepción transparente con iptables (opcional, avanzada)

**Objetivo:** redirigir el tráfico HTTP (puerto 80) y DNS (puerto 53) de los clientes hacia Squid y AdGuard sin que configuren nada en el navegador.

**Lo que debes saber antes de empezar**

- Las reglas actúan solo sobre los paquetes que **llegan al servidor**. Para que el tráfico de un cliente pase por ellas, el cliente debe tener como **puerta de enlace (gateway)** la IP del servidor.
- Solo se redirige el **puerto 80 (HTTP)**. El HTTPS (puerto 443) **no** se intercepta.
- Hazlo en un laboratorio o con autorización, porque afecta la navegación de los equipos que usen el servidor como gateway.

**Paso 14.1. Configurar el cliente de prueba**

En el adaptador de red de Windows, en IPv4, usa **Usar la siguiente dirección IP** con: una IP libre de tu red, la misma máscara, **Puerta de enlace predeterminada = IP del servidor** y **DNS = IP del servidor**.

**Paso 14.2. Aplicar las reglas en el servidor**

```bash
sudo ./03_firewall.sh
```

**Paso 14.3. Verificar**

```bash
sudo iptables -t nat -L PREROUTING -n -v
sudo iptables -t nat -L POSTROUTING -n -v
```

Deben verse las reglas `DNAT` (puertos 53 y 80) y `MASQUERADE`. Abre en el cliente una página HTTP, vuelve a ejecutar el primer comando y comprueba que el contador de paquetes (`pkts`) de la regla del puerto 80 aumentó. Luego mira el panel **Peticiones Proxy (Squid)** en Grafana.

**Paso 14.4. Deshacer las reglas (si lo necesitas)**

```bash
SERVER_IP=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
INTERFACE=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
sudo iptables -t nat -D PREROUTING -p udp --dport 53 ! -s 172.16.0.0/12 -j DNAT --to-destination ${SERVER_IP}:53
sudo iptables -t nat -D PREROUTING -p tcp --dport 53 ! -s 172.16.0.0/12 -j DNAT --to-destination ${SERVER_IP}:53
sudo iptables -t nat -D PREROUTING -p tcp --dport 80 ! -s 172.16.0.0/12 -j DNAT --to-destination ${SERVER_IP}:3129
sudo iptables -t nat -D POSTROUTING -o ${INTERFACE} -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=0
```

**Persistencia:** estas reglas **se pierden al reiniciar el servidor**. Vuelve a ejecutar `sudo ./03_firewall.sh` después de cada reinicio (o añade esa línea al final de `02_iniciar_lab.sh`). Si el firewall `ufw` está activo (`sudo ufw status`), debes permitir los puertos 53, 3000, 3001, 3128, 3129 y 9090.

&#91;Captura 9: reglas de iptables y contador de paquetes\]

## 6. Evidencias y verificación integral

### 6.1 Lista de capturas de pantalla

| Captura | Fase | Qué debe mostrar |
| --- | --- | --- |
| 1 | 0 | `ip a` con la IP del servidor |
| 2 | 1 | Versiones de `docker` y `docker compose` |
| 3 | 8 | `docker compose ps` con los 7 contenedores en Up |
| 4 | 9 | Prometheus, página Targets, 4 jobs en UP |
| 5 | 10 | AdGuard, regla de reescritura `srv-colegio.lan` |
| 6 | 10 | Ping exitoso a `srv-colegio.lan` desde Windows |
| 7 | 11 | Data source Prometheus con *Save & test* correcto |
| 8 | 11 o 12 | Dashboard completo con los 9 paneles y datos |
| 9 | 14 | Reglas `iptables` con el contador de paquetes |
| 10 | 13 | Registro de consultas de AdGuard con una consulta bloqueada |
| 11 | 13 | Cabecera `X-Cache` (MISS y luego HIT) de Squid |

### 6.2 Verificación integral (de principio a fin)

| # | Prueba | Cómo se hace | Resultado esperado | ✔/✘ |
| --- | --- | --- | --- | --- |
| 1 | Docker instalado | `docker compose version` | Muestra la versión |  |
| 2 | Contenedores activos | `docker compose ps` | 7 contenedores en Up |  |
| 3 | Panel de AdGuard | `http://<IP_SERVIDOR>:3001` | Inicio de sesión con `jr-admin` |  |
| 4 | Exportador de AdGuard | `curl -s localhost:9617/metrics \| grep adguard_num` | Líneas con números |  |
| 5 | Exportador de Squid | `curl -s localhost:9301/metrics \| grep squid_client_http_requests_total` | Línea con número |  |
| 6 | Prometheus | Status > Targets | 4 targets en UP |  |
| 7 | Consulta `up` | Pestaña Query de Prometheus | 4 resultados con valor 1 |  |
| 8 | Resolución del dominio local | `ping srv-colegio.lan` en Windows | Responde la IP del servidor |  |
| 9 | Bloqueo DNS | `nslookup cuevana3.com` | Rechazado o `0.0.0.0` |  |
| 10 | Proxy explícito | `curl -x http://localhost:3128 http://example.com/` | Código `200` |  |
| 11 | Grafana conectado | Data source > Save & test | Mensaje de éxito |  |
| 12 | Dashboard | Los 9 paneles | Sin *No data* |  |
| 13 | Intercepción (opcional) | Reglas DNAT con paquetes | Contador de `pkts` aumenta |  |
| 14 | Métricas de red del servidor | curl -s localhost:9100/metrics \| grep node\_network\_transmit\_bytes\_total | Aparece la interfaz que usa el Panel 9 |  |

### 6.3 Apagado, encendido y respaldo del laboratorio

| Acción | Comando (dentro de `laboratorio-tesis`) |
| --- | --- |
| Detener los contenedores (conserva todo) | `docker compose stop` |
| Iniciar de nuevo después de detener | `docker compose start` |
| Iniciar tras reiniciar el servidor | `./02_iniciar_lab.sh` (recalcula la IP y actualiza AdGuard) |
| Eliminar contenedores (los volúmenes se conservan) | `docker compose down` |
| **Eliminar también los datos de Grafana** | `docker compose down -v` (cuidado: borra los dashboards guardados en el volumen) |
| Respaldar configuración | Copiar la carpeta `laboratorio-tesis` y el JSON exportado del dashboard |

### 6.4 Mejoras de seguridad recomendadas (más allá del laboratorio)

- Cambiar `jr-admin` / `linux1234` y la contraseña `admin` de Grafana, y no publicar contraseñas en documentos.
- Sustituir `chmod 777` por permisos mínimos y, en lo posible, mover las credenciales del compose a un archivo `.env`.
- Restringir `http_access allow manager` de Squid a la red local.
- Publicar solo los puertos necesarios (los de exportadores `9100`, `9301` y `9617` normalmente no hace falta exponerlos fuera del servidor).
- Añadir un volumen para los datos de Prometheus si se quiere conservar el historial al recrear el contenedor.
- Si se necesita filtrar HTTPS, estudiar *SSL Bump* con un certificado de la institución instalado en los equipos (requiere autorización y conlleva implicaciones de privacidad).

## Anexo A. Dashboard: referencia de los 9 paneles y del JSON

### A.1 Resumen de paneles

| ID | Panel | Tipo | Consulta PromQL | De dónde sale |
| --- | --- | --- | --- | --- |
| 5 | Estado de Servicios | Stat | `up` | Prometheus (automática por cada target) |
| 1 | Consultas DNS Totales | Stat | `adguard_num_dns_queries` | `adguard_exporter` |
| 2 | Dominios Bloqueados | Stat | `adguard_num_blocked_filtering{job="adguard"}` | `adguard_exporter` |
| 9 | Tasa de Bloqueo (%) | Stat | `(sum(adguard_num_blocked_filtering) / sum(adguard_num_dns_queries)) * 100` | `adguard_exporter` |
| 3 | Peticiones Proxy (Squid) | Stat | `sum(squid_client_http_requests_total)` | `squid_exporter` |
| 6 | Aciertos de Caché (Hits) | Stat | `sum(increase(squid_client_http_hits_total{job="squid"}[5m]))` | `squid_exporter` |
| 7 | Tasa de Aciertos (%) | Gauge | `(sum(rate(squid_client_http_hits_total[5m])) / sum(rate(squid_client_http_requests_total[5m]))) * 100` | `squid_exporter` |
| 10 | Byte Hit Ratio | Stat | La misma consulta del panel 7 | `squid_exporter` |
| nuevo | Tráfico de Red WAN | Time series | rate(node\_network\_transmit\_bytes\_total{device="eth0"}\[$\_\_rate\_interval\]) (opcional: la misma con node\_network\_receive\_bytes\_total) | node\_exporter |

El dashboard completo se llama **Consola Central de Telemetría**, usa el rango **Last 5 minutes** (se recomienda ampliarlo a 15 minutos) y no tiene refresco automático configurado (se recomienda 10 s). Los ocho primeros paneles vienen en el archivo dashboard-telemetria.json; el Panel 9 se agrega con la Fase 12 y se vuelve a exportar (Paso 12.5).

### A.2 Cómo leer el archivo JSON y su equivalente en la interfaz

El archivo `dashboard-telemetria.json` describe lo mismo que construiste a mano. Si lo abres, cada campo se corresponde con una opción de pantalla:

| Campo del JSON | Opción en Grafana |
| --- | --- |
| `spec.title` | Dashboard > Settings > Title |
| `spec.elements.panel-N.spec.title` | Title del panel |
| `vizConfig.group` (`stat`, `gauge`) | Tipo de visualización |
| `queries[].spec.query.spec.expr` | Consulta PromQL (modo Code) |
| `legendFormat` (`{{job}}` o `__auto`) | Options > Legend (Custom o Auto) |
| `instant: true` / `range: true` | Options > Type (Instant o Range) |
| `datasource.name` (`efzh5rtmm718ga`) | UID de la fuente de datos (debe existir en tu Grafana) |
| `options.textMode` | Text mode |
| `options.colorMode` | Color mode |
| `options.graphMode` (`area` o `none`) | Graph mode |
| `options.reduceOptions.calcs` (`lastNotNull`) | Calculation = Last \* |
| `fieldConfig.defaults.unit` (`percent`) | Unit = Percent (0-100) |
| `fieldConfig.defaults.color.fixedColor` | Color scheme = Single color |
| `fieldConfig.defaults.color.mode` (`thresholds`) | Color scheme = From thresholds (by value) |
| `fieldConfig.defaults.thresholds.steps` | Thresholds (base verde, 80 rojo) |
| `layout.spec.items` (`x`, `y`, `width`, `height`) | Posición y tamaño del panel en la cuadrícula de 24 columnas |
| `timeSettings.from` (`now-5m`) | Rango de tiempo |
| `variables` (`query0`) | Dashboard > Settings > Variables (variable vacía, se puede borrar) |

### A.3 Cómo corregir de verdad el panel Byte Hit Ratio

El **Byte Hit Ratio** mide qué porcentaje de los **bytes** entregados a los clientes salió de la caché. Se calcula como bytes servidos desde caché divididos entre bytes totales entregados. Pasos:

1. En el servidor, lista las métricas de volumen de Squid:

```bash
curl -s localhost:9301/metrics | grep -i kbytes
```

2. Identifica dos métricas: los bytes servidos **desde caché** (nombre con `hit` y `out`) y los bytes **totales entregados** a clientes (nombre con `kbytes_out`). Anota sus nombres y la unidad que indican (`bytes` o `kbytes`).
3. Si ambas están en la misma unidad, la consulta es:

```
(sum(rate(<METRICA_BYTES_DESDE_CACHE>[5m])) / sum(rate(<METRICA_BYTES_TOTALES>[5m]))) * 100
```

4. Si una está en bytes y la otra en kilobytes, multiplica la de kilobytes por 1024 para igualar las unidades antes de dividir.
5. Pégala en el Panel 8 y comprueba que el resultado esté entre 0 y 100.

Confirma los nombres exactos en tu instalación porque pueden variar según la versión del exportador.

### A.4 Cómo descubrir qué métricas existen

En Prometheus (`http://<IP_SERVIDOR>:9090`), en la pestaña **Query**, empieza a escribir `squid_` o `adguard_`: el autocompletado lista las métricas disponibles. También se puede usar el explorador de métricas (*Metrics explorer*). En Grafana, dentro del editor de un panel, el modo **Builder** tiene un selector de métricas con la misma información.

## Anexo B. Solución de problemas

### B.1 Método de diagnóstico: revisar la cadena de datos en orden

Cuando un panel muestra *No data* o un valor raro, revisa los eslabones **de izquierda a derecha** y detente en el primero que falle:

1. **Servicio origen:** ¿el contenedor está en Up? (`docker compose ps`).
2. **Exportador:** ¿responde `/metrics`? (`curl -s localhost:9617/metrics`, `localhost:9301/metrics`).
3. **Prometheus:** ¿el target está en UP y la consulta devuelve datos en la pestaña Query?
4. **Grafana:** ¿Save & test del data source es correcto y el panel usa ese data source? ¿El rango de tiempo es adecuado?

### B.2 Tabla de problemas frecuentes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| `failed to bind host port 0.0.0.0:53/tcp: address already in use` | `systemd-resolved` ocupa el puerto 53 | Fase 8: detener y deshabilitar `systemd-resolved` y recrear `resolv.conf` |
| `permission denied` al usar `docker` | El usuario aún no pertenece al grupo `docker` en esta sesión | `newgrp docker` o cerrar sesión y volver a entrar |
| El contenedor `squid_proxy` o `prometheus_db` no arranca y `squid.conf` o `prometheus.yml` aparece como carpeta | Se ejecutó `docker compose up` antes de crear el archivo; Docker creó una carpeta con ese nombre | `docker compose down`, `sudo rm -r squid.conf` (o `prometheus.yml`), crear el archivo correcto y repetir `up -d` |
| `squid_proxy` en `Restarting` | Error de sintaxis en `squid.conf` o carpeta `squid_cache` sin permisos | `docker logs squid_proxy`; revisar `squid.conf`; repetir `chmod 777 squid_cache` |
| Target `adguard` en DOWN o `adguard_num_*` vacío | Usuario o contraseña del exportador incorrectos, o AdGuard no está activo | Revisar `ADGUARD_USERNAME` y `ADGUARD_PASSWORD` en el compose; `docker logs adguard_exporter`; `docker compose up -d` para recrear |
| Target `squid` en DOWN | El exportador no puede leer las estadísticas de Squid | `docker logs squid_exporter`; revisar la ACL `manager` y `http_access` en `squid.conf` |
| `http://<IP>:3001` no abre | AdGuard caído o YAML mal formado | `docker logs adguard_dns`; revisar sangría del YAML |
| No puedo iniciar sesión en AdGuard | La contraseña del hash no coincide | Generar un hash nuevo (Fase 3) |
| Todos los paneles en *No data* tras importar el JSON | El JSON apunta al UID `efzh5rtmm718ga`, que no existe en tu Grafana | Fase 11, Pasos 11.3 y 11.4 (reemplazar el UID) o elegir `prometheus` en cada panel |
| *Save & test* falla en Grafana | URL incorrecta | Usa `http://prometheus:9090` y confirma que `prometheus_db` está en Up |
| Aciertos de caché siempre en 0 | HTTPS no se guarda en caché; poco tráfico HTTP repetido | Es normal (Fase 13). Repite varias veces una petición HTTP cacheable |
| `ping srv-colegio.lan` no resuelve | El cliente no usa el servidor como DNS, o la caché DNS del cliente | Revisar el DNS del adaptador, `ipconfig /flushdns` y la regla en AdGuard |
| `srv-colegio.lan` resuelve a una IP vieja | La IP del servidor cambió | Ejecutar `./02_iniciar_lab.sh` (o `sudo ./auto_update_ip.sh`) |
| El cliente se queda sin Internet tras cambiar el DNS | El servidor o AdGuard están apagados, o AdGuard no llega a Quad9 | Revisar `docker compose ps` y `docker logs adguard_dns`; temporalmente volver a DNS automático en el cliente |
| Respuestas DNS lentas o rechazadas con muchos clientes | Límite `ratelimit: 20` consultas por segundo por subred `/24` | Aumentar el valor en `AdGuardHome.yaml` y reiniciar AdGuard |
| Disco lleno | Registros y estadísticas, imágenes de Docker antiguas | `df -h`, `docker system df`, `docker image prune`; reducir `querylog.interval` |
| Tras reiniciar, el tráfico ya no se intercepta | Las reglas `iptables` no son persistentes | Repetir `sudo ./03_firewall.sh` |
| Panel Tráfico de Red WAN en No data o en 0 | El nombre de la interfaz no es eth0, o node-exporter solo ve la red de su contenedor | Revisa los device disponibles con el comando de la Fase 9, cambia eth0 en la consulta y, si hace falta, usa network\_mode: host en node-exporter |

## Anexo C. Comandos útiles

| Comando | Para qué sirve |
| --- | --- |
| `docker compose ps` | Ver el estado de los contenedores |
| `docker compose up -d` | Crear e iniciar los contenedores en segundo plano |
| `docker compose stop` / `start` | Detener / iniciar sin eliminar |
| `docker compose down` | Eliminar los contenedores (conserva volúmenes) |
| `docker compose restart <servicio>` | Reiniciar un servicio (por ejemplo, `squid`) |
| `docker logs <contenedor>` | Ver el registro de un contenedor |
| `docker logs -f <contenedor>` | Seguir el registro en vivo (`Ctrl+C` para salir) |
| `docker exec -it <contenedor> sh` | Entrar a la terminal de un contenedor |
| `docker compose config -q` | Validar la sintaxis del compose |
| `curl -s localhost:<puerto>/metrics` | Ver las métricas de un exportador |
| `ip a` / `hostname -I` | Ver las IP del servidor |
| `ip route get 8.8.8.8` | Ver con qué IP e interfaz sale el servidor a Internet |
| `sudo iptables -t nat -L -n -v` | Ver las reglas NAT con contadores |
| `nslookup <dominio> [servidor]` | Consultar el DNS |
| `ipconfig /flushdns` (Windows) | Limpiar la caché DNS del cliente |
| `df -h` / `free -h` | Ver espacio en disco y memoria |

## Anexo D. Glosario

| Término | Significado |
| --- | --- |
| ACL | Lista de control de acceso: regla que agrupa orígenes, puertos o métodos para permitir o negar tráfico en Squid |
| AdGuard Home | Servidor DNS con filtrado y panel web |
| Acierto de caché (*hit*) | Petición respondida con una copia guardada, sin ir a Internet |
| Contenedor | Programa ejecutándose de forma aislada a partir de una imagen |
| Counter (contador) | Métrica que solo aumenta |
| DNAT | Traducción del destino de un paquete (redirección) |
| DNS | Sistema que traduce nombres de dominio a direcciones IP |
| Docker Compose | Herramienta para definir y levantar varios contenedores con un archivo YAML |
| Exportador (*exporter*) | Programa que publica métricas de un servicio para que Prometheus las lea |
| Gauge | Visualización de medidor; también, métrica que puede subir y bajar |
| Grafana | Plataforma de paneles y gráficos |
| Job | Grupo de targets en Prometheus |
| MASQUERADE | NAT que usa la IP de salida del servidor |
| Métrica | Valor numérico medido a lo largo del tiempo |
| Modo puente (*Bridged*) | Adaptador de red virtual que obtiene IP de la red local real |
| Panel | Recuadro de un dashboard con una consulta y una visualización |
| PromQL | Lenguaje de consultas de Prometheus |
| Prometheus | Base de datos de series temporales que recolecta métricas |
| Proxy explícito / transparente | Proxy que el cliente configura / que el firewall impone sin que el cliente lo sepa |
| Reescritura DNS (*rewrite*) | Respuesta DNS fija definida por el administrador |
| Scrape | Lectura periódica de las métricas de un target |
| Stat | Visualización de un número grande |
| Target | Dirección de un exportador que Prometheus visita |
| *Upstream* | Servidor DNS externo al que AdGuard reenvía las consultas |
| Volumen | Carpeta o espacio persistente conectado a un contenedor |
| YAML | Formato de archivo de configuración basado en sangría |

## Bibliografía

- Guía de despliegue: Infraestructura Telemática. Anexo técnico de implementación para sistemas de red y monitoreo (versión original del proyecto).
- Archivo `dashboard-telemetria.json` (exportado de Grafana v13.2.0).
- Documentación oficial de Docker y Docker Compose.
- Wiki y documentación oficial de AdGuard Home (configuración YAML, reescrituras DNS, servicios bloqueados).
- Documentación oficial de Squid (directivas `http_port`, `cache_dir`, `acl`, `http_access`).
- Documentación oficial de Prometheus (configuración, PromQL) y de Grafana (data sources, importación de dashboards, visualizaciones Stat y Gauge).
- Repositorios de los exportadores `ebrianne/adguard-exporter` y `boynux/squid-exporter`, y página de manual de `prometheus-squid-exporter` (Debian/Ubuntu).
- Páginas de manual de Linux: `iptables(8)`, `ip(8)`, `sysctl(8)`.

Nota: los nombres de menús de Grafana y de Prometheus pueden cambiar entre versiones; en caso de diferencia, consulta la documentación de la versión instalada.
