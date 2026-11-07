# Build de Ship of Harkinian 9.3.0 para PS4 (GitHub Actions, Windows)

**Fecha:** 2026-11-07
**Estado:** workflow listo para lanzar. **No compilado todavía**: el primer
build real ocurre en GitHub Actions; aquí solo se verificó que los parches
aplican limpios, que el YAML es válido y que las URLs de descarga existen
(ver "Verificación local" al final).

## 1. Qué es esto

Este repo es el port experimental de Ship of Harkinian para PS4 de
[alechurri](https://github.com/alechurri/shipofharkinian-ps4) (basado en SoH
9.2.3 "Ackbar Delta"), actualizado a **Ship of Harkinian 9.3.0 "Dewey
Alpha"** (tag `9.3.0`, commit `ecd889c2`) con los 17 conflictos del rebase
resueltos a mano (ver `../REBASE-9.3.0.md`).

El build se hace en **GitHub Actions con runner `windows-latest`**, el mismo
entorno que usó el autor (Windows 11 + Git Bash, LLVM 18.1.8, CMake, Ninja,
OpenOrbis toolchain v0.5.4). No se compila en esta VM Linux: no tiene el
toolchain, tiene ~600 MiB de RAM libre y el build completo necesita varios GB.

## 2. Qué contiene este repo

| Ruta | Qué es |
|---|---|
| `.github/workflows/build-ps4.yml` | El workflow: descarga herramientas, prepara fuentes, compila deps, compila `soh.elf`, empaqueta el `.pkg` y sube artifacts. Solo se lanza a mano (`workflow_dispatch`). |
| `patches/shipwright-9.3.0-ps4.patch` | Parche PS4 para Shipwright 9.3.0 (875 líneas, 15 archivos). Rebase de `shipwright-9.2.3-ps4.patch`, 17/17 conflictos resueltos. |
| `patches/libultraship-9.3.0-ps4.patch` | Parche PS4 para libultraship en el pin de 9.3.0 (`62e973a`, 2 899 líneas, 17 archivos). |
| `patches/shipwright-9.3.0-ps4-network-stub.patch` | Parche nuevo: desactiva la red en PS4 (ver §3). 37 líneas, 3 archivos. |
| `scripts/prepare-sources.sh` | Clona Shipwright tag 9.3.0 + submódulos y aplica los 3 parches (con `git apply --check` antes de cada uno). Idempotente. |
| `scripts/fetch-soh-o2r.sh` | Descarga `SoH-Dewey-Alpha-Win64.zip` de la release oficial 9.3.0 y extrae `soh.o2r` a `release-pc/`. |
| `build-deps.sh`, `configure.sh`, `env.sh`, `package.sh` | Scripts del autor, con 2 cambios (ver §5). |
| `cmake/`, `compat/`, `bzip2-cmake/`, `opusfile-cmake/`, `zlib-cmake/`, `pkg-static/`, `tests/` | Toolchain CMake PS4, compatibilidad OpenOrbis, helpers de deps, icono del paquete y tests del autor, sin cambios. |
| `docs/` | Guías originales del autor (`BUILDING.md`, `INSTALL.md`, `MODS.md`, `TECHNICAL.md`) para 9.2.3. La instalación en consola es la misma; la versión cambia. |
| `README.md` | README original del autor con un aviso arriba indicando que este repo es el build 9.3.0. |

**Lo que este repo NO contiene (a propósito):** ningún ROM de Ocarina of
Time, ningún `oot.o2r` / `oot-mq.o2r`, ningún módulo Piglet de Sony
(`libScePigletv2VSH.sprx`, `libSceShaccVSH.sprx`). El `.pkg` resultante
tampoco los incluye: solo lleva el ejecutable y el `soh.o2r` de la release
de PC. El `oot.o2r` se genera aparte en PC con el ROM propio de Lux, y los
módulos Piglet se sacan de RetroArch PS4 o del port de Mario 64 PS4 (ver §7).

## 3. Anchor / SDL_net: decisión explícita

**Decisión para este primer build (v1): la red se DESACTIVA en PS4.**

En Ship of Harkinian 9.3.0 la red no es opcional en el build: `soh/CMakeLists.txt`
enlaza `SDL2_net::SDL2_net` en la rama genérica (la que usa PS4), `Network.h`
incluye `<SDL2/SDL_net.h>`, `Network.cpp` llama a `SDLNet_*` y
`OTRGlobals.cpp` llama a `SDLNet_Init()` / `SDLNet_Quit()` sin ninguna guarda.
`build-deps.sh` del autor no compila SDL_net (compila SDL 2.30.9, zlib,
bzip2, libzip, tinyxml2, nlohmann-json, spdlog, ogg, vorbis, opus, opusfile).

El parche `shipwright-9.3.0-ps4-network-stub.patch` hace lo siguiente, todo
guardado con `#ifdef __PS4__` / `#ifndef __PS4__` (el build de PC no cambia):

- `soh/soh/Network/Network.h`: en PS4 no incluye `<SDL2/SDL_net.h>`; define
  unos tipos mínimos (`struct IPaddress { uint32_t host; uint16_t port; };`
  y `typedef void* TCPsocket;`).
- `soh/soh/Network/Network.cpp`: `Enable()` registra un aviso en el log y
  vuelve sin abrir conexión ni arrancar el hilo receptor; `Disable()` solo
  hace `join()` si el hilo existe; `SendDataToRemote()` no envía nada;
  `ReceiveFromServer()` vuelve de inmediato. `HandleRemoteJson()` y los
  callbacks vacíos quedan como están (no usan SDL_net).
- `soh/soh/OTRGlobals.cpp`: `SDLNet_Init()` y `SDLNet_Quit()` quedan
  guardados con `#ifndef __PS4__`.

La rama PS4 de `soh/CMakeLists.txt` (que ya venía en el parche del autor)
**no enlaza `SDL2_net`**, así que el link no lo busca. `find_package(SDL2_net)`
sigue siendo no obligatorio y solo imprime un aviso si no lo encuentra.

**Consecuencia para el jugador:** Anchor (multijugador online), CrowdControl
y Sail quedan desactivados en PS4. Son funciones opt-in (apagadas por
defecto en el menú); si alguien las enciende en la PS4, el stub solo registra
el aviso y no pasa nada: no hay crash, no hay hilo colgado, no hay envío.
`Anchor.cpp` comprueba `isConnected` antes de enviar, y en el stub esa
variable nunca se pone a `true`.

**Por qué no intentar SDL_net ya:** SDL_net 2.2.0 existe
(`libsdl-org/SDL_net`, tag `release-2.2.0`) y es una librería pequeña que
solo depende de SDL2, pero nadie ha demostrado que compile y funcione sobre
OpenOrbis 0.5.4 (la API de sockets de PS4 pasa por `sceNet`, y el toolchain
ya enlaza `-lSceNet` en `PS4_SCE_LIBS`, pero eso no garantiza que SDL_net
resuelva sus símbolos). Una dependencia que falla bloquea todo el build,
mientras que el stub es un cambio de 37 líneas y deja el resto del juego
intacto.

**Fase 2 (después de que el primer `.pkg` arranque en consola):** añadir
SDL_net 2.2.0 a `build-deps.sh` (hay un bloque comentado que lo explica),
quitar el parche stub, y volver a enlazar `SDL2_net` en la rama PS4 de
`soh/CMakeLists.txt`. Si SDL_net no compila o no conecta en la PS4 real, se
revierte al stub: el resto del port no depende de ello.

## 4. Pasos exactos para lanzar el build

### 4.1 Subir este repo a GitHub

```bash
# Desde la carpeta build/ de este trabajo:
cd ~/workspace/soh-ps4-9.3/build

# Crea el repo vacío en GitHub (web o gh cli) y luego:
git init
git add -A
git commit -m "Ship of Harkinian 9.3.0 for PS4 (GitHub Actions build)"
git branch -M main
git remote add origin https://github.com/<tu-usuario>/shipofharkinian-ps4-9.3.0.git
git push -u origin main
```

Notas:
- El nombre del repo en GitHub da igual; lo importante es que el workflow
  haga checkout **con `path: ps4port`**, cosa que ya hace el YAML.
- No subas nunca `tools/`, `Shipwright/`, `oot.o2r`, `*.sprx` ni `*.pkg` al
  repo: `.gitignore` ya los excluye. El workflow los genera/descarga solo.
- No hace falta ningún secret: todo lo que descarga el workflow es público.

### 4.2 Lanzar el workflow

1. En GitHub, abre el repo → pestaña **Actions** → workflow
   **"Build Ship of Harkinian PS4 (9.3.0)"** (en la columna izquierda).
2. Botón **"Run workflow"** → rama `main` → **"Run workflow"**.
3. Espera. Un primer build tarda **~30-60 minutos** (la mayor parte es
   `build-deps.sh` y la compilación del juego). Los siguientes reutilizan las
   cachés de herramientas y dependencias y son más rápidos.
4. Cuando termine en verde, descarga los artifacts de la página de la
   ejecución (abajo del todo).

### 4.3 Artifacts que debe producir

| Artifact | Contenido | Para qué |
|---|---|---|
| `soh-ps4-9.3.0` | `IV0000-SOHP00001_00-SHIPOFHARKINIAN0.pkg`, `build/soh/soh.elf`, `build-info.txt` | El `.pkg` para instalar en la PS4; el `.elf` por si hay que depurar; `build-info.txt` con versiones y fecha. |
| `soh-ps4-9.3.0-logs` | Logs de `build-deps.sh` (`deps/build/*/*.log`), `CMakeOutput.log`, `CMakeError.log`, `CMakeCache.txt` | Para diagnosticar si algo falla (siempre se sube, incluso si el build falla). |

Los artifacts caducan a los **14 días**: descarga el `.pkg` en cuanto el
build termine en verde.

## 5. Cambios respecto al build original del autor (9.2.3)

- **Patches:** los dos parches PS4 son los regenerados contra 9.3.0 (ver
  `../REBASE-9.3.0.md`, §11). Se añade el parche stub de red (§3).
- **`package.sh`:** `VERSION` pasa de `01.00` a `01.01`. El Title ID
  (`SOHP00001`) y el Content ID no cambian, así que instalar este `.pkg`
  actualiza el de 9.2.3 en vez de crear otra entrada. El resto igual.
- **`build-deps.sh`:** solo se añade el comentario de la decisión SDL_net
  (§3). La lista de dependencias no cambia.
- **`configure.sh`, `env.sh`, `cmake/`, `compat/`:** sin cambios.
- **`scripts/prepare-sources.sh` y `scripts/fetch-soh-o2r.sh`:** nuevos,
  para que el workflow no dependa de clonar a mano.
- **`soh.o2r`:** se saca de `SoH-Dewey-Alpha-Win64.zip` (release oficial
  9.3.0), no de la 9.2.3. El `oot.o2r` que pide la consola tiene que ser
  también de 9.3.0 (ver §7).

## 6. Errores probables en el primer intento (y cómo leerlos)

El workflow sube los logs siempre (`soh-ps4-9.3.0-logs`), así que el primer
paso ante un fallo es descargar ese artifact y buscar el error real. Los
fallos más probables, en orden:

| Síntoma | Dónde mirar | Qué significa / qué hacer |
|---|---|---|
| Falla "Download portable tools" con 404 | Log del step | Una URL de descarga cambió (LLVM, CMake, Ninja u OpenOrbis). Comprueba la URL en el navegador y actualiza la versión en el YAML. Las 4 URLs se verificaron el 2026-11-07 (todas devuelven 302). |
| Falla "Prepare sources" en `git apply --check` | Log del step | Un parche no aplica. Casi seguro es que el clon no es el tag 9.3.0 exacto, o que el submódulo libultraship no quedó en el pin `62e973a`. El script imprime el pin real antes de aplicar. Si el pin cambió, actualiza `LUS_PIN` en el script y revisa el parche. |
| Falla "Fetch soh.o2r" | Log del step | La release 9.3.0 cambió de nombre de asset o GitHub devolvió un error. El asset verificado es `SoH-Dewey-Alpha-Win64.zip` (72 814 046 bytes). |
| Falla "Cross-build dependencies" | `deps/build/<nombre>/*.log` | Una dependencia no compila con el toolchain PS4. El `build()` del script muestra las últimas 40-60 líneas del log que falló. Lo más delicado es SDL2 2.30.9 (la más grande). Si falla, el log completo está en el artifact. |
| Falla "Configure (CMake)" | `build/CMakeFiles/CMakeError.log` | Normalmente, una dependencia que no se encontró (`find_package` con REQUIRED) o el toolchain mal detectado. Comprueba que `build-deps.sh` terminó con `ALL DEPS OK` y que `prefix/lib` tiene las librerías. |
| Falla "Build soh.elf" con errores de compilación | Salida del step (el log de Ninja/CMake va a la salida estándar) | Aquí es donde saldrían los problemas del rebase que no se vieron en la revisión estática (un símbolo que cambió de nombre, un include que falta). El error dirá el archivo y la línea: casi seguro será en uno de los 11 archivos tocados por los parches. Hay que corregirlo en el parche correspondiente y relanzar. |
| Falla "Package (.pkg)" con `missing soh.o2r` | Log del step | `fetch-soh-o2r.sh` no dejó `release-pc/soh.o2r`. Revisa ese step. |
| Falla "Package (.pkg)" con `create-fself.exe` / `PkgTool.Core.exe` no encontrado | Log del step | Falta algo en el toolchain OpenOrbis 0.5.4 (o cambió la ruta de `bin/windows`). Comprueba el listado de `tools/OpenOrbis/.../bin/windows` que imprime el step de herramientas. |
| El build termina en verde pero el `.pkg` no arranca en la PS4 | `/data/soh/ps4_boot.log` en la consola | Eso ya no es fallo del workflow: es fallo en consola. Ver §7. El log dice hasta dónde llegó el juego. |

Regla general: **un fallo en los steps 1-6 es problema del workflow o de
las descargas; un fallo en "Build soh.elf" es problema del rebase; un fallo
al arrancar en la PS4 es problema del port en consola.** No mezclarlos.

## 7. Qué falta para probar en la PS4 12.50 de Lux

El workflow solo produce el `.pkg`. Para jugar hacen falta, en la consola,
las mismas 3 cosas que pedía el port 9.2.3 (guía completa en
`docs/INSTALL.md`):

1. **El `.pkg` de este build** (`IV0000-SOHP00001_00-SHIPOFHARKINIAN0.pkg`,
   versión 01.01). Instalarlo con GoldHEN → Package Installer. Actualiza el
   de 9.2.3 si ya lo tenías; las partidas y ajustes viven en `/data/soh/` y
   no se tocan.
2. **`oot.o2r` generado con SoH 9.3.0 en PC** (no vale el de 9.2.3: la
   consola dirá "Outdated ROM Archives"). Se genera corriendo SoH 9.3.0 de
   PC una vez con el ROM propio de Lux. Copiarlo por FTP en modo binario a
   `/data/soh/` (y `oot-mq.o2r` si quiere Master Quest).
3. **Los dos módulos Piglet** (`libScePigletv2VSH.sprx`,
   `libSceShaccVSH.sprx`), de RetroArch PS4 o del port de Mario 64 PS4,
   por FTP en modo binario a `/data/self/system/common/lib/`. No usar
   WinSCP para estos archivos (los corrompe); usar FileZilla en modo
   binario. Comprobar tamaño y SHA-256 con la tabla de `docs/INSTALL.md`.

Primer arranque: compila shaders bajo demanda (tirones cortos la primera
vez); a partir del segundo arranque los precompila detrás del splash y tarda
10-15 s más. Touchpad = menú de SoH. Si el juego vuelve al menú principal
nada más arrancar (CE-34878-0), casi seguro son los módulos Piglet: mirar
`/data/soh/ps4_boot.log` y buscar
`sceKernelLoadStartModule(".../libScePigletv2VSH.sprx") failed`.

**Ciclo de pruebas acordado:** instalar → si falla, copiar
`/data/soh/ps4_boot.log` antes de volver a arrancar (cada arranque lo
sobrescribe) → pasarlo a Muse → corregir → nuevo build.

**Prioridad de Lux para las pruebas: el Randomizer al 100%.** Lo primero
que hay que validar en la consola, una vez que el `.pkg` arranque, es que
el Randomizer de 9.3.0 funcione en PS4 (crear una seed, jugarla, comprobar
que los shuffles nuevos — Bean Souls, Masks, Crawl, Grab, Climb, Speak,
Open Chest, Ganon's Tower, Bushsanity, Roc's Feather — no rompen nada). El
README original lo marca como "Not tested yet", y es lo que más le
interesa a Lux, por encima de la light bar reactiva, el modo Speedrun,
Anchor/online, el gyro y el resto de ideas nuevas. El resto de ideas
quedan para después del Randomizer.

## 8. Verificación local (hecha en esta VM, 2026-11-07)

- **Parches:** `shipwright-9.3.0-ps4.patch`, `libultraship-9.3.0-ps4.patch` y
  el parche stub de red aplican limpios (`git apply --check`) sobre un clon
  fresco y completo de Shipwright tag 9.3.0 (`ecd889c2`) con libultraship en
  el pin `62e973a` (verificado en `../.local-test/verify/`). El árbol
  resultante es **idéntico** a las copias de trabajo resueltas
  (`rebase-9.3.0/` y `rebase-lus-9.3.0/`), salvo los 3 archivos del parche
  stub, que es justo lo que añade. (Ojo: la primera verificación con un
  clon superficial `--depth 1` en `/tmp` falló porque `/tmp` es un tmpfs de
  512 MB y se llenó a mitad del checkout; no era un fallo del parche.)
- **Workflow:** el YAML es válido (parseado con PyYAML: 14 steps, runner
  `windows-latest`, timeout 240 min). `bash -n` pasa en los 7 scripts.
- **URLs de descarga verificadas el 2026-11-07** (todas devuelven 302 a la
  release): LLVM 18.1.8 win64, CMake 3.28.3 win64, Ninja 1.12.1 win, OpenOrbis
  toolchain v0.5.4 (`toolchain-llvm-18.tar.gz`, 158,7 MB) y
  `SoH-Dewey-Alpha-Win64.zip` de la release 9.3.0 (72 814 046 bytes).
- **Intento local con el toolchain OpenOrbis para Linux:** ver §9.

## 9. Intento local de build en esta VM (Linux)

Se intentó hasta donde permite el entorno, sin llegar a ejecutar
`configure.sh`. Bloqueos encontrados, en orden:

- **Bloqueo 1 — el toolchain OpenOrbis no trae compilador:** el tarball
  v0.5.4 (`toolchain-llvm-18.tar.gz`, 158,7 MB) se descargó y descomprimió
  en `../.local-test/`. Contiene `bin/linux/` con las herramientas PS4
  (`create-fself`, `create-gp4`, `PkgTool.Core`, `readoelf`) y las librerías
  del SDK, pero **no trae clang**: el compilador es la descarga separada de
  LLVM 18.1.8 que usa el autor. Sin `PS4_LLVM_BIN/clang`, el toolchain
  CMake (`cmake/ps4-toolchain.cmake`, líneas 47-55) no puede ni empezar.
- **Bloqueo 2 — LLVM 18.1.8 para Linux, descarga estrangulada:** el asset
  correcto es `clang+llvm-18.1.8-x86_64-linux-gnu-ubuntu-18.04.tar.xz`
  (996 MB; el nombre `LLVM-18.1.8-Linux-X64.tar.xz` da 404). La descarga
  llegó al 93% (~930 MB) a ~2,4 MB/s y se abortó; reintentarlo costaría
  otros ~10-15 minutos solo para el compilador.
- **Bloqueo 3 — apt no funciona en esta VM:** `apt-get update` se quedó
  colgado más de 7 minutos en los métodos http/https (sin listas de
  paquetes en caché, `/var/lib/apt/lists/` solo tiene `auxfiles`, `lock` y
  `partial`), así que no se pudo instalar `clang-18`/`lld-18` de Ubuntu
  24.04 como alternativa.
- **Lo que sí se verificó localmente:** el shim `cygpath` (los scripts del
  autor usan `cygpath -m`, inexistente en Linux) funciona; el árbol de
  fuentes se preparó completo (`../.local-test/Shipwright`: rebase 9.3.0
  con `libultraship` rellenado desde `rebase-lus-9.3.0/` y `torch` clonado
  en el pin de 9.3.0 `2ab12fe`); y `ninja` 1.12.1 para Linux se descargó y
  funciona.
- **Bloqueo 4 — RAM (el definitivo):** esta VM tiene **~640 MiB de RAM
  disponible** de 7,7 GiB. Compilar SDL2 y el juego con clang cruzado
  necesita varios GB por proceso en los archivos grandes; un build local
  completo moriría por falta de memoria (OOM) aunque se resolviera todo lo
  anterior. Por eso el build se hace en GitHub Actions y no aquí.

Conclusión: el intento local confirma que el entorno de esta VM no es el
adecuado y que la ruta correcta es el workflow de Windows. Nada de lo
anterior es un fallo del rebase: es un fallo del entorno local. Los
archivos del intento quedan en `../.local-test/` (toolchain, fuentes y
scripts), fuera de este repo, por si alguien quiere retomarlo con más RAM.

## 10. Después del primer build en verde

1. Probar el `.pkg` en la PS4 12.50 (§7) y devolver el log si falla.
2. **Validar el Randomizer en consola** (prioridad de Lux, §7): es lo
   primero que hay que probar una vez que el juego arranque.
3. Subir a **9.3.1** (delta pequeño: solo `OTRGlobals.cpp` y el pin de
   libultraship `62e973a` → `da6daf1a` cambian entre 9.3.0 y 9.3.1).
4. Fase 2 de red: intentar SDL_net 2.2.0 para PS4 y, si funciona, quitar el
   parche stub (§3).
5. Contactar a alechurri con el trabajo ya probado (el rebase + este build),
   como acordó Lux.
