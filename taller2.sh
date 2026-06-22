#!/bin/bash

PIDS=()
SERVICIOS=()

listar_procesos() {
    read -p "Ingrese nombre de usuario (o * para todos): " usuario

    if [ "$usuario" = "*" ]; then
        ps -e -o pid,user,comm > procesos.txt
    else
        if ! id "$usuario" >/dev/null 2>&1; then
            echo "El usuario '$usuario' no existe."
            return 1
        fi
        ps -u "$usuario" -o pid,user,comm > procesos.txt
    fi

    PIDS=()
    contador=1
    primera=1
    > listado.txt

    while read -r pid user comm; do
        # La primera linea es la cabecera (PID USER COMMAND), la saltamos
        if [ $primera -eq 1 ]; then
            primera=0
            continue
        fi
        PIDS[contador]=$pid
        echo "$contador) PID=$pid USER=$user CMD=$comm" >> listado.txt
        contador=$((contador+1))
    done < procesos.txt

    # Mostramos el listado pagina a pagina
    less listado.txt
    rm -f procesos.txt listado.txt
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

    # Listamos todos los servicios instalados en el sistema
    systemctl list-unit-files --type=service --no-legend --no-pager > unidades.txt

    SERVICIOS=()
    contador=1
    > listado.txt

    # Recorremos cada servicio instalado y dejamos solo los que NO estan corriendo
    while read -r servicio estado resto; do
        if ! systemctl is-active "$servicio" >/dev/null 2>&1; then
            SERVICIOS[contador]=$servicio
            echo "$contador) SERVICIO=$servicio ESTADO=$estado" >> listado.txt
            contador=$((contador+1))
        fi
    done < unidades.txt

    if [ $contador -eq 1 ]; then
        echo "No hay servicios detenidos para mostrar."
        rm -f unidades.txt listado.txt
        return 1
    fi

    # Mostramos el listado pagina a pagina
    less listado.txt
    rm -f unidades.txt listado.txt
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
