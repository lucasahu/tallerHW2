# Explicación de `taller2.sh`

Este documento tiene dos partes:

1. **Conceptos de Bash** usados en el script (qué hace `read`, `case`, `select`, `<<<`, etc.).
2. **Recorrido bloque por bloque** del código real.

---

# Parte 1 — Conceptos de Bash

## El shebang `#!/bin/bash`
La primera línea de un script. Le dice al sistema operativo con qué intérprete ejecutar el archivo. `#!/bin/bash` = "córrelo con bash". Sin esto, si ejecutas `./taller2.sh`, el sistema podría usar otro shell (como `sh`/`dash`) donde cosas como `select`, los arreglos o `<<<` **no funcionan**.

## Variables y `$`
- `nombre=valor` crea una variable (sin espacios alrededor del `=`).
- `$nombre` o `${nombre}` lee su valor.
- Se usan comillas (`"$nombre"`) para evitar problemas si el valor tiene espacios o está vacío.

## `read`
Lee lo que el usuario escribe por teclado y lo guarda en una variable.
- `read -p "texto" var` → muestra "texto" como pregunta (`-p` = *prompt*) y guarda la respuesta en `var`.
- `read -r a b c` → lee una línea y la parte por espacios: la 1ª palabra a `a`, la 2ª a `b`, **el resto** a `c`. El `-r` evita que bash interprete las contrabarras `\`.

## Arreglos (arrays)
- `PIDS=()` crea un arreglo vacío (una lista).
- `PIDS[3]=8801` guarda un valor en la posición 3.
- `${PIDS[3]}` lee la posición 3.
- `${#PIDS[@]}` da la **cantidad** de elementos (el `#` significa "largo de").

## `if` y los corchetes `[ ]`
`[ ... ]` es una prueba (test) que da verdadero/falso. **Los espacios internos son obligatorios.** Operadores usados:
- `[ "$a" = "$b" ]` → ¿son iguales como texto?
- `[ -z "$a" ]` → ¿está vacío? (*zero length*).
- `[ "$n" -eq 0 ]` → ¿son iguales como número? (`-eq` = *equals*).
- `!` adelante invierte el resultado: `if ! comando` = "si el comando FALLÓ".

## Códigos de salida (`return` / `$?`)
En Linux todo comando devuelve un número: **0 = éxito, distinto de 0 = error**. Por eso podemos hacer `if comando; then ...` (entra si el comando tuvo éxito). `return 1` sale de una función con código de error.

## `case ... esac`
Es el `switch` de bash. Compara un valor contra varios patrones:
```bash
case "$x" in
    patron1) ordenes ;;
    patron2) ordenes ;;
    *)       ordenes ;;   # comodín: calza con todo
esac
```
- `;;` marca el fin de cada caso.
- `esac` es "case" escrito al revés y cierra el bloque.
- Los patrones usan comodines de archivo (globs), no expresiones regulares. Por ejemplo `*[!0-9]*` significa "cualquier texto que contenga **al menos un carácter que NO sea dígito**", y `""` calza con la entrada vacía. Juntos sirven para detectar que algo **no** es un número.

## `while ... done`
Repite un bloque mientras se cumpla una condición. En este script se usa para leer texto **línea por línea**:
```bash
while read -r ...; do
    ...
done <<< "$texto"
```

## Sustitución de comandos `$( )`
`var=$(comando)` ejecuta el comando y guarda **su salida (lo que imprimiría)** como texto en `var`.

## Here-string `<<<`
`comando <<< "$texto"` le entrega el contenido de `$texto` al comando como **entrada estándar (stdin)**, igual que si viniera de un archivo, pero sin crear ningún archivo. Lo usamos para alimentar el `while read` con el texto que capturamos antes.

### ¿Por qué `<<<` y no un pipe `|`?
Pregunta clásica de interrogación. Si hiciéramos `comando | while read ...`, bash ejecuta el `while` en un **subshell** (un proceso hijo aparte). El arreglo se llenaría dentro de ese hijo y, al terminar el pipe, el hijo muere y **se lleva el arreglo**: quedaría vacío en el script principal. Con `<<<` el loop corre en el **mismo** proceso, así que el arreglo sobrevive y la opción de matar/activar puede usarlo.

## Aritmética `$(( ))`
Para hacer cuentas: `contador=$((contador+1))`. Fuera de `$(( ))`, bash trataría `contador+1` como texto, no como suma.

## Redirección `>/dev/null 2>&1`
- `>` manda la salida normal de un comando a un archivo. `/dev/null` es un "agujero negro" que descarta todo.
- `2>&1` manda también los errores (canal 2) al mismo lugar.
- Resultado: ejecutamos el comando en silencio porque solo nos importa **si tuvo éxito o no**, no lo que imprime.

## `select` y `PS3` (el menú)
`select` construye automáticamente un **menú numerado** a partir de una lista y repite hasta que se le indique salir:
```bash
PS3="Elija una opción: "
select opc in "${opciones[@]}"; do
    case $opc in
        ...
    esac
done
```
- `select` imprime cada elemento de la lista con un número delante.
- `PS3` es el texto que `select` muestra como pregunta.
- Lo que el usuario elige queda en `opc` (el texto de la opción); el número que tecleó queda en `$REPLY`.
- Se repite en loop hasta encontrar un `break`.

## Comandos del sistema usados
- `ps` → lista los procesos. `-e` = todos; `-u usuario` = los de un usuario; `-o pid=,user=,comm=` = mostrar solo esas columnas, y el `=` tras cada una **borra el encabezado** (la línea de títulos).
- `id usuario` → da información de un usuario; **falla** si el usuario no existe (lo aprovechamos para validar).
- `kill PID` → manda la señal SIGTERM (terminación ordenada) a un proceso. `kill -9` sería SIGKILL (muerte inmediata).
- `which comando` → indica si un comando está instalado.
- `systemctl` → administra servicios:
  - `list-unit-files --type=service` → lista **todos los servicios instalados**.
  - `is-active servicio` → dice si está corriendo (éxito) o no (error).
  - `start servicio` → lo arranca.
- `less` → **paginador**: muestra texto página por página (espacio/flechas para avanzar, `q` para salir).
- `--no-legend` y `--no-pager` → le piden a `systemctl` que no imprima encabezados ni use su propio paginador.

---

# Parte 2 — Recorrido bloque por bloque

## Cabecera

```bash
#!/bin/bash

PIDS=()
SERVICIOS=()
```
Shebang + dos arreglos vacíos **globales**. Son el "puente" entre opciones:
- La opción 1 llena `PIDS` → la opción 2 lo lee para saber qué proceso matar.
- La opción 3 llena `SERVICIOS` → la opción 4 lo lee para saber qué servicio activar.

---

## `listar_procesos` (opción 1)

```bash
read -p "Ingrese nombre de usuario (o * para todos): " usuario
```
Pide el usuario y lo guarda en `usuario`.

```bash
if [ "$usuario" = "*" ]; then
    salida=$(ps -e -o pid=,user=,comm=)
```
Si escribió `*`, captura **todos** los procesos. El `-o pid=,user=,comm=` muestra solo PID, usuario y comando, sin encabezado.

```bash
else
    if ! id "$usuario" >/dev/null 2>&1; then
        echo "El usuario '$usuario' no existe."
        return 1
    fi
    salida=$(ps -u "$usuario" -o pid=,user=,comm=)
fi
```
Si no escribió `*`, primero **valida** que el usuario exista: `id usuario` falla si no existe, y `! ... ` detecta esa falla; en ese caso avisa y vuelve al menú. Si existe, captura solo los procesos de ese usuario con `-u`.

```bash
PIDS=()
listado=""
contador=1
```
Reinicia el arreglo (cada listado nuevo invalida el anterior), prepara el texto a mostrar y el número secuencial que empieza en 1.

```bash
while read -r pid user comm; do
    PIDS[contador]=$pid
    listado+="$contador) PID=$pid USER=$user CMD=$comm"$'\n'
    contador=$((contador+1))
done <<< "$salida"
```
Recorre la salida de `ps` **línea por línea** (alimentada con `<<<`). En cada línea:
- `PIDS[contador]=$pid` → **la línea clave**: guarda el PID real en la posición secuencial. Si el n°3 del listado es el PID 8801, queda `PIDS[3]=8801`. Así el usuario usa números y nosotros sabemos el PID.
- Arma la línea visible (ej. `3) PID=8801 USER=lucas CMD=firefox`) y la agrega a `listado` (`$'\n'` es un salto de línea).
- Sube el contador.

```bash
echo "$listado" | less
```
Con el arreglo ya lleno y el texto armado, lo muestra página a página con `less`. Aquí el pipe no causa problema porque ya no estamos llenando ningún arreglo.

---

## `matar_proceso` (opción 2)

```bash
if [ ${#PIDS[@]} -eq 0 ]; then
    echo "Primero debe listar procesos (opción 1)."
    return 1
fi
```
Si el arreglo está vacío, es que nunca se corrió la opción 1: no hay mapeo número→PID, así que avisa y vuelve.

```bash
read -p "Ingrese el número secuencial del proceso a matar: " num

case "$num" in
    *[!0-9]*|"")
        echo "Número inválido."
        return 1
        ;;
esac
```
Pide el número y valida que sea realmente un número: `*[!0-9]*` calza si contiene algún carácter no-dígito, y `""` calza si está vacío. En cualquiera de esos casos, error.

```bash
if [ -z "${PIDS[$num]}" ]; then
    echo "Número inválido."
    return 1
fi
```
Segunda validación: si el número está fuera de rango (ej. pidió el 99 pero solo había 20), esa posición del arreglo está vacía → inválido.

```bash
if kill "${PIDS[$num]}" 2>/dev/null; then
    echo "Proceso ${PIDS[$num]} (n°$num) terminado con SIGTERM."
else
    echo "No se pudo matar el proceso ${PIDS[$num]} (¿permisos? ¿ya no existe?)."
    return 1
fi
```
`${PIDS[$num]}` traduce el número secuencial al PID real y le manda SIGTERM con `kill`. El `2>/dev/null` oculta los errores feos de kill (los manejamos nosotros). Si kill tuvo éxito, confirma; si no (sin permisos, o el proceso ya murió), avisa.

---

## `listar_servicios` (opción 3)

```bash
if ! which systemctl >/dev/null 2>&1; then
    echo "Este sistema no tiene systemctl."
    return 1
fi
```
Verifica que el sistema use `systemctl` antes de seguir.

```bash
salida=$(systemctl list-unit-files --type=service --no-legend --no-pager)
```
Captura **todos los servicios instalados** en el sistema (esto cumple el "todos los instalados" del enunciado).

```bash
SERVICIOS=()
listado=""
contador=1

while read -r servicio estado resto; do
    if ! systemctl is-active "$servicio" >/dev/null 2>&1; then
        SERVICIOS[contador]=$servicio
        listado+="$contador) SERVICIO=$servicio ESTADO=$estado"$'\n'
        contador=$((contador+1))
    fi
done <<< "$salida"
```
Recorre cada servicio instalado. `is-active` dice si está corriendo; con `!` nos quedamos solo con los que **NO** están corriendo. A esos los enumera y los guarda en `SERVICIOS[contador]` (mismo truco que con los PIDs: número secuencial → nombre del servicio).

```bash
if [ ${#SERVICIOS[@]} -eq 0 ]; then
    echo "No hay servicios detenidos para mostrar."
    return 1
fi

echo "$listado" | less
```
Si no quedó ninguno, avisa. Si hay, los muestra paginados con `less`.

---

## `activar_servicio` (opción 4)

```bash
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
```
Misma estructura que `matar_proceso`: exige que primero se haya listado (opción 3), pide el número secuencial y lo valida (que sea número y que exista en el arreglo).

```bash
if systemctl start "${SERVICIOS[$num]}"; then
    echo "Servicio ${SERVICIOS[$num]} activado correctamente."
else
    echo "No se pudo activar el servicio ${SERVICIOS[$num]}."
    echo "Puede que necesite ejecutar el script con sudo."
    return 1
fi
```
`${SERVICIOS[$num]}` traduce el número al nombre del servicio y lo arranca con `systemctl start`. Si falla (normalmente por permisos), sugiere usar `sudo`.

---

## Menú principal

```bash
PS3=" PS3 Este es el prompt automático del menú de opciones "

opciones=("Listar procesos por usuario" "Matar proceso por numero" "Listar servicios que no estan corriendo" "Activar servicio por numero" "Salir")
```
`PS3` es el texto que mostrará `select`. `opciones` es la lista que se convertirá en menú numerado.

```bash
select opc in "${opciones[@]}"
do
   case $opc in
    "Listar procesos por usuario")  listar_procesos ;;
    "Matar proceso por numero")     matar_proceso ;;
    "Listar servicios que no estan corriendo") listar_servicios ;;
    "Activar servicio por numero")  activar_servicio ;;
    "Salir")
        echo "Finalizamos el menú con un break"
        break
        ;;
    *)
        echo "opción incorrecta"
        ;;
   esac
done
```
`select` imprime el menú numerado y espera la elección. El texto elegido queda en `opc`, y el `case` decide qué función llamar. La opción "Salir" hace `break`, que rompe el loop de `select` y termina el script. El comodín `*` atrapa cualquier número fuera de rango y vuelve a mostrar el menú.

---

## Resumen del flujo

1. Se definen los arreglos vacíos y las funciones (definir ≠ ejecutar).
2. `select` muestra el menú y espera una opción.
3. Opción **1** → `listar_procesos`: valida usuario/`*`, captura `ps`, enumera y llena `PIDS` a la vez, y pagina con `less`.
4. Opción **2** → `matar_proceso`: valida, traduce número→PID con el arreglo y manda SIGTERM.
5. Opción **3** → `listar_servicios`: lista todos los servicios instalados, filtra los que no corren con `is-active`, los enumera y llena `SERVICIOS`.
6. Opción **4** → `activar_servicio`: valida, traduce número→nombre y hace `systemctl start`.
7. Opción **5** → `break` → fin.
