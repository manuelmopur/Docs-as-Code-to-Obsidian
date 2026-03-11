#!/usr/bin/env bash
# sync_docs.sh — Sincronizacion unidireccional de Markdown
# Vigila cambios en archivos .md en ORIGEN y replica en DESTINO.
# Uso optimizado para systemd user service.

set -euo pipefail

# --- Configuracion ---

ORIGEN="${HOME}/Projects/MyRepo"
DESTINO="${HOME}/Documents/Obsidian/carpeta_a_sincronizar"

LOG_DIR="${HOME}/.local/share/sync-docs"
LOG_FILE="${LOG_DIR}/sync_docs.log"
MAX_LOG_SIZE=$((5 * 1024 * 1024))  # 5 MB

# Exclusiones (regex): .git, node_modules, vendor, y ocultas
EXCLUDE_REGEX='/(\.git|node_modules|vendor)/|/\.[^/]+/'

# --- Funciones auxiliares ---

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

rotate_log() {
    if [[ -f "${LOG_FILE}" ]]; then
        local size
        size=$(stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0)
        if (( size > MAX_LOG_SIZE )); then
            mv "${LOG_FILE}" "${LOG_FILE}.old"
            log "Log rotado"
        fi
    fi
}

should_ignore() {
    local path="$1"
    if [[ "${path}" =~ /\.[^/]+/ ]] || \
       [[ "${path}" =~ /node_modules/ ]] || \
       [[ "${path}" =~ /vendor/ ]]; then
        return 0
    fi
    return 1
}

get_dest_path() {
    local src_path="$1"
    echo "${DESTINO}${src_path#"${ORIGEN}"}"
}

# --- Sync inicial ---

initial_sync() {
    log "Iniciando rsync de sincronizacion base"

    rsync -av --delete \
        --include='*/' \
        --include='*.md' \
        --exclude='*' \
        --exclude='.git/' \
        --exclude='node_modules/' \
        --exclude='vendor/' \
        --exclude='.*/' \
        "${ORIGEN}/" "${DESTINO}/" >> "${LOG_FILE}" 2>&1

    # Limpia directorios vacíos en destino omitiendo config de Obsidian
    find "${DESTINO}" -type d -empty -not -path "${DESTINO}/.obsidian*" -delete 2>/dev/null || true

    log "Sincronizacion base completada"
}

# --- Manejo de eventos ---

handle_event() {
    local dir="$1"
    local events="$2"
    local filename="$3"
    local full_src="${dir}${filename}"

    if should_ignore "${full_src}"; then
        return
    fi

    local full_dest
    full_dest=$(get_dest_path "${full_src}")
    local dest_dir
    dest_dir=$(dirname "${full_dest}")

    # Eventos de directorio
    if [[ "${events}" == *"ISDIR"* ]]; then
        if [[ "${events}" == *"CREATE"* ]] || [[ "${events}" == *"MOVED_TO"* ]]; then
            log "DIR CREATE: ${full_src}"
            mkdir -p "${full_dest}"
        elif [[ "${events}" == *"DELETE"* ]] || [[ "${events}" == *"MOVED_FROM"* ]]; then
            log "DIR DELETE: ${full_src}"
            if [[ -d "${full_dest}" ]]; then
                rm -rf "${full_dest}"
            fi
        fi
        return
    fi

    if [[ "${filename}" != *.md ]]; then
        return
    fi

    # Eventos de archivo
    if [[ "${events}" == *"CREATE"* ]] || \
       [[ "${events}" == *"CLOSE_WRITE"* ]] || \
       [[ "${events}" == *"MODIFY"* ]] || \
       [[ "${events}" == *"MOVED_TO"* ]]; then

        log "SYNC: ${full_src} -> ${full_dest}"
        mkdir -p "${dest_dir}"
        cp -f "${full_src}" "${full_dest}"

    elif [[ "${events}" == *"DELETE"* ]] || \
         [[ "${events}" == *"MOVED_FROM"* ]]; then

        log "DELETE: ${full_dest}"
        if [[ -f "${full_dest}" ]]; then
            rm -f "${full_dest}"
        fi

        # Limpieza de directorios vacíos
        if [[ -d "${dest_dir}" ]] && [[ -z "$(ls -A "${dest_dir}" 2>/dev/null)" ]]; then
            if [[ "${dest_dir}" != "${DESTINO}" ]] && [[ "${dest_dir}" != *".obsidian"* ]]; then
                rmdir --parents --ignore-fail-on-non-empty "${dest_dir}" 2>/dev/null || true
            fi
        fi
    fi
}

# --- Main ---

main() {
    mkdir -p "${LOG_DIR}" "${DESTINO}"
    rotate_log

    log "--- Servicio sync_docs.sh iniciado ---"
    log "Origen:  ${ORIGEN}"
    log "Destino: ${DESTINO}"
    log "PID:     $$"

    initial_sync

    log "Monitor inotifywait activo"

    inotifywait -m -r \
        --exclude "${EXCLUDE_REGEX}" \
        --format '%w %e %f' \
        -e create -e modify -e close_write -e delete -e moved_from -e moved_to \
        "${ORIGEN}" | while IFS=' ' read -r dir events filename; do

        handle_event "${dir}" "${events}" "${filename}" || true
        rotate_log
    done
}

trap 'log "Servicio detenido (señal recibida)"; exit 0' SIGTERM SIGINT SIGHUP

main "$@"
