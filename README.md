# -Instalaci-n-de-CMS-en-pila-LEMP

## índice
## índice

- [Introducción](#introducción)
- [Paso 1: Preparación del proyecto y control de versiones](#paso-1-preparación-del-proyecto-y-control-de-versiones)
- [Paso 2: Despliegue de la VM (`lempMiriam`) y redirección de puertos](#paso-2-despliegue-de-la-vm-lempmiriam-y-redirección-de-puertos)
- [Paso 3: Estado de la pila LEMP y restricción de MariaDB a local](#paso-3-estado-de-la-pila-lemp-y-restricción-de-mariadb-a-local)
- [Paso 4: Redirección HTTP -> HTTPS y verificación del certificado SAN](#paso-4-redirección-http---https-y-verificación-del-certificado-san)
- [Paso 5: Usuarios, entradas, plugins y permisos de WordPress (WP-CLI)](#paso-5-usuarios-entradas-plugins-y-permisos-de-wordpress-wp-cli)
- [Paso 6: Navegador web en HTTPS (`https://localhost:8443` y `/wp-admin`)](#paso-6-navegador-web-en-HTTPS-httpslocalhost8443-y-wp-admin)
- [Paso 7: Auditoría inicial con WPScan (ANTES del refuerzo de seguridad)](#paso-7-auditoría-inicial-con-wpscan-antes-del-refuerzo-de-seguridad)
- [Paso 8: Refuerzo de seguridad y segundo WPScan (DESPUÉS del refuerzo)](#paso-8-refuerzo-de-seguridad-y-segundo-wpscan-después-del-refuerzo)
- [Paso 9: Limpieza de archivos temporales y subida a GitHub](#paso-9-limpieza-de-archivos-temporales-y-subida-a-github)
## Introducción

En este proyecto se automatiza el despliegue y refuerzo de **WordPress** sobre una pila **LEMP** (**Nginx**, **MariaDB** y **PHP-FPM**), aprovisionado mediante **WP-CLI**, protegido con **HTTPS** y auditado con **WPScan** antes y después de aplicar medidas de endurecimiento.

La infraestructura parte de un equipo anfitrión **Windows 11** con **Git Bash**, donde **VirtualBox 7.2** y **Vagrant 2.4.9** levantan una máquina virtual **Debian 12** (`lempMiriam`) con carpeta compartida (`/vagrant`) y reenvío de puertos **8080 -> 80** (HTTP) y **8443 -> 443** (HTTPS). MariaDB se restringe a `127.0.0.1` y WordPress se configura con usuarios de distintos roles, tema y plugins instalados por CLI y permisos endurecidos (`640` en `wp-config.php`).

## Paso 1: Preparación del proyecto y control de versiones

**Qué voy a hacer** 

Voy a verificar que los archivos del proyecto y los scripts de `provision/` existen, que el `Vagrantfile` es válido y que `git status` no expone ficheros sensibles como `.env`.

![Captura 1](img/Captura%20de%20pantalla%202026-11-26%20093149.png)

* `ls -la && ls -la provision/`: Lista archivos ocultos y normales en la raíz y en `provision/`.
* `vagrant validate`: Comprueba que la sintaxis del `Vagrantfile` no tiene errores.
* `git status`: Muestra los archivos modificados o sin seguimiento en el repositorio.

**Resultado** 
Se ven los archivos del proyecto y scripts de `provision/`, `vagrant validate` confirma que el `Vagrantfile` es válido y `git status` muestra el estado sin incluir `.env` como cambio a subir.


## Paso 2: Despliegue de la VM (`lempMiriam`) y redirección de puertos

**Qué voy a hacer**

Voy a verificar que la máquina virtual `lempMiriam` tenga los puertos reenviados desde el host hacia la máquina invitada.

![Captura 2](img/Captura%20de%20pantalla%202026-11-26%20093240.png)

* `vagrant port`: Lista los puertos reenviados entre el host (Windows) y la VM (Debian 12).

**Resultado**

`vagrant port` muestra el mapeo de `8080 -> 80` y `8443 -> 443`.

## Paso 3: Estado de la pila LEMP y restricción de MariaDB a local

**Qué voy a hacer**

Voy a comprobar dentro de `lempMiriam` que Nginx, PHP-FPM y MariaDB están activos y que los puertos `80`, `443` y `3306` están escuchando, con MariaDB limitado a `127.0.0.1`.

![Captura 3](img/Captura%20de%20pantalla%202026-11-26%20093320.png)

* `vagrant ssh -c "..."`: Ejecuta el comando dentro de la máquina virtual `lempMiriam`.
* `systemctl is-active nginx php*-fpm mariadb`: Comprueba si Nginx, PHP-FPM y MariaDB están activos.
* `ss -tlpn | grep -E '80|443|3306'`: Lista los sockets TCP en escucha y filtra los puertos `80`, `443` y `3306`.

**Resultado**

Los servicios aparecen como `active` y `ss` muestra `80`, `443` y `127.0.0.1:3306` en `LISTEN`.

## Paso 4: Redirección HTTP -> HTTPS y verificación del certificado SAN

**Qué voy a hacer**

Voy a verificar que `http://localhost:8080` redirige (`301`) a `https://localhost:8443/` y a revisar el `CN` y el `Subject Alternative Name` (SAN) del certificado TLS.

![Captura 4](img/Captura%20de%20pantalla%202026-11-26%20093332.png)

![Captura 5](img/Captura%20de%20pantalla%202026-11-26%20093345.png)

![Captura 6](img/Captura%20de%20pantalla%202026-11-26%20093434.png)

* `curl -I http://localhost:8080`: Solicita solo las cabeceras HTTP a `http://localhost:8080` para ver la redirección.
* `echo | openssl s_client -connect localhost:8443 -servername localhost 2>/dev/null`: Conecta por TLS a `localhost:8443` enviando SNI y ocultando mensajes de error.

**Resultado**

Se ve `HTTP/1.1 301 Moved Permanently` con `Location: https://localhost:8443/` y el certificado con `CN = localhost` y `DNS:localhost, IP Address:127.0.0.1`.

## Paso 5: Usuarios, entradas, plugins y permisos de WordPress (WP-CLI)

**Qué voy a hacer**

Voy a comprobar mediante WP-CLI (como `www-data`) los usuarios creados, las entradas/páginas publicadas, los plugins y los permisos `640` de `wp-config.php`.

![Captura 7](img/Captura%20de%20pantalla%202026-11-26%20110600.png)

![Captura 7](img/Captura%20de%20pantalla%202026-11-26%20120430.png)

* `sudo -u www-data wp ... --path=/var/www/wordpress`: Ejecuta WP-CLI con el usuario `www-data` sobre `/var/www/wordpress`.
* `wp user list`, `wp post list` y `wp plugin status`: Listan usuarios y roles, entradas/páginas y estado de plugins.
* `ls -la /var/www/wordpress/wp-config.php`: Muestra el propietario, grupo y permisos (`-rw-r-----`, `640`) de `wp-config.php`.

**Resultado**

Aparecen los usuarios con sus roles, las publicaciones, los plugins y `wp-config.php` con permisos `640` (`www-data:www-data`).

## Paso 6: Navegador web en HTTPS (`https://localhost:8443`)

**Qué voy a hacer**

Voy a abrir tanto la portada pública en `https://localhost:8443` como el panel de administración en `https://localhost:8443/wp-login.php` desde el navegador de Windows para comprobar visualmente la carga por HTTPS.

![Captura 8](img/Captura%20de%20pantalla%202026-11-26%20093345.png)

![Captura 8](img/Captura%20de%20pantalla%202026-11-26%20120719.png)

![Captura 8](img/Captura%20de%20pantalla%202026-11-26%20120844.png)

**Resultado**

El navegador muestra tanto la portada pública de *WordPress de Miriam* como el Escritorio de administración autenticado con `miriam_admin` en español y con el plugin *Limit Login Attempts Reloaded* activo, todo servido de forma segura sobre `https://localhost:8443`.

## Paso 7: Auditoría inicial con WPScan (ANTES del refuerzo de seguridad)

**Qué voy a hacer**

Voy a instalar `wpscan` y ejecutar un escaneo inicial sobre `https://localhost:8443` guardando el informe en `/vagrant/wpscan-antes.txt`.

![Captura 9](img/Captura%20de%20pantalla%202026-11-26%20102154.png)

![Captura 10](img/Captura%20de%20pantalla%202026-11-26%20110226.png)

* `if ! command -v wpscan ... then ... fi`: Instala `wpscan` y sus dependencias en la VM si aún no existe.
* `wpscan --url https://localhost:8443 --disable-tls-checks --enumerate vp,vt,u --format cli-no-color`: Escanea plugins vulnerables (`vp`), temas vulnerables (`vt`) y usuarios (`u`) omitiendo la comprobación estricta del certificado autofirmado.

**Resultado**

El escaneo finaliza y se genera `wpscan-antes.txt` en la carpeta del proyecto.

## Paso 8: Refuerzo de seguridad y segundo WPScan (DESPUÉS del refuerzo)

**Qué voy a hacer**

Voy a limpiar saltos de línea CRLF de `provision/harden.sh`, aplicar el endurecimiento y comprobar las cabeceras HTTP resultantes.

![Captura 11](img/Captura%20de%20pantalla%202026-11-26%20105658.png)

`sed -i 's/\r$//' provision/harden.sh && chmod +x provision/harden.sh`: Convierte finales de línea a LF y da permiso de ejecución.
* `sudo bash /vagrant/provision/harden.sh`: Aplica las medidas de refuerzo y recarga servicios.
* `curl -Ik https://localhost:8443 | grep -iE "..."`: Comprueba las cabeceras HTTP de respuesta y seguridad.

### Tabla comparativa de auditoría (ANTES vs. DESPUÉS)

| Hallazgo | Riesgo | Medida | Resultado |
| :--- | :--- | :--- | :--- |
| Enumeración de usuarios y exposición de información en WPScan / REST API o rutas sensibles | Medio-Alto: Facilita ataques de fuerza bruta o reconocimiento de cuentas válidas (como administradores) | Aplicación de medidas de endurecimiento en `provision/harden.sh` y protección de acceso con *Limit Login Attempts Reloaded* | Reducción de exposición detectada en `wpscan-despues.txt` y bloqueo ante intentos repetidos de acceso |
| Cabeceras HTTP de seguridad y ocultación de versión del servidor | Medio: Posible *clickjacking*, *MIME sniffing* o identificación de versión de software | Configuración de cabeceras de seguridad en Nginx (`X-Frame-Options`, `X-Content-Type-Options`, etc.) y `server_tokens off` | Cabeceras verificadas con `curl -Ik https://localhost:8443` tras recargar servicios |
| Permisos de `wp-config.php` y archivos del directorio de WordPress | Alto: Acceso no autorizado a credenciales de base de datos o modificación de archivos web | Propietario `www-data:www-data`, `755` en directorios, `644` en archivos y `640` en `wp-config.php` | Permisos aplicados y comprobados (`640` en `wp-config.php`) |
| Alcance de red de MariaDB y transporte de tráfico web | Alto: Exposición de la base de datos o envío de credenciales/sesiones en texto plano | MariaDB restringido a `127.0.0.1` y redirección forzada de HTTP (`8080 -> 80`) a HTTPS (`8443 -> 443`) con TLS | Servicios activos en escucha segura y redirección `301` a `https://localhost:8443/` |

**Resultado**

`harden.sh` se aplica sin errores, se crea `wpscan-despues.txt` y `curl` muestra las cabeceras de seguridad configuradas.

## Paso 9: Limpieza de archivos temporales y subida a GitHub

**Qué voy a hacer**

Voy a eliminar los informes temporales de WPScan si no se desean en el repositorio, revisar `git status` y subir los cambios a GitHub.

![Captura 12](img/Captura%20de%20pantalla%202026-11-26%20102753.png)

* `rm -f wpscan-antes.txt wpscan-despues.txt`: Elimina los archivos temporales de salida si no van al repositorio.
* `git status`: Verifica los archivos a incluir y comprueba que `.env` no se sube.
* `git add ...`, `git commit -m "..."` y `git push`: Añade, confirma y envía los cambios al repositorio remoto.

**Resultado**

El commit se realiza correctamente y el repositorio remoto queda actualizado sin exponer `.env`.





























































