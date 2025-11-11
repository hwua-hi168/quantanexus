#!/bin/bash

# Script para ejecutar todos los playbooks de Ansible y rastrear su estado
# Autor: Script generado automáticamente
# Fecha: $(date)

set -e  # Salir si hay algún error

# Configuración
PLAYBOOKS_DIR="playbooks"
LOG_DIR="logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/playbooks_execution_${TIMESTAMP}.log"
RESULTS_FILE="${LOG_DIR}/playbooks_results_${TIMESTAMP}.json"
SUMMARY_FILE="${LOG_DIR}/playbooks_summary_${TIMESTAMP}.txt"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Crear directorio de logs si no existe
mkdir -p "$LOG_DIR"

# Función para logging
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Función para mostrar progreso
show_progress() {
    local current=$1
    local total=$2
    local playbook=$3
    local percent=$((current * 100 / total))
    printf "\r${BLUE}[%d/%d] (%d%%) Ejecutando: %s${NC}" "$current" "$total" "$percent" "$playbook"
}

# Función para ejecutar un playbook
execute_playbook() {
    local playbook=$1
    local playbook_path="${PLAYBOOKS_DIR}/${playbook}"
    local start_time=$(date +%s)
    local result=""
    local exit_code=0
    
    log "\n${YELLOW}=== Ejecutando: $playbook ===${NC}"
    log "Inicio: $(date)"
    
    # Ejecutar el playbook
    if ansible-playbook -i "${PLAYBOOKS_DIR}/hosts" "$playbook_path" --check 2>&1 | tee -a "$LOG_FILE"; then
        result="SUCCESS"
        log "${GREEN}✓ $playbook ejecutado exitosamente${NC}"
    else
        exit_code=$?
        result="FAILED"
        log "${RED}✗ $playbook falló con código de salida: $exit_code${NC}"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Fin: $(date)"
    log "Duración: ${duration}s"
    log "${YELLOW}=== Fin de $playbook ===${NC}\n"
    
    # Retornar resultado en formato JSON
    echo "{\"playbook\":\"$playbook\",\"result\":\"$result\",\"duration\":$duration,\"exit_code\":$exit_code,\"timestamp\":\"$(date -Iseconds)\"}"
}

# Función para generar resumen
generate_summary() {
    local results_file=$1
    local summary_file=$2
    
    echo "=== RESUMEN DE EJECUCIÓN DE PLAYBOOKS ===" > "$summary_file"
    echo "Fecha: $(date)" >> "$summary_file"
    echo "Total de playbooks: $(jq -r '. | length' "$results_file")" >> "$summary_file"
    echo "Exitosos: $(jq -r '[.[] | select(.result == "SUCCESS")] | length' "$results_file")" >> "$summary_file"
    echo "Fallidos: $(jq -r '[.[] | select(.result == "FAILED")] | length' "$results_file")" >> "$summary_file"
    echo "" >> "$summary_file"
    echo "=== DETALLES ===" >> "$summary_file"
    jq -r '.[] | "\(.playbook): \(.result) (\(.duration)s)"' "$results_file" >> "$summary_file"
    echo "" >> "$summary_file"
    echo "=== PLAYBOOKS FALLIDOS ===" >> "$summary_file"
    jq -r '.[] | select(.result == "FAILED") | .playbook' "$results_file" >> "$summary_file"
}

# Función principal
main() {
    log "${BLUE}=== INICIANDO EJECUCIÓN DE TODOS LOS PLAYBOOKS ===${NC}"
    log "Timestamp: $TIMESTAMP"
    log "Directorio de playbooks: $PLAYBOOKS_DIR"
    log "Archivo de log: $LOG_FILE"
    log "Archivo de resultados: $RESULTS_FILE"
    log ""
    
    # Verificar que el directorio de playbooks existe
    if [ ! -d "$PLAYBOOKS_DIR" ]; then
        log "${RED}Error: El directorio $PLAYBOOKS_DIR no existe${NC}"
        exit 1
    fi
    
    # Verificar que ansible-playbook está disponible
    if ! command -v ansible-playbook &> /dev/null; then
        log "${RED}Error: ansible-playbook no está instalado o no está en el PATH${NC}"
        exit 1
    fi
    
    # Obtener lista de playbooks (archivos .yml y .yaml)
    playbooks=($(find "$PLAYBOOKS_DIR" -name "*.yml" -o -name "*.yaml" | grep -v "hosts" | sort))
    
    if [ ${#playbooks[@]} -eq 0 ]; then
        log "${YELLOW}No se encontraron playbooks para ejecutar${NC}"
        exit 0
    fi
    
    log "Se encontraron ${#playbooks[@]} playbooks para ejecutar:"
    for playbook in "${playbooks[@]}"; do
        log "  - $(basename "$playbook")"
    done
    log ""
    
    # Array para almacenar resultados
    results=()
    successful=0
    failed=0
    
    # Ejecutar cada playbook
    for i in "${!playbooks[@]}"; do
        local playbook="${playbooks[$i]}"
        local playbook_name=$(basename "$playbook")
        local current=$((i + 1))
        local total=${#playbooks[@]}
        
        show_progress "$current" "$total" "$playbook_name"
        
        # Ejecutar playbook y capturar resultado
        local result=$(execute_playbook "$playbook_name")
        results+=("$result")
        
        # Contar éxitos y fallos
        if echo "$result" | jq -r '.result' | grep -q "SUCCESS"; then
            ((successful++))
        else
            ((failed++))
        fi
    done
    
    echo "" # Nueva línea después del progreso
    
    # Guardar resultados en archivo JSON
    printf "[\n" > "$RESULTS_FILE"
    for i in "${!results[@]}"; do
        printf "%s" "${results[$i]}" >> "$RESULTS_FILE"
        if [ $i -lt $((${#results[@]} - 1)) ]; then
            printf ",\n" >> "$RESULTS_FILE"
        else
            printf "\n" >> "$RESULTS_FILE"
        fi
    done
    printf "]\n" >> "$RESULTS_FILE"
    
    # Generar resumen
    generate_summary "$RESULTS_FILE" "$SUMMARY_FILE"
    
    # Mostrar resumen final
    log "\n${BLUE}=== RESUMEN FINAL ===${NC}"
    log "Total de playbooks: ${#playbooks[@]}"
    log "${GREEN}Exitosos: $successful${NC}"
    log "${RED}Fallidos: $failed${NC}"
    log ""
    log "Archivos generados:"
    log "  - Log completo: $LOG_FILE"
    log "  - Resultados JSON: $RESULTS_FILE"
    log "  - Resumen: $SUMMARY_FILE"
    log ""
    
    # Mostrar playbooks fallidos si los hay
    if [ $failed -gt 0 ]; then
        log "${RED}=== PLAYBOOKS FALLIDOS ===${NC}"
        for result in "${results[@]}"; do
            if echo "$result" | jq -r '.result' | grep -q "FAILED"; then
                local failed_playbook=$(echo "$result" | jq -r '.playbook')
                log "  - $failed_playbook"
            fi
        done
    fi
    
    log "\n${BLUE}=== EJECUCIÓN COMPLETADA ===${NC}"
    
    # Retornar código de salida apropiado
    if [ $failed -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Verificar dependencias
check_dependencies() {
    local missing_deps=()
    
    if ! command -v ansible-playbook &> /dev/null; then
        missing_deps+=("ansible-playbook")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "${RED}Error: Faltan las siguientes dependencias:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Instalar con:"
        echo "  brew install ansible jq  # macOS"
        echo "  apt-get install ansible jq  # Ubuntu/Debian"
        echo "  yum install ansible jq  # CentOS/RHEL"
        exit 1
    fi
}

# Punto de entrada
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_dependencies
    main "$@"
fi
