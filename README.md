# -Instalaci-n-de-CMS-en-pila-LEMP

## índice

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

* `sudo -u www-data wp ... --path=/var/www/wordpress`: Ejecuta WP-CLI con el usuario `www-data` sobre `/var/www/wordpress`.
* `wp user list`, `wp post list` y `wp plugin status`: Listan usuarios y roles, entradas/páginas y estado de plugins.
* `ls -la /var/www/wordpress/wp-config.php`: Muestra el propietario, grupo y permisos (`-rw-r-----`, `640`) de `wp-config.php`.

**Resultado**

Aparecen los usuarios con sus roles, las publicaciones, los plugins y `wp-config.php` con permisos `640` (`www-data:www-data`).

## Paso 6: Navegador web en HTTPS (`https://localhost:8443`)

**Qué voy a hacer**

Voy a abrir el sitio en el navegador de Windows a través de `https://localhost:8443` para comprobar visualmente la carga por HTTPS.

![Captura 8](img/Captura%20de%20pantalla%202026-11-26%20093345.png)

**Resultado**

El navegador muestra el sitio WordPress servido sobre `https://localhost:8443`.

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





























































