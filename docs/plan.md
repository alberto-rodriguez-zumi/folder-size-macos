# Plan inicial de Folder Size

## Flujo de uso

1. Elegir una carpeta o un volumen montado en el selector de macOS.
2. Ver el progreso del análisis y poder cancelarlo. El progreso muestra elementos recorridos y la carpeta actual, porque el total de elementos se desconoce al empezar.
3. Explorar los resultados con un mapa de rectángulos cuyo área representa el tamaño y una lista ordenable sincronizada. La lista también permite explorar con el teclado y VoiceOver.
4. Entrar en una subcarpeta y volver a cualquier nivel mediante la ruta de navegación. Mostrar el tamaño y el porcentaje respecto a la carpeta visible, con la ruta completa disponible para copiar.
5. Mostrar el elemento en Finder o abrir Terminal en la carpeta seleccionada. Para un archivo, Terminal se abre en su carpeta contenedora.

## Alcance propuesto para la primera versión

- Carpetas locales, disco de arranque y volúmenes externos montados. Dar prioridad a APFS para las pruebas y decidir si SMB/NAS entra en la primera versión según el uso previsto.
- Análisis local y de solo lectura, con un botón para repetir el análisis después de gestionar archivos. Proponer el envío a la papelera como mejora posterior si se necesita.
- Usar el tamaño asignado en disco para el mapa y la lista, con el tamaño lógico disponible en los detalles. Indicar si falta la métrica de algún archivo y marcar los totales afectados como parciales. [Apple Foundation: tamaño asignado](https://developer.apple.com/documentation/foundation/urlresourcevalues/totalfileallocatedsize)
- Incluir archivos ocultos accesibles. Continuar ante errores recuperables e indicar qué rutas se omitieron y por qué. Explicar qué permisos de macOS podrían ampliar la cobertura cuando corresponda. [Apple: acceso completo al disco](https://support.apple.com/en-us/149699)
- Evitar seguir enlaces simbólicos o entrar en otros volúmenes mediante puntos de montaje. Definir el tratamiento del grupo de volúmenes del sistema y de los enlaces entre Sistema y Datos antes de admitir el disco de arranque como objetivo validado.
- Contabilizar una vez los enlaces duros por volumen e identificador de archivo. Fijar y probar cómo se atribuye el tamaño cuando un archivo tiene rutas en varias carpetas. Presentar el tamaño asignado como una medida de los archivos recorridos. Los bloques compartidos por clones APFS y los retenidos por instantáneas impiden usar ese total para predecir cuánto espacio liberaría una eliminación.

## Implementación por etapas

1. **Motor de análisis.** Prototipar en Swift con Foundation. Recorrer metadatos fuera del hilo principal, agregar tamaños y registrar incidencias. Medir tiempo y memoria en un árbol grande antes de fijar la representación en memoria. Validar pronto el acceso y la cobertura del disco de arranque.
2. **Exploración.** Construir la app macOS en SwiftUI, con AppKit para el selector o las integraciones de escritorio que lo requieran. Implementar el mapa original, la tabla, la selección compartida y la navegación por ruta. Agrupar visualmente los elementos pequeños y mantenerlos accesibles desde la tabla.
3. **Integración con macOS.** Abrir Finder y Terminal mediante APIs del sistema o argumentos separados, evitando interpolar rutas en comandos de shell. Validar rutas con espacios, apóstrofos y caracteres Unicode, además de casos en los que el elemento haya desaparecido tras el análisis.
4. **Validación y empaquetado.** Probar cancelación, archivos dispersos, enlaces, directorios inaccesibles, cambios durante el análisis y desconexión de un volumen. Comparar con `du` en un árbol de prueba con métricas y límites equivalentes. Preparar una build local de Xcode como punto de partida y concretar la distribución según quién vaya a instalarla.

## Decisiones pendientes

- Caso de uso prioritario y tipos de volumen que deben entrar desde el principio.
- Mac más antiguo que debe poder ejecutar la app. La propuesta de desarrollo parte de Apple Silicon.
- Acciones de gestión dentro de la app y forma de distribución.
