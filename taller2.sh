#!/bin/bash
 
PIDS=()
SERVICIOS=()
 
listar_procesos() {
    : # TODO Issue #2
}
 
matar_proceso() {
    : # TODO Issue #3
}
 
listar_servicios() {
    : # TODO Issue #4
}
 
activar_servicio() {
    : # TODO Issue #5
}
 
while true; do
    read -p "Opción [1-5]: " opcion
    case "$opcion" in
        1) listar_procesos ;;
        2) matar_proceso ;;
        3) listar_servicios ;;
        4) activar_servicio ;;
        5) break ;;
        *) ;;
    esac
done
