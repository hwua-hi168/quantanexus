# Scripts para Ejecutar Playbooks de Ansible

Este directorio contiene scripts para ejecutar todos los playbooks de Ansible y rastrear su estado de ejecución.

## Scripts Disponibles

### 1. `run_all_playbooks.sh` - Script Básico
Ejecuta todos los playbooks de forma secuencial y genera reportes detallados.

**Características:**
- Ejecuta todos los playbooks en orden
- Genera logs detallados
- Crea archivos JSON con resultados
- Muestra resumen final con estadísticas
- Modo dry-run por defecto (solo verificación)

**Uso:**
```bash
./run_all_playbooks.sh
```

### 2. `run_playbooks_advanced.sh` - Script Avanzado
Script más flexible con múltiples opciones de ejecución.

**Características:**
- Ejecución secuencial o paralela
- Filtrado por categorías o patrones
- Modo dry-run y verbose
- Ejecución de playbooks individuales
- Control de concurrencia

**Opciones disponibles:**
```bash
# Mostrar ayuda
./run_playbooks_advanced.sh --help

# Ejecutar todos los playbooks
./run_playbooks_advanced.sh

# Modo dry-run (solo verificar)
./run_playbooks_advanced.sh --dry-run

# Modo verbose
./run_playbooks_advanced.sh --verbose

# Filtrar por patrón
./run_playbooks_advanced.sh --filter device

# Ejecutar por categoría
./run_playbooks_advanced.sh --category device

# Ejecutar un solo playbook
./run_playbooks_advanced.sh --single device_info.yml

# Ejecución paralela
./run_playbooks_advanced.sh --parallel --max-parallel 5

# Listar playbooks disponibles
./run_playbooks_advanced.sh --list
```

## Categorías de Playbooks

Los playbooks están organizados por categorías:

- **device_*** - Playbooks relacionados con dispositivos
- **network_*** - Playbooks relacionados con redes  
- **organization_*** - Playbooks relacionados con organizaciones
- **admin_*** - Playbooks de administración

## Archivos Generados

Los scripts generan los siguientes archivos en el directorio `logs/`:

- **`playbooks_execution_TIMESTAMP.log`** - Log completo de la ejecución
- **`playbooks_results_TIMESTAMP.json`** - Resultados en formato JSON
- **`playbooks_summary_TIMESTAMP.txt`** - Resumen ejecutivo

## Dependencias

Los scripts requieren las siguientes herramientas:

- `ansible-playbook` - Para ejecutar los playbooks
- `jq` - Para procesar JSON (solo en el script básico)

**Instalación:**
```bash
# macOS
brew install ansible jq

# Ubuntu/Debian
apt-get install ansible jq

# CentOS/RHEL
yum install ansible jq
```

## Ejemplos de Uso

### Ejecutar todos los playbooks
```bash
./run_all_playbooks.sh
```

### Verificar todos los playbooks (dry-run)
```bash
./run_playbooks_advanced.sh --dry-run
```

### Ejecutar solo playbooks de dispositivos
```bash
./run_playbooks_advanced.sh --category device
```

### Ejecutar playbooks que contengan "network" en el nombre
```bash
./run_playbooks_advanced.sh --filter network
```

### Ejecutar en paralelo con máximo 3 procesos
```bash
./run_playbooks_advanced.sh --parallel --max-parallel 3
```

### Ejecutar un playbook específico con verbose
```bash
./run_playbooks_advanced.sh --single device_info.yml --verbose
```

## Interpretación de Resultados

### Códigos de Salida
- **0** - Todos los playbooks se ejecutaron exitosamente
- **1** - Algunos playbooks fallaron

### Estados de Playbooks
- **SUCCESS** - Playbook ejecutado exitosamente
- **FAILED** - Playbook falló durante la ejecución

### Archivos de Log
Los logs contienen información detallada sobre:
- Tiempo de inicio y fin de cada playbook
- Duración de ejecución
- Mensajes de error (si los hay)
- Resultado final de cada playbook

## Troubleshooting

### Error: "ansible-playbook no está instalado"
```bash
# Instalar Ansible
pip install ansible
# o
brew install ansible  # macOS
```

### Error: "jq no está instalado"
```bash
# Instalar jq
brew install jq  # macOS
apt-get install jq  # Ubuntu/Debian
```

### Error: "El directorio playbooks no existe"
Verificar que estás ejecutando el script desde el directorio raíz del proyecto.

### Error: "No se encontraron playbooks"
Verificar que existen archivos `.yml` o `.yaml` en el directorio `playbooks/`.

## Personalización

### Modificar el archivo de hosts
Los scripts usan `playbooks/hosts` como archivo de inventario. Asegúrate de que este archivo esté configurado correctamente.

### Cambiar el directorio de logs
Modifica la variable `LOG_DIR` en los scripts para cambiar el directorio donde se guardan los logs.

### Ajustar el máximo de procesos paralelos
Usa la opción `--max-parallel` para controlar cuántos playbooks se ejecutan simultáneamente.
