#!/bin/bash
 
PIDS=()
SERVICIOS=()
 
listar_procesos() {
    read -p "Ingrese nombre de usuario (o * para todos): " usuario
 
    # Elegir el comando ps según la entrada
    if [ "$usuario" = "*" ]; then
        salida=$(ps -e -o pid=,user=,comm=)
    else
        # Validar que el usuario exista antes de listar
        if ! id "$usuario" &>/dev/null; then
            echo "El usuario '$usuario' no existe."
            return 1
        fi
        salida=$(ps -u "$usuario" -o pid=,user=,comm=)
    fi
 
    # Reiniciar el mapeo (un listado nuevo invalida el anterior)
    PIDS=()
    local listado=""
    local contador=1
 
    # Leer línea por línea SIN pipe para no perder PIDS en un subshell
    while read -r pid user comm; do
        PIDS[contador]=$pid
        listado+="$contador) PID=$pid USER=$user CMD=$comm"$'\n'
        contador=$((contador+1))
    done <<< "$salida"
 
    # Paginar el listado ya construido
    echo "$listado" | less
}
 
matar_proceso() {
    # Sin listado previo no hay mapeo secuencial→PID
    if [ ${#PIDS[@]} -eq 0 ]; then
        echo "Primero debe listar procesos (opción 1)."
        return 1
    fi
 
    read -p "Ingrese el número secuencial del proceso a matar: " num
 
    # Validar que sea un número y que exista en el mapeo
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ -z "${PIDS[$num]}" ]; then
        echo "Número inválido."
        return 1
    fi
 
    if kill "${PIDS[$num]}" 2>/dev/null; then
        echo "Proceso ${PIDS[$num]} (n°$num) terminado con SIGTERM."
    else
        echo "No se pudo matar el proceso ${PIDS[$num]} (¿permisos? ¿ya no existe?)."
        return 1
    fi
}
 
listar_servicios() {
    if ! command -v systemctl &>/dev/null; then
        echo "Este sistema no tiene systemctl."
        return 1
    fi

    salida=$(systemctl list-units --all --type=service --state=inactive --no-legend --no-pager)

    if [ -z "$salida" ]; then
        echo "No hay servicios detenidos para mostrar."
        return 1
    fi

    SERVICIOS=()
    listado=""
    contador=1

    while read -r servicio carga activo sub descripcion; do
        SERVICIOS[contador]=$servicio
        listado+="$contador) SERVICIO=$servicio ESTADO=$activo/$sub DESCRIPCION=$descripcion"$'\n'
        contador=$((contador+1))
    done <<< "$salida"

    echo "$listado" | less
}
 
activar_servicio() {
    : # TODO Issue #5
}
 
while true; do
    echo ""
    echo "===== MENU PRINCIPAL ====="
    echo "1) Listar procesos por usuario"
    echo "2) Matar proceso por numero"
    echo "3) Listar servicios que no estan corriendo"
    echo "4) Activar servicio por numero"
    echo "5) Salir"
    echo ""

    read -p "Ingrese una opcion [1-5]: " opcion

    case "$opcion" in
        1)
            listar_procesos
            ;;
        2)
            matar_proceso
            ;;
        3)
            listar_servicios
            ;;
        4)
            activar_servicio
            ;;
        5)
            echo "Saliendo del script..."
            break
            ;;
        *)
            echo "Opcion invalida. Intente nuevamente."
            ;;
    esac
done
