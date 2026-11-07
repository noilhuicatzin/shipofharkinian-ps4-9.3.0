# ¿Se puede descargar el .pkg directo desde la PS4?

**Fecha:** 2026-11-07
**Pregunta de Lux:** si el `.pkg` de Ship of Harkinian 9.3.0 se puede descargar e instalar directamente desde la PS4, sin pasar por PC / USB / FTP.

## Respuesta corta

**Sí, a medias: la PS4 puede descargar e instalar el `.pkg` ella sola desde internet,
pero no con su navegador, y no sin ayuda de una app o un servicio en la consola.**
Hace falta una de estas dos cosas en la PS4: **Remote Package Installer (RPI)** de
flatz, o **GoldHEN con el Payload Server activado**. Con eso, una herramienta
(PC, teléfono, o la propia consola vía RPI) le pasa a la PS4 la URL directa del
`.pkg` y la consola lo descarga e instala sola, sin USB ni FTP.

Lo que **no** se puede:
- Abrir el navegador de la PS4, descargar el `.pkg` y que se instale. El navegador
  no tiene gestor de descargas para archivos `.pkg` y no instala nada.
- Descargar el artifact de GitHub Actions directo desde la PS4. Los artifacts
  exigen estar logueado en GitHub (la API y `gh run download` piden token); sin
  login dan 404. Hay proxies de terceros (nightly.link, gh-proxy) que dicen
  saltarse el login, pero son servicios ajenos, poco fiables, y tampoco resuelven
  que el navegador de la PS4 no instala `.pkg`.

## La vía recomendada (la más directa)

**DirectPackageInstaller (DPI) + Remote Package Installer, con el `.pkg` publicado como Release de GitHub.**

1. **Publicar el `.pkg` como Release de GitHub** (no solo como artifact). Los
   assets de una Release pública tienen URL directa y estable, sin login:
   `https://github.com/<usuario>/<repo>/releases/latest/download/IV0000-SOHP00001_00-SHIPOFHARKINIAN0.pkg`
   (el nombre exacto es el del artifact que sube el workflow).
   ⚠️ El workflow actual (`build/.github/workflows/build-ps4.yml`) solo sube el
   `.pkg` como artifact (`soh-ps4-9.3.0`, caduca a los 14 días, exige login).
   Para esta vía hay que añadirle un paso que cree una Release con el `.pkg`
   (p. ej. `softprops/action-gh-release` o `gh release create`).
2. **En la PS4, con GoldHEN activo:** instalar **Remote Package Installer**
   (flatz, `https://github.com/flatz/ps4_remote_pkg_installer`, sirve en el
   puerto `12800`) o activar el **Payload Server en GoldHEN** (puertos
   `9090`/`9021`/`9020`).
3. **DirectPackageInstaller** (marcussacana, `https://github.com/marcussacana/DirectPackageInstaller`,
   gratis, GPL-3.0, builds para Windows/Linux/macOS/Android, necesita .NET 8):
   pegar la URL directa del `.pkg`, pulsar «Load» y luego «Install». La PS4
   descarga el `.pkg` desde internet y lo instala; el PC/teléfono solo le pasa
   la URL. Tiene también modo proxy (si la PS4 no tiene internet directo) y
   modo segmentado (descarga más rápida).
4. El `.pkg` queda en `/data/pkg/` y se instala desde ahí, igual que con USB.
   Después se instala como siempre desde GoldHEN → Package Installer si hiciera
   falta, y aparece el juego en el menú principal.

## Otras vías que también funcionan (sin USB/FTP para el .pkg)

| Vía | Cómo funciona | Qué hace falta |
|---|---|---|
| **PKG Sender** (Loopayeh, `https://github.com/Loopayeh/pkg-sender`) | El PC sirve el `.pkg` por HTTP (puerto `9898`) y la PS4 lo descarga e instala sola. Sin USB, sin FTP, sin escribir la IP a mano. | PC encendido en la misma red + RPI o GoldHEN Payload Server en la PS4. |
| **PKG Sender para Android** (311budz, `ps4-ps5-pkg-sender`) | Igual que el anterior, pero desde el teléfono: envía el `.pkg` a la PS4 por Wi-Fi, o hace streaming directo de una URL a la consola sin guardarlo en el teléfono. | Teléfono Android en la misma Wi-Fi + GoldHEN en la PS4. |
| **GoldHEN Remote Package Installer (web)** | GoldHEN expone una interfaz web: desde el navegador del PC se arrastra el `.pkg` y la consola lo instala. | PC en la misma red + GoldHEN. Sigue necesitando el PC para subir el archivo, pero no USB ni FTP. |
| **Homebrew Store / PKG Zone** (`https://pkg-zone.com/install` en el navegador de la PS4) | Tienda homebrew que descarga e instala apps **de su catálogo** directamente en la PS4. | Solo sirve para lo que está en su catálogo; nuestro `.pkg` no está ahí, así que **no sirve para Ship of Harkinian** salvo que alguien lo publicara en la tienda. |

## Lo que la descarga directa NO resuelve

Aunque el `.pkg` llegue solo a la PS4, la instalación completa de Ship of Harkinian
sigue necesitando **FTP desde el PC**, porque estos dos archivos no hay forma de
meterlos por RPI/DPI:

1. **`oot.o2r` (de 9.3.0)** → `/data/soh/` por FTP en modo binario. Se genera en el PC de Lux con su propio ROM; no es un `.pkg`, ningún instalador lo coloca.
2. **Los dos módulos Piglet** (`libScePigletv2VSH.sprx`, `libSceShaccVSH.sprx`) → `/data/self/system/common/lib/` por FTP en modo binario (FileZilla, nunca WinSCP para los `.sprx`).

O sea: la descarga directa te ahorra el paso del `.pkg` por USB/FTP, pero **el FTP
sigue siendo necesario** para el `oot.o2r` y los Piglet. Si ya tienes FileZilla
abierto para eso, subir el `.pkg` por FTP a `/data/pkg/` y luego instalarlo desde
GoldHEN → Package Installer sigue siendo la vía más simple y fiable de todas,
y es la que documenta la guía original del port.

## Recomendación

- **Si quieres lo más cómodo:** publica el `.pkg` como Release de GitHub y usa
  **DirectPackageInstaller + Remote Package Installer**. Es la única vía en la
  que la PS4 descarga el `.pkg` directamente de internet sin que el archivo
  pase por tu PC ni por USB.
- **Si quieres lo más fiable:** **FTP con FileZilla en modo binario** para todo
  (`.pkg` a `/data/pkg/`, `oot.o2r` a `/data/soh/`, Piglet a
  `/data/self/system/common/lib/`), e instalar desde GoldHEN → Package Installer.
  Es un solo programa, un solo método, y es el que el autor del port probó.
- **No recomendado:** intentar descargar el artifact de GitHub Actions desde el
  navegador de la PS4, ni depender de proxies de terceros (nightly.link /
  gh-proxy) para saltarse el login de GitHub.

## Fuentes

- DirectPackageInstaller: https://github.com/marcussacana/DirectPackageInstaller
- PKG Sender: https://github.com/Loopayeh/pkg-sender
- Remote Package Installer (flatz): https://github.com/flatz/ps4_remote_pkg_installer
- Homebrew Store / PKG Zone: https://consolemods.org/wiki/PS4:Homebrew_Store — instalar con `https://pkg-zone.com/install` en el navegador de la PS4
- Cómo instalar PKGs: https://consolemods.org/wiki/PS4:How_to_Install_PKG_Files
- GitHub Actions artifacts (exigen autenticación): https://docs.github.com/rest/actions/artifacts — los assets de Releases públicas, en cambio, se descargan sin login: `https://github.com/<usuario>/<repo>/releases/latest/download/<archivo>`
