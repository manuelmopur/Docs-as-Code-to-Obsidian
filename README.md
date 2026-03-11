# Sistema de Sincronización: Docs-as-Code a Obsidian

> **Tipo de Infraestructura:** Event-Driven (inotifywait) + Systemd User Service

---

## ¿Para qué sirve este sistema?
Resuelve el dilema arquitectónico entre mantener la documentación en el repositorio (para dar contexto como "Docs-as-Code") y tener una base de conocimiento centralizada en Obsidian. 

Escucha en tiempo real cualquier cambio en los archivos `.md` del código fuente y los copia automáticamente a la bóveda de Obsidian.
* **Origen (El Código manda):** `<TU_RUTA_DE_ORIGEN>` (ej. `~/Projects/MiRepo`)
* **Destino (Solo lectura):** `<TU_RUTA_DE_DESTINO>` (ej. `~/Documents/Obsidian`)

---

## Características Principales

1. **Sincronización Unidireccional:** El código fuente es la única fuente de la verdad.
2. **Reactividad:** Usa `inotifywait` para reaccionar a eventos en tiempo real sin consumir CPU.
3. **Manejo CRUD Completo:** Escucha y replica eventos de Creación, Modificación, Eliminación y Renombramiento de archivos.
4. **Filtro Anti-Basura:** Excluye automáticamente directorios irrelevantes usando expresiones regulares (`.git`, `node_modules`, `vendor`, y carpetas ocultas).
5. **Autostart sin Root:** Empaquetado como un servicio de *Systemd* a nivel de usuario.
6. **Sincronización de Estado (Fallback):** Al iniciar, ejecuta un `rsync` para capturar cualquier cambio que haya ocurrido mientras el sistema estaba apagado.

---

## Archivos en este Directorio

* `sync_docs.sh`: El script bash principal con la lógica de monitoreo de archivos.
* `sync-docs.service`: El archivo unit de configuración para Systemd.

---

## Guía de Instalación

**Nota Importante:** Antes de ejecutar el servicio, debes editar el archivo `sync_docs.sh` para configurar tus variables `ORIGEN` y `DESTINO` reales.

**1. Instalar dependencias del sistema:**
```bash
sudo apt update && sudo apt install -y inotify-tools rsync
```

**2. Ubicar y dar permisos al script:**
Por defecto, el servicio espera que el script esté en el subdirectorio `scripts` de tu usuario. 
```bash
mkdir -p ~/scripts
cp sync_docs.sh ~/scripts/
chmod +x ~/scripts/sync_docs.sh
```

**3. Instalar y habilitar el servicio Systemd:**
```bash
# Crear la carpeta de servicios de usuario si no existe
mkdir -p ~/.config/systemd/user/

# Copiar el archivo del servicio
cp sync-docs.service ~/.config/systemd/user/

# Recargar los demonios de systemd
systemctl --user daemon-reload

# Habilitar el servicio para que arranque con el sistema e iniciarlo ahora
systemctl --user enable --now sync-docs.service
```

**4. Verificar el estado:**
```bash
systemctl --user status sync-docs.service

# Opcional: ver los logs en tiempo real
journalctl --user -fu sync-docs.service
```
