# tallerHW2
taller de hardware y os v2
# Enunciado
Realice un Shell que corra en BASH que muestre un menú con las siguientes opciones:
1. Permita ingresar el nombre de un usuario o bien un “*” y liste página a página los procesos que están
corriendo que pertenezcan a dicho usuario. En el caso de ser un “*” muestre todos los procesos.
2. El listado anterior deberá ir enumerado con un número secuencial (no por su PID). Ésta opción pedirá
el número secuencial y permitirá “Matar” el proceso
3. Esta opción deberá mostrar todos los servicios instalados en el sistema que NO están corriendo (ya
sea porque no están habilitado en el nivel de ejecución actual o porque los bajaron). Al igual que en el
caso anterior este listado deberá mostrar el listado enumerado en orden secuencial.
4. Esta opción permitirá dado el número secuencial de un proceso listado en el punto anterior (no su
nombre) , activar el servicio seleccionado.
5. Opción para finalizar el script (Salir).
# Grupo de trabajo
Se deberá desarrollar en los mismos grupos del taller anterior.
# Entrega
 Se podrá entregar hasta las 10:00 horas del día martes 23 de junio. Dicho día y el miércoles 24 se realizará la
interrogación al grupo.
# Estructura proyecto
# Variables globales compartidas (cada función las llena o las lee)
PIDS=()        # PIDS[1]=1234 → mapeo secuencial→PID (opción 1 lo llena, opción 2 lo lee)
SERVICIOS=()   # SERVICIOS[1]="cups.service" → secuencial→servicio (opción 3 llena, opción 4 lee)
# Funciones (cada una autocontenida):
listar_procesos()    # opción 1
matar_proceso()      # opción 2
listar_servicios()   # opción 3
activar_servicio()   # opción 4
