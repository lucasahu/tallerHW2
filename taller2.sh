#!/bin/bash

PIDS=()
SERVICIOS=()

listar_procesos() {
    read -p "Ingrese nombre de usuario (o * para todos): " usuario

    if [ "$usuario" = "*" ]; then
        salida=$(ps -e -o pid=,user=,comm=)
    else
        if ! id "$usuario" >/dev/null 2>&1; then
            echo "El usuario '$usuario' no existe."
            return 1
        fi
        salida=$(ps -u "$usuario" -o pid=,user=,comm=)
    fi

    PIDS=()
    listado=""
    contador=1

    while read -r pid user comm; do
        PIDS[contador]=$pid
        listado+="$contador) PID=$pid USER=$user CMD=$comm"$'\n'
        contador=$((contador+1))
    done <<< "$salida"

    # Paginar el listado ya construido
    echo "$listado" | less
}

matar_proceso() {
    if [ ${#PIDS[@]} -eq 0 ]; then
        echo "Primero debe listar procesos (opción 1)."
        return 1
    fi

    read -p "Ingrese el número secuencial del proceso a matar: " num

    case "$num" in
        *[!0-9]*|"")
            echo "Número inválido."
            return 1
            ;;
    esac

    if [ -z "${PIDS[$num]}" ]; then
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
    if ! which systemctl >/dev/null 2>&1; then
        echo "Este sistema no tiene systemctl."
        return 1
    fi

    salida=$(systemctl list-units --all --type=service --state=inactive,failed --no-legend --no-pager)

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
    if [ ${#SERVICIOS[@]} -eq 0 ]; then
        echo "Primero debe listar servicios (opcion 3)."
        return 1
    fi

    read -p "Ingrese el numero secuencial del servicio a activar: " num

    case "$num" in
        *[!0-9]*|"")
            echo "Numero invalido."
            return 1
            ;;
    esac

    if [ -z "${SERVICIOS[$num]}" ]; then
        echo "Numero invalido."
        return 1
    fi

    if systemctl start "${SERVICIOS[$num]}"; then
        echo "Servicio ${SERVICIOS[$num]} activado correctamente."
    else
        echo "No se pudo activar el servicio ${SERVICIOS[$num]}."
        echo "Puede que necesite ejecutar el script con sudo."
        return 1
    fi
}

PS3=" PS3 Este es el prompt automático del menú de opciones "

opciones=("Listar procesos por usuario" "Matar proceso por numero" "Listar servicios que no estan corriendo" "Activar servicio por numero" "Salir")  # vector con lista de opciones a mostrar

select opc in "${opciones[@]}"
do
   case $opc in
    "Listar procesos por usuario")
       listar_procesos

       ;;  # Fin opción 1
     "Matar proceso por numero")
       matar_proceso

       ;;
     "Listar servicios que no estan corriendo")
       listar_servicios

       ;;
     "Activar servicio por numero")
       activar_servicio

       ;;
     "Salir")
	echo "Finalizamos el menú con un break"
	break
	;;
      *)
	      echo "opcionalmente podemos usar esto usa una opción incorrecta (else) "
	;;
     esac 	#  fin al case (case al réves)
done
