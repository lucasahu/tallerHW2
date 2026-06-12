# Explicación línea por línea — `taller2.sh`

---

## Cabecera

```bash
#!/bin/bash
```
Se llama *shebang*. Le dice al sistema operativo: "este archivo de texto ejecútalo con el programa `/bin/bash`". Sin esta línea, el sistema no sabe qué intérprete usar. Es como decir "este archivo es Python" o "este archivo es Java", pero para shell.

```bash
PIDS=()
SERVICIOS=()
```
Crea dos **arrays vacíos**. En bash, `()` es un array (lista). Son **globales**: cualquier función puede leerlos y escribirlos. Son el "puente" entre opciones:

- La opción 1 llena `PIDS` → la opción 2 lo lee.
- La opción 3 llenará `SERVICIOS` → la opción 4 lo leerá.

En bash los arrays se acceden así: `${PIDS[3]}` = "el elemento en la posición 3".

---

## Función `listar_procesos` (opción 1)

```bash
listar_procesos() {
```
Define una función. Igual que en cualquier lenguaje, pero sin parámetros declarados (en bash los parámetros llegan de otra forma, acá no usamos).

```bash
    read -p "Ingrese nombre de usuario (o * para todos): " usuario
```
`read` pausa el programa y espera que el usuario escriba algo y presione Enter. Lo que escribió queda guardado en la variable `usuario`. El `-p "texto"` muestra ese texto como pregunta antes de esperar (p = *prompt*).

```bash
    if [ "$usuario" = "*" ]; then
```
Un if. En bash las comparaciones van entre corchetes `[ ]` **con espacios obligatorios** alrededor. `$usuario` es "el valor de la variable usuario". Las comillas alrededor (`"$usuario"`) evitan errores si el valor tiene espacios o está vacío. Aquí pregunta: ¿escribió un asterisco?

```bash
        salida=$(ps -e -o pid=,user=,comm=)
```
La parte más densa. De adentro hacia afuera:

- `ps` = comando que lista los **procesos** corriendo en el sistema.
- `-e` = *everyone*, todos los procesos del sistema.
- `-o pid=,user=,comm=` = "muéstrame solo 3 columnas: PID, usuario y nombre del comando". El signo `=` después de cada columna **borra el encabezado** (la línea "PID USER COMMAND" que normalmente sale arriba). Lo necesitamos porque si no, esa línea de título se enumeraría como si fuera el proceso n°1.
- `$( ... )` = "ejecuta este comando y **devuélveme su salida como texto**". Es como capturar lo que el comando habría impreso en pantalla.
- `salida=` = guarda todo ese texto en la variable `salida`.

Resultado: `salida` contiene algo como:
```
      1 root     systemd
    523 lucas    firefox
    611 lucas    bash
```

```bash
    else
        if ! id "$usuario" &>/dev/null; then
```
Si NO escribió `*`, primero validamos que el usuario exista. `id usuario` es un comando que da información de un usuario, y **falla** (devuelve error) si el usuario no existe — usamos ese efecto secundario como validación. El `!` invierte: "si id FALLÓ...". El `&>/dev/null` tira toda la salida del comando a la basura (`/dev/null` es un agujero negro): solo nos interesa si funcionó o no, no lo que imprime.

```bash
            echo "El usuario '$usuario' no existe."
            return 1
```
`echo` imprime en pantalla. `return 1` sale de la función con código de error (en bash/Linux, **0 = éxito, cualquier otro número = error**). Volvemos al menú.

```bash
        salida=$(ps -u "$usuario" -o pid=,user=,comm=)
```
Igual que antes pero con `-u "$usuario"` = "solo los procesos de ESTE usuario".

```bash
    PIDS=()
```
Vacía el array antes de llenarlo. Importante: si ya habías listado antes, el mapeo viejo queda obsoleto (esos números apuntaban a otro listado). Cada listado nuevo parte de cero.

```bash
    local listado=""
    local contador=1
```
Dos variables. `local` = solo existen dentro de esta función (buena práctica, igual que en otros lenguajes). `listado` acumulará el texto a mostrar; `contador` es el número secuencial que empieza en 1.

```bash
    while read -r linea...   # en el código: while read -r pid user comm; do
```
Aquí está el truco central. `read -r pid user comm` lee **una línea** y la parte por espacios: la primera palabra va a `pid`, la segunda a `user`, y el resto a `comm`. Como cada línea de `ps` es `PID USUARIO COMANDO`, cada variable recibe su pedazo. El `-r` evita que bash interprete los `\` raros (siempre se pone, por seguridad).

El `while ... done` repite esto línea por línea hasta que se acaben.

```bash
        PIDS[contador]=$pid
```
**La línea más importante del taller.** Guarda el PID real en la posición `contador` del array. Ejemplo: si la línea 3 del listado es el proceso 8801, entonces `PIDS[3]=8801`. Así, cuando el usuario después diga "mata el n°3", sabremos que se refiere al PID 8801. Esto cumple la restricción del enunciado: el usuario usa números secuenciales, nunca PIDs.

```bash
        listado+="$contador) PID=$pid USER=$user CMD=$comm"$'\n'
```
`+=` agrega texto al final de `listado` (concatenación). Construimos la línea visible: `3) PID=8801 USER=lucas CMD=firefox`. El `$'\n'` es un salto de línea explícito.

```bash
        contador=$((contador+1))
```
Suma 1. En bash, la aritmética va dentro de `$(( ))` — fuera de eso, bash trataría `contador+1` como texto literal.

```bash
    done <<< "$salida"
```
Cierra el loop e indica **de dónde** lee el `read`: del contenido de la variable `salida` (el texto de `ps` que capturamos antes). El operador `<<<` se llama *here-string*.

**¿Por qué no simplemente `ps ... | while read ...`?** Pregunta de interrogación segura. Con un pipe (`|`), bash ejecuta el `while` en un **subshell**: un proceso hijo separado. El array `PIDS` se llenaría en ese hijo, y al terminar el pipe, el hijo muere y se lleva el array a la tumba — `PIDS` quedaría vacío en el script principal y la opción 2 jamás funcionaría. Con `<<<`, el loop corre en el mismo proceso y el array sobrevive.

```bash
    echo "$listado" | less
```
Recién ahora, con el array ya lleno y el texto ya construido, mandamos el listado a `less`, que es el **paginador**: muestra página por página (flechas/espacio para avanzar, `q` para salir). Aquí el pipe no causa problema porque ya no estamos llenando ningún array.

---

## Función `matar_proceso` (opción 2)

```bash
    if [ ${#PIDS[@]} -eq 0 ]; then
```
`${#PIDS[@]}` = "cantidad de elementos del array PIDS" (el `#` significa "largo de"). `-eq` = *equals* para números. Traducción: "si el array está vacío...". Está vacío cuando el usuario nunca corrió la opción 1 — no hay listado, no hay mapeo, no se puede matar nada por número.

```bash
        echo "Primero debe listar procesos (opción 1)."
        return 1
```
Avisa y vuelve al menú sin romper nada.

```bash
    read -p "Ingrese el número secuencial del proceso a matar: " num
```
Pide el número (el secuencial del listado, NO el PID — restricción del enunciado).

```bash
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ -z "${PIDS[$num]}" ]; then
```
Doble validación unida por `||` (OR). Falla si cualquiera de las dos falla:

1. `[[ "$num" =~ ^[0-9]+$ ]]` — compara contra una **expresión regular**: `^[0-9]+$` = "de principio (`^`) a fin (`$`), solo dígitos (`[0-9]`), al menos uno (`+`)". Si el usuario escribió "hola" o "-5", esto falla. El `!` lo invierte: "si NO es un número...".
2. `[ -z "${PIDS[$num]}" ]` — `-z` = *zero length*, "¿está vacío?". Si escribió 99 pero el listado tenía 20 procesos, `PIDS[99]` no existe (vacío) → número inválido.

```bash
    if kill "${PIDS[$num]}" 2>/dev/null; then
```
La acción. `${PIDS[$num]}` traduce el número secuencial al PID real (si escribió 3, esto es 8801). `kill PID` le manda la señal **SIGTERM** al proceso: "por favor, termina ordenadamente". El `2>/dev/null` descarta los mensajes de error feos de kill (los manejamos nosotros con mensajes propios). El `if kill ...` aprovecha que kill devuelve éxito/error: si funcionó entra al `then`.

> **Dato de interrogación:** `kill` a secas manda SIGTERM (señal 15, terminación amable que el proceso puede atrapar para limpiar antes de morir). `kill -9` manda SIGKILL (señal 9, muerte inmediata e inevitable, el proceso ni se entera). Buena práctica: SIGTERM primero, SIGKILL solo si el proceso no coopera.

```bash
        echo "Proceso ${PIDS[$num]} (n°$num) terminado con SIGTERM."
    else
        echo "No se pudo matar el proceso ${PIDS[$num]} (¿permisos? ¿ya no existe?)."
        return 1
```
Feedback en ambos casos. El kill puede fallar si el proceso es de otro usuario (sin permisos) o si murió entre el listado y ahora.

---

## Menú principal

```bash
while true; do
```
Loop infinito: el menú se repite eternamente hasta que algo lo rompa (`break`).

```bash
    read -p "Opción [1-5]: " opcion
```
Pide la opción al usuario.

```bash
    case "$opcion" in
```
Un `switch` de toda la vida, con sintaxis marciana de bash.

```bash
        1) listar_procesos ;;
        2) matar_proceso ;;
        3) listar_servicios ;;
        4) activar_servicio ;;
```
Cada caso llama a su función. El `;;` es el `break` del switch (fin del caso). Las funciones se llaman solo con su nombre, sin paréntesis.

```bash
        5) break ;;
```
`break` rompe el `while true` → el script sigue después del `done` → como no hay nada más, termina. Esa es la opción "Salir".

```bash
        *) ;;
```
El `default` del switch: cualquier cosa que no sea 1-5 cae aquí. Por ahora no hace nada (vuelve a mostrar el menú). Importante que vaya **al final**: `case` evalúa en orden y `*` calza con todo — si fuera primero, se tragaría todas las opciones.

```bash
    esac
done
```
`esac` cierra el `case` (es "case" al revés, en serio). `done` cierra el `while`.

---

## Resumen mental del flujo completo

1. El script define los arrays vacíos y las funciones (definir ≠ ejecutar: todavía no pasa nada).
2. Entra al `while true` y muestra el menú.
3. Usuario elige **1** → `listar_procesos` pide un usuario, captura la salida de `ps`, recorre línea por línea **enumerando y llenando `PIDS` al mismo tiempo**, y al final pagina con `less`.
4. Usuario elige **2** → `matar_proceso` valida que haya listado, pide el número, lo **traduce a PID con el array**, y manda SIGTERM.
5. Opciones 3 y 4 harán lo mismo pero con servicios y `systemctl` (pendientes).
6. Opción 5 → `break` → fin.

