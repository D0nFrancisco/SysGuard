# SysGuard - Automated System Monitoring & Alert Tool

## 📝 Descripción
SysGuard es un script robusto desarrollado en **Bash** diseñado para el monitoreo automatizado de recursos críticos en sistemas Linux. Esta herramienta permite a los administradores supervisar la salud del servidor en tiempo real y recibir alertas visuales cuando se superan los umbrales de seguridad.

## 🚀 Características Principales
- **Monitoreo en Tiempo Real:** Seguimiento de CPU, RAM, Uso de Disco y Tráfico de Red.
- **Lógica de Alertas:** Sistema de colores (ANSI) para identificar estados OK (Verde) y ALERTA (Rojo).
- **Reportes Visuales:** Generación automática de reportes en formato **HTML/CSS** para una revisión rápida.
- **Automatización:** Configurado para ejecutarse de forma autónoma mediante **Cron Jobs**.
- **Configuración Desacoplada:** Ajuste de umbrales sin modificar el código fuente.

## 🛠️ Tecnologías Utilizadas
- **Lenguaje:** Bash Shell Scripting.
- **Herramientas de Linux:** `awk`, `sed`, `grep`, `procfs`, `cron`.
- **Frontend:** HTML5 y CSS3 para reportes.

## 📦 Instalación y Uso
1. Clonar el repositorio:
   ```bash
   git clone https://github.com/D0nFrancisco/sysguard.git
   cd sysguard
