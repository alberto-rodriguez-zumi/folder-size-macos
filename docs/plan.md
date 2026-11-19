# Plan de la primera versión de Folder Size

## Flujo de uso

1. Elegir una carpeta o un volumen montado en el selector de macOS.
2. Ver el progreso del análisis y poder cancelarlo. El progreso muestra elementos recorridos y la carpeta actual, porque el total de elementos se desconoce al empezar.
3. Explorar los resultados con un mapa de rectángulos cuyo área representa el tamaño y una lista ordenable sincronizada. La lista también permite explorar con el teclado y VoiceOver.
4. Entrar en una subcarpeta y volver a cualquier nivel mediante la ruta de navegación. Mostrar el tamaño y el porcentaje respecto a la carpeta visible, con la ruta completa disponible para copiar.
5. Mostrar el elemento en Finder o abrir Terminal en la carpeta seleccionada. Para un archivo, Terminal se abre en su carpeta contenedora.
6. Enviar el archivo o la carpeta seleccionada a la papelera mediante una acción explícita. El diálogo muestra el nombre y la ruta completa, avisa si se moverá una carpeta con todo su contenido y ofrece **Cancelar** como opción por defecto. La acción requiere pulsar **Mover a la papelera**.

## Alcance de la primera versión

- Empezar por carpetas locales como la del usuario. La primera versión instalable también permitirá elegir el disco de arranque, discos externos y unidades de red montadas en macOS. Usar SMB como primer protocolo de red para validar, con casos de permisos limitados y desconexión. Mantener la interfaz operativa si una lectura tarda y descartar resultados que lleguen tras cancelar.
- El análisis es de solo lectura. Para enviar un elemento a la papelera, comprobar antes de actuar que sigue siendo el elemento seleccionado y usar la operación de papelera de macOS. Si el volumen no admite esa operación o devuelve un error, informar y conservar el resultado del análisis. Excluir el borrado permanente y la raíz del análisis de las acciones de papelera. Tras un movimiento confirmado por el sistema, actualizar los resultados afectados y permitir repetir el análisis. [Apple Foundation: mover a la papelera](https://developer.apple.com/documentation/foundation/filemanager/trashitem(at:resultingitemurl:))
- Usar el tamaño asignado en disco para el mapa y la lista, con el tamaño lógico disponible en los detalles. Indicar si falta la métrica de algún archivo y marcar los totales afectados como parciales. [Apple Foundation: tamaño asignado](https://developer.apple.com/documentation/foundation/urlresourcevalues/totalfileallocatedsize)
- Incluir archivos ocultos accesibles. Continuar ante errores recuperables e indicar qué rutas se omitieron y por qué. Explicar qué permisos de macOS podrían ampliar la cobertura cuando corresponda. [Apple: acceso completo al disco](https://support.apple.com/en-us/149699)
- Evitar seguir enlaces simbólicos o entrar en otros volúmenes mediante puntos de montaje. Definir el tratamiento del grupo de volúmenes del sistema y de los enlaces entre Sistema y Datos antes de admitir el disco de arranque como objetivo validado.
- Contabilizar una vez los enlaces duros por volumen e identificador de archivo. Fijar y probar cómo se atribuye el tamaño cuando un archivo tiene rutas en varias carpetas. Presentar el tamaño asignado como una medida de los archivos recorridos. Los bloques compartidos por clones APFS y los retenidos por instantáneas impiden usar ese total para predecir cuánto espacio liberaría una eliminación.

## Compatibilidad y distribución

- Compilar para Apple Silicon (`arm64`) con macOS 15 Sequoia como versión mínima. Implementar el análisis, la navegación y las acciones de archivo con APIs disponibles desde Sequoia. Si una API posterior aporta una mejora, comprobar su disponibilidad y mantener el flujo equivalente en macOS 15. [Apple: compatibilidad con macOS Sequoia](https://support.apple.com/en-ph/120282)
- Verificar el mismo paquete en macOS 15 Sequoia y macOS 26 Tahoe, incluido el portátil M1 con Tahoe. Si surge una limitación que afecte a una función de la primera versión, documentar su impacto antes de reconsiderar la versión mínima.
- Distribuir la app en un `.dmg` que permita arrastrarla a Aplicaciones sin instalar Xcode. Para compartir la versión firmada y notarizada se necesita un certificado Developer ID Application y acceso al servicio de notarización de Apple. Verificar el paquete descargado en otro Mac. [Apple: empaquetado para distribución](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution) · [Apple: Developer ID](https://developer.apple.com/developer-id/)

## Implementación por etapas

1. **Motor y primer recorrido.** Crear un proyecto Xcode con el motor Swift separado de la interfaz. Seleccionar una carpeta local, recorrer metadatos fuera del hilo principal y mostrar en una tabla los tamaños agregados, el progreso y las incidencias. Comparar con `du` en un árbol de prueba con métricas y límites equivalentes. Medir tiempo y memoria en un árbol grande y probar cancelación, enlaces y errores de acceso.
2. **Exploración y navegación.** Añadir el mapa original en SwiftUI, sincronizarlo con la tabla y conectar la navegación por ruta. Agrupar visualmente los elementos pequeños y mantenerlos accesibles desde la tabla. Abrir Finder y Terminal mediante APIs del sistema o argumentos separados. Validar rutas con espacios, apóstrofos y caracteres Unicode.
3. **Volúmenes y papelera.** Validar el disco de arranque, un disco externo y un recurso SMB, incluidos permisos limitados y desconexión durante el análisis. Probar el diálogo de papelera y su cancelación, el movimiento en volúmenes compatibles y los errores por falta de permisos, recurso desconectado o elemento reemplazado.
4. **Paquete instalable.** Preparar el `.dmg`, firmar y notarizar cuando haya una identidad Developer ID disponible y verificar instalación y apertura en los dos entornos de macOS previstos.
