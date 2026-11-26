# -Instalaci-n-de-CMS-en-pila-LEMP

## índice

## Introducción

En este proyecto se automatiza el despliegue y refuerzo de **WordPress** sobre una pila **LEMP** (**Nginx**, **MariaDB** y **PHP-FPM**), aprovisionado mediante **WP-CLI**, protegido con **HTTPS** y auditado con **WPScan** antes y después de aplicar medidas de endurecimiento.

La infraestructura parte de un equipo anfitrión **Windows 11** con **Git Bash**, donde **VirtualBox 7.2** y **Vagrant 2.4.9** levantan una máquina virtual **Debian 12** (`lempMiriam`) con carpeta compartida (`/vagrant`) y reenvío de puertos **8080 -> 80** (HTTP) y **8443 -> 443** (HTTPS). MariaDB se restringe a `127.0.0.1` y WordPress se configura con usuarios de distintos roles, tema y plugins instalados por CLI y permisos endurecidos (`640` en `wp-config.php`).

## Paso 1: Preparación del proyecto y control de versiones

**Qué voy a hacer** 

Voy a verificar que los archivos del proyecto y los scripts de `provision/` existen, que el `Vagrantfile` es válido y que `git status` no expone ficheros sensibles como `.env`.
