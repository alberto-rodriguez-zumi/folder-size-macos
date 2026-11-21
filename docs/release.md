# Preparar una versión para distribución

La compilación de distribución incluye las arquitecturas `arm64` y `x86_64` y requiere macOS 15 o posterior. Antes de publicar, prueba el DMG descargado en equipos independientes con Apple Silicon e Intel y en las versiones de macOS compatibles. La validación en otros equipos y de los volúmenes contemplados en el plan está pendiente.

## Requisitos de firma y notarización

1. Una cuenta del Apple Developer Program con acceso a un certificado **Developer ID Application** válido y su clave privada en el llavero de este Mac. Comprueba las identidades con `security find-identity -v -p codesigning`.
2. Credenciales de notarización guardadas en el llavero con `xcrun notarytool store-credentials`. Usa una contraseña específica de aplicación o una clave de App Store Connect según corresponda; no añadas credenciales al repositorio.
3. Xcode y las herramientas de línea de comandos, acceso a internet y permisos para usar la clave de firma.

```sh
export FOLDER_SIZE_SIGNING_IDENTITY='Developer ID Application: Nombre (TEAMID)'
export FOLDER_SIZE_NOTARY_PROFILE='nombre-del-perfil-del-llavero'
bash Scripts/build-release.sh
```

El script compila un binario universal, firma la aplicación con hardened runtime y sello de tiempo, crea y firma el DMG, lo envía al servicio de notarización de Apple, adjunta el ticket y verifica el resultado. Produce `dist/Folder-Size-0.2.0.dmg`. Si falla cualquier paso, no publiques el archivo como versión notarizada. La firma, notarización, instalación en otro Mac y validación de ambas arquitecturas requieren realizarse con los certificados y equipos adecuados; no se han dado por realizadas por el hecho de preparar el script.

Actualiza los números de versión del paquete y el nombre del DMG antes de preparar una versión posterior. Crea el tag sobre el commit verificado de `main`, prepara las notas y adjunta el DMG final a una GitHub Release. Un repositorio privado limita la descarga a quienes tengan acceso; para ofrecer descargas públicas se necesita otro canal o cambiar la visibilidad deliberadamente.
