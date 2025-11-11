#!/bin/bash

# Script avanzado para ejecutar playbooks con opciones adicionales
# Permite ejecutar playbooks individuales, por categoría, o todos
# Incluye opciones de dry-run, verbose, y filtrado

set -e

# Configuración
PLAYBOOKS_DIR="playbooks"
LOG_DIR="logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables por defecto
DRY_RUN=false
VERBOSE=false
FILTER=""
CATEGORY=""
SINGLE_PLAYBOOK=""
PARALLEL=false
MAX_PARALLEL=3

# Función de ayuda
show_help() {
    echo -e "${BLUE}Script Avanzado para Ejecutar Playbooks de Ansible${NC}"
    echo ""
    echo "Uso: $0 [OPCIONES]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help              Mostrar esta ayuda"
    echo "  -d, --dry-run           Ejecutar en modo dry-run (solo verificar)"
    echo "  -v, --verbose           Modo verbose (más información)"
    echo "  -f, --filter PATTERN    Filtrar playbooks por patrón"
    echo "  -c, --category CAT      Ejecutar solo playbooks de una categoría"
    echo "  -s, --single PLAYBOOK   Ejecutar un solo playbook"
    echo "  -p, --parallel          Ejecutar en paralelo (máximo $MAX_PARALLEL)"
    echo "  --max-parallel NUM      Máximo número de playbooks en paralelo (default: $MAX_PARALLEL)"
    echo ""
    echo "Categorías disponibles:"
    echo "  - device_*              Playbooks relacionados con dispositivos"
    echo "  - network_*             Playbooks relacionados con redes"
    echo "  - organization_*         Playbooks relacionados con organizaciones"
    echo "  - admin_*               Playbooks de administración"
    echo ""
    echo "Ejemplos:"
    echo "  $0                                    # Ejecutar todos los playbooks"
    echo "  $0 -d                                # Dry-run de todos los playbooks"
    echo "  $0 -f device                         # Solo playbooks que contengan 'device'"
    echo "  $0 -c device                         # Solo playbooks de dispositivos"
    echo "  $0 -s device_info.yml                # Solo un playbook específico"
    echo "  $0 -p --max-parallel 5               # Ejecutar en paralelo (máximo 5)"
    echo "  $0 -v -f network                     # Verbose con filtro de red"
}

# Función para obtener playbooks por categoría
get_playbooks_by_category() {
    local category=$1
    case $category in
        "device")
            find "$PLAYBOOKS_DIR" -name "*device*" -name "*.yml" -o -name "*device*" -name "*.yaml" | grep -v "hosts"
            ;;
        "network")
            find "$PLAYBOOKS_DIR" -name "*network*" -name "*.yml" -o -name "*network*" -name "*.yaml" | grep -v "hosts"
            ;;
        "organization")
            find "$PLAYBOOKS_DIR" -name "*organization*" -name "*.yml" -o -name "*organization*" -name "*.yaml" | grep -v "hosts"
            ;;
        "admin")
            find "$PLAYBOOKS_DIR" -name "*admin*" -name "*.yml" -o -name "*admin*" -name "*.yaml" | grep -v "hosts"
            ;;
        *)
            echo -e "${RED}Error: Categoría '$category' no válida${NC}"
            echo "Categorías disponibles: device, network, organization, admin"
            exit 1
            ;;
    esac
}

# Función para obtener playbooks filtrados
get_filtered_playbooks() {
    local filter=$1
    find "$PLAYBOOKS_DIR" -name "*${filter}*" -name "*.yml" -o -name "*${filter}*" -name "*.yaml" | grep -v "hosts"
}

# Función para ejecutar un playbook
execute_single_playbook() {
    local playbook=$1
    local playbook_path="${PLAYBOOKS_DIR}/${playbook}"
    local start_time=$(date +%s)
    local result=""
    local exit_code=0
    
    echo -e "${YELLOW}=== Ejecutando: $playbook ===${NC}"
    echo "Inicio: $(date)"
    
    # Construir comando ansible-playbook
    local ansible_cmd="ansible-playbook -i ${PLAYBOOKS_DIR}/hosts $playbook_path"
    
    if [ "$DRY_RUN" = true ]; then
        ansible_cmd="$ansible_cmd --check"
    fi
    
    if [ "$VERBOSE" = true ]; then
        ansible_cmd="$ansible_cmd -vvv"
    fi
    
    # Ejecutar el playbook
    if eval "$ansible_cmd"; then
        result="SUCCESS"
        echo -e "${GREEN}✓ $playbook ejecutado exitosamente${NC}"
    else
        exit_code=$?
        result="FAILED"
        echo -e "${RED}✗ $playbook falló con código de salida: $exit_code${NC}"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "Fin: $(date)"
    echo "Duración: ${duration}s"
    echo -e "${YELLOW}=== Fin de $playbook ===${NC}\n"
    
    return $exit_code
}

# Función para ejecutar playbooks en paralelo
execute_parallel() {
    local playbooks=("$@")
    local pids=()
    local results=()
    
    echo -e "${BLUE}Ejecutando ${#playbooks[@]} playbooks en paralelo (máximo $MAX_PARALLEL)${NC}"
    
    for i in "${!playbooks[@]}"; do
        local playbook="${playbooks[$i]}"
        local playbook_name=$(basename "$playbook")
        
        # Esperar si hemos alcanzado el máximo de procesos paralelos
        while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
            sleep 1
        done
        
        # Ejecutar playbook en background
        execute_single_playbook "$playbook_name" &
        pids+=($!)
        
        echo -e "${CYAN}Iniciado: $playbook_name (PID: ${pids[-1]})${NC}"
    done
    
    # Esperar a que terminen todos los procesos
    echo -e "${BLUE}Esperando a que terminen todos los playbooks...${NC}"
    for pid in "${pids[@]}"; do
        wait $pid
        results+=($?)
    done
    
    # Mostrar resumen
    local successful=0
    local failed=0
    
    for result in "${results[@]}"; do
        if [ $result -eq 0 ]; then
            ((successful++))
        else
            ((failed++))
        fi
    done
    
    echo -e "\n${BLUE}=== RESUMEN PARALELO ===${NC}"
    echo "Total: ${#playbooks[@]}"
    echo -e "${GREEN}Exitosos: $successful${NC}"
    echo -e "${RED}Fallidos: $failed${NC}"
}

# Función para listar playbooks disponibles
list_playbooks() {
    echo -e "${BLUE}=== PLAYBOOKS DISPONIBLES ===${NC}"
    
    if [ -n "$CATEGORY" ]; then
        echo -e "${YELLOW}Categoría: $CATEGORY${NC}"
        get_playbooks_by_category "$CATEGORY" | while read -r playbook; do
            echo "  - $(basename "$playbook")"
        done
    elif [ -n "$FILTER" ]; then
        echo -e "${YELLOW}Filtro: $FILTER${NC}"
        get_filtered_playbooks "$FILTER" | while read -r playbook; do
            echo "  - $(basename "$playbook")"
        done
    else
        find "$PLAYBOOKS_DIR" -name "*.yml" -o -name "*.yaml" | grep -v "hosts" | while read -r playbook; do
            echo "  - $(basename "$playbook")"
        done
    fi
    echo ""
}

# Función principal
main() {
    # Crear directorio de logs
    mkdir -p "$LOG_DIR"
    
    # Determinar qué playbooks ejecutar
    local playbooks=()
    
    if [ -n "$SINGLE_PLAYBOOK" ]; then
        playbooks=("$SINGLE_PLAYBOOK")
    elif [ -n "$CATEGORY" ]; then
        while IFS= read -r playbook; do
            playbooks+=("$playbook")
        done < <(get_playbooks_by_category "$CATEGORY")
    elif [ -n "$FILTER" ]; then
        while IFS= read -r playbook; do
            playbooks+=("$playbook")
        done < <(get_filtered_playbooks "$FILTER")
    else
        while IFS= read -r playbook; do
            playbooks+=("$playbook")
        done < <(find "$PLAYBOOKS_DIR" -name "*.yml" -o -name "*.yaml" | grep -v "hosts")
    fi
    
    if [ ${#playbooks[@]} -eq 0 ]; then
        echo -e "${YELLOW}No se encontraron playbooks para ejecutar${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}=== CONFIGURACIÓN ===${NC}"
    echo "Playbooks a ejecutar: ${#playbooks[@]}"
    echo "Modo dry-run: $DRY_RUN"
    echo "Modo verbose: $VERBOSE"
    echo "Ejecución paralela: $PARALLEL"
    if [ "$PARALLEL" = true ]; then
        echo "Máximo paralelo: $MAX_PARALLEL"
    fi
    echo ""
    
    # Mostrar playbooks que se van a ejecutar
    echo -e "${YELLOW}Playbooks a ejecutar:${NC}"
    for playbook in "${playbooks[@]}"; do
        echo "  - $(basename "$playbook")"
    done
    echo ""
    
    # Confirmar ejecución
    if [ "$DRY_RUN" = false ]; then
        read -p "¿Continuar con la ejecución? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Ejecución cancelada${NC}"
            exit 0
        fi
    fi
    
    # Ejecutar playbooks
    if [ "$PARALLEL" = true ]; then
        execute_parallel "${playbooks[@]}"
    else
        local successful=0
        local failed=0
        
        for playbook in "${playbooks[@]}"; do
            local playbook_name=$(basename "$playbook")
            if execute_single_playbook "$playbook_name"; then
                ((successful++))
            else
                ((failed++))
            fi
        done
        
        echo -e "\n${BLUE}=== RESUMEN FINAL ===${NC}"
        echo "Total: ${#playbooks[@]}"
        echo -e "${GREEN}Exitosos: $successful${NC}"
        echo -e "${RED}Fallidos: $failed${NC}"
    fi
}

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--filter)
            FILTER="$2"
            shift 2
            ;;
        -c|--category)
            CATEGORY="$2"
            shift 2
            ;;
        -s|--single)
            SINGLE_PLAYBOOK="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        --max-parallel)
            MAX_PARALLEL="$2"
            shift 2
            ;;
        --list)
            list_playbooks
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Opción desconocida '$1'${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Verificar dependencias
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}Error: ansible-playbook no está instalado${NC}"
    exit 1
fi

# Ejecutar función principal
main
