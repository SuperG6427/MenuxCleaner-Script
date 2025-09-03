#!/bin/bash
# MenuxCleaner
# Autor: SL2705
# Descripcion: Limpiador de cache de memoria RAM en Linux con menu interactivo.

# Configuracion de colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# Configuracion
VERSION="0.8"
LAST_CLEAN="Nunca"
CLEAN_COUNT=0

# Animacion de Spinner
spinner() {
    local pid=$!
    local spin='-\|/'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r⏳ Progreso: ${spin:$i:1}"
        sleep 0.2
    done
    printf "\r"
}

# Mostrar historial de limpiezas
show_log() {
    clear
    echo -e "${BLUE}=======================================================${NC}"
    echo -e "${WHITE}${BOLD}HISTORIAL DE LIMPIEZAS${NC}"
    echo -e "${BLUE}=======================================================${NC}"
    echo
    if [ -f ~/.menuxcleaner.log ]; then
        cat ~/.menuxcleaner.log
    else
        echo -e "${YELLOW} No hay registros de limpieza.${NC}"
    fi
    echo
    read -p "Presiona ENTER para volver al menu..."
}


# Verificar permisos sudo
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}Se requieren permisos de administrador${NC}"
        sudo echo -e "${BLUE}Autenticando...${NC}" || {
            echo -e "${RED}Error: No se pudieron obtener permisos de administrador${NC}"
            exit 1
        }
    fi
}

# Mostrar memoria actual con detalles
show_memory() {
    echo -e "${BLUE}==============================================================${NC}"
    echo -e "${WHITE}${BOLD}Estado actual de memoria:${NC}"
    echo -e "${BLUE}--------------------------------------------------------------${NC}"
    free -h | awk '
        NR==2{printf "RAM Usada: %s | Libre: %s | Total: %s | Cache: %s\n", $3, $4, $2, $6}
        NR==3{printf "Swap Usada: %s | Libre: %s | Total: %s\n", $3, $4, $2}'
    
    # Mostrar porcentaje de uso con color según el nivel
    local mem_info=$(free | awk 'NR==2{printf "%.0f", $3/$2 * 100}')
    local color=$GREEN
    if [ $mem_info -gt 70 ]; then
        color=$YELLOW
    fi
    if [ $mem_info -gt 85 ]; then
        color=$RED
    fi
    echo -e "Uso de RAM: ${color}${mem_info}%${NC}"
    
    # Barra de progreso visual con colores
    echo -n "["
    for ((i=0; i<50; i++)); do
        if [ $i -lt $((mem_info/2)) ]; then
            if [ $mem_info -gt 85 ]; then
                echo -ne "${RED}#${NC}"
            elif [ $mem_info -gt 70 ]; then
                echo -ne "${YELLOW}#${NC}"
            else
                echo -ne "${GREEN}#${NC}"
            fi
        else
            echo -n "-"
        fi
    done
    echo "]"
    echo -e "${BLUE}==============================================================${NC}"
    echo
}

# Limpiar caches con validaciones
clean_cache() {
    local option=$1
    local result=1
    
    # Sincronizar sistemas de archivos
    sync
    sync
    
    # Pausa para operaciones pendientes
    sleep 0.5
    
    case $option in
        1) echo 1 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 && result=0 ;;
        2) echo 2 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 && result=0 ;;
        3) echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 && result=0 ;;
        4) echo 1 | sudo tee /proc/sys/vm/compact_memory > /dev/null 2>&1 && result=0 ;;
        5) sudo swapoff -a && sudo swapon -a && result=0 ;;  # Limpiar swap
    esac
    
    # Pausa para que el kernel procese
    sleep 0.5
    return $result
}

# Mostrar advertencia sobre uso excesivo
show_warning() {
    if [ $CLEAN_COUNT -gt 3 ]; then
        echo -e "${YELLOW}========================================================${NC}"
        echo -e "${YELLOW}ADVERTENCIA: Has realizado $CLEAN_COUNT limpiezas.${NC}"
        echo -e "${YELLOW}El exceso de limpieza puede reducir el rendimiento.${NC}"
        echo -e "${YELLOW}========================================================${NC}"
        echo
    fi
}

# Mostrar informacion del sistema
show_system_info() {
    echo -e "${CYAN}Sistema: $(hostname) | Kernel: $(uname -r)${NC}"
    echo -e "${CYAN}Ultima limpieza: $LAST_CLEAN${NC}"
    echo -e "${CYAN}Limpiezas totales: $CLEAN_COUNT${NC}"
    echo -e "${BLUE}==============================================================${NC}"
}

# Ejecutar limpieza con progreso
execute_cleaning() {
    local choice=$1
    local option_name=""
    local memory_before=$(free | awk 'NR==2{print $7}')
    
    case $choice in
        1) option_name="PageCache" ;;
        2) option_name="Dentries e Inodes" ;;
        3) option_name="Limpieza completa" ;;
        4) option_name="Compactacion de memoria" ;;
        5) option_name="Limpiar memoria Swap" ;;
    esac
    
    echo -e "${BLUE}Ejecutando: $option_name${NC}"
    echo -ne "${YELLOW}Progreso: ${NC}"
    
    # Animacion de progreso
    (clean_cache "$choice") & spinner
    wait

    
        if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK] Limpieza completada exitosamente${NC}"
        
        # Mostrar diferencia de memoria liberada
        local memory_after=$(free | awk 'NR==2{print $7}')
        local memory_freed=$(( (memory_after - memory_before) / 1024 ))
        
        if [ $memory_freed -gt 0 ]; then
        echo -e "${GREEN}Memoria liberada: ${memory_freed} MB${NC}"
        else
        echo -e "${YELLOW}Nota: Poca memoria liberada (puede ser normal)${NC}"
        fi
        
        # Actualizar estadisticas
        LAST_CLEAN=$(date '+%Y-%m-%d %H:%M:%S')
        CLEAN_COUNT=$((CLEAN_COUNT + 1))
        
        # Guardar log en el home del usuario
        echo "$(date '+%F %T') | $option_name | Liberado: ${memory_freed} MB" >> ~/.menuxcleaner.log
        
    else
        echo -e "${RED}[ERROR] Problema durante la limpieza${NC}"
        echo -e "${YELLOW}Comprueba que tienes los permisos adecuados${NC}"
    fi
    echo
}

# Mostrar informacion y recomendaciones
show_recommendations() {
    clear
    echo -e "${BLUE}========================================================${NC}"
    echo -e "${WHITE}${BOLD}INFORMACION Y RECOMENDACIONES${NC}"
    echo -e "${BLUE}========================================================${NC}"
    echo
    echo -e "${CYAN}¿Por que Linux usa memoria como cache?${NC}"
    echo "  Linux utiliza memoria RAM no utilizada para almacenar"
    echo "  en cache datos de disco, lo que acelera el acceso."
    echo
    echo -e "${CYAN}¿Cuando debo limpiar la memoria?${NC}"
    echo -e "  - ${GREEN}Antes de ejecutar aplicaciones que requieren mucha memoria${NC}"
    echo -e "  - ${YELLOW}Cuando el sistema se vuelve lento después de mucho uso${NC}"
    echo -e "  - ${RED}En sistemas con poca RAM (< 4GB)${NC}"
    echo
    echo -e "${RED}${BOLD}ADVERTENCIAS:${NC}"
    echo -e "  - ${RED}La limpieza excesiva puede REDUCIR el rendimiento${NC}"
    echo -e "  - ${YELLOW}El kernel libera memoria automaticamente cuando es necesario${NC}"
    echo -e "  - ${GREEN}La memoria en cache se considera 'disponible' para aplicaciones${NC}"
    echo
    read -p "Presiona ENTER para volver al menu..." 
}

# Menu interactivo
check_sudo

while true; do
    clear
    echo -e "${MAGENTA}========================================================${NC}"
    echo -e "${WHITE}${BOLD}            MenuxCleaner            v$VERSION${NC}"
    echo -e "${WHITE}            Autor: SL2705${NC}"
    echo -e "${MAGENTA}========================================================${NC}"
    
    show_system_info
    show_memory
    show_warning
    
    echo -e "${WHITE}${BOLD}SELECCIONE UNA OPCION:${NC}"
    echo -e " ${GREEN}1)${NC} Limpiar PageCache (opcion mas segura)"
    echo -e " ${YELLOW}2)${NC} Limpiar Dentries e Inodes"
    echo -e " ${RED}3)${NC} Limpieza COMPLETA (PageCache + Dentries + Inodes)"
    echo -e " ${BLUE}4)${NC} Compactar memoria (para sistemas fragmentados)"
    echo -e " ${MAGENTA}5)${NC} Limpiar memoria Swap"
    echo -e " ${CYAN}6)${NC} Informacion y recomendaciones"
    echo -e " ${WHITE}7)${NC} Ver historial de limpiezas"
    echo -e " ${RED}8)${NC} Salir"
    echo -e "${MAGENTA}========================================================${NC}"
    
    read -p "Opcion [1-7]: " opt

case $opt in
    1|2|3|4|5) 
        execute_cleaning "$opt"
        read -p "Presiona ENTER para continuar..." 
        ;;
    6) 
        show_recommendations
        ;;
    7)
        show_log
        ;;
    8) 
        echo -e "${GREEN}Saliendo de MenuxCleaner...${NC}"
        exit 0 
        ;;
    *) 
        echo -e "${RED}Opcion invalida${NC}"
        sleep 1 
        ;;
esac
done