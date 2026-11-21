# Folder Size

Folder Size es una aplicación para macOS que ayuda a encontrar los archivos y carpetas que ocupan espacio. Representa los resultados como un mosaico o un gráfico radial y permite recorrerlos desde un árbol y una lista ordenable.

## Requisitos e instalación

- macOS 15 Sequoia o posterior.
- Mac con Apple Silicon o Intel de 64 bits. La versión universal está preparada para ambas arquitecturas; la validación en distintos equipos y versiones de macOS sigue pendiente.
- Para instalar una versión distribuible, descarga el DMG desde [Releases](https://github.com/alberto-rodriguez-zumi/folder-size-macos/releases), ábrelo y arrastra **Folder Size** a **Aplicaciones**.

La versión preliminar generada para desarrollo está firmada localmente y no está notarizada: no debe confundirse con una versión pública lista para distribuir.

## Idioma

Folder Size usa español o japonés cuando el idioma del sistema corresponde a una de sus variantes, e inglés para los demás idiomas. En **Folder Size → Configuración** puedes elegir español, inglés, japonés o automático; la elección se conserva entre ejecuciones. Los cuadros y menús propios de macOS pueden seguir el idioma del sistema.

Las traducciones se mantienen en `Resources/<idioma>.lproj/Localizable.strings`; añade el código del idioma a `AppLanguage.supported` y a `CFBundleLocalizations` para incorporar otra traducción.

## Uso

1. Abre Folder Size. Elige entre **Bajo demanda** —opción predeterminada, con menor consumo de memoria— y **Completo**, que conserva más detalle en memoria. Decide si quieres analizar carpetas ocultas y cuántos niveles mostrar en los gráficos.
2. Pulsa **Elegir carpeta o volumen** y selecciona la ubicación. Puedes cancelar el análisis; el contador indica los elementos examinados, no un porcentaje de finalización.
3. Explora el resultado en modo mosaico o radial. Pasa el cursor por un elemento para ver su información; abre una carpeta desde el gráfico, el árbol o el botón de la lista. Utiliza la ruta superior o la flecha para volver a un nivel anterior.
4. Ordena la lista pulsando **Nombre** o **Tamaño**; vuelve a pulsar para invertir el orden. Las opciones de la barra permiten mostrar elementos ocultos y ocultar carpetas pequeñas en la visualización.
5. Selecciona un elemento para mostrarlo en Finder, abrir Terminal, copiar su ruta o moverlo a la papelera. El menú contextual también ofrece propiedades y otras acciones. Mover a la papelera requiere confirmación y afecta a todo el contenido de una carpeta.

Puedes arrastrar los separadores para ajustar el ancho del árbol y la altura de la lista. El árbol también se puede ocultar.

## Permisos y resultados parciales

Algunas ubicaciones están protegidas por macOS. Si necesitas ampliar el acceso, activa **Folder Size** en **Ajustes del Sistema → Privacidad y seguridad → Acceso total al disco** y repite el análisis. Esto no garantiza acceso a todas las ubicaciones: también pueden aplicarse permisos de otras cuentas y restricciones del sistema.

La exclamación indica que el resultado es parcial. Consulta **Incidencias** para ver las rutas y los errores registrados. La comprobación que oculta la ayuda de acceso al disco es orientativa: si macOS no permite verificar el acceso, la ayuda puede seguir apareciendo.

## Cómo interpretar el espacio

Los tamaños se basan en el espacio asignado de los archivos que se han podido recorrer. Los enlaces simbólicos no se siguen, se evitan otros volúmenes montados dentro de la ubicación y los enlaces duros se cuentan una sola vez durante un análisis. El acceso limitado y los cambios durante el recorrido pueden producir resultados incompletos. Los bloques compartidos de APFS y las instantáneas pueden hacer que eliminar un elemento no libere la cantidad indicada.

El espacio recuperable mostrado es una **estimación** basada en las capacidades que devuelve macOS; no es una medición exacta del espacio purgable. Las carpetas o unidades de red pueden responder con lentitud o desconectarse; la compatibilidad con volúmenes externos y SMB aún requiere validación adicional.

## Desarrollo

Se necesita Xcode con las herramientas de línea de comandos y el SDK de macOS. Desde la raíz del repositorio:

```sh
bash Scripts/build-preview.sh
bash Scripts/test-chart-layout.sh
bash Scripts/test-results-sort.sh
bash Scripts/test-volume-capacity.sh
bash Scripts/test-full-disk-access.sh
```

El primer comando genera `Folder-Size-preview.dmg`, una compilación universal firmada ad hoc, apta para pruebas locales. Para preparar una distribución firmada y notarizada, consulta [la guía de publicación](docs/release.md). El alcance y las comprobaciones pendientes están en [el plan del proyecto](docs/plan.md).

## Descargo de responsabilidad

La aplicación se proporciona tal cual, sin garantías. Comprueba los resultados y los elementos seleccionados antes de moverlos a la papelera y conserva copias de seguridad. En la medida permitida por la ley, sus autores no se responsabilizan de pérdidas o daños derivados de su uso.
