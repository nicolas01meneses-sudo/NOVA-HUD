# NOVA HUD 5.9 NEON — diagnóstico móvil y escaneo sin filtro de color

Rama: `ui/neon-5-9-mobile-diagnostics`. Base: `ui/auto-scan-neon-5-8`.

## ¿Qué cambió?

- Se conserva la interfaz histórica 5.x con Mundo 1, Marte, Build, Visual y Config.
- El panel Build añade un resumen informativo que muestra: pads detectados, botones GUI de mejoras, número de candidatos de BUY oficial, estado de recolección, estado de Auto Mejoras, intentos y contador de mejoras observadas.
- La clasificación de pads del mundo no utiliza propiedades de color. La detección del BUY oficial se basa en texto/nombre, posición, visibilidad y exclusiones de tienda/premium; **no** es un detector universal de todo el mapa.
- `findOfficialRemoteBuy()` indica cuántos candidatos compatibles encuentra. Si existen varios, se informa **ambiguo** y no se adivina cuál usar.
- `refreshOfficialRemoteBuy()` registra la identidad real de la instancia, no su ruta completa: si Roblox reemplaza un control con otro del mismo nombre, se invalida la confirmación anterior.
- El HUD limita su posición al área visible al arrastrarlo o cambiar de tamaño la pantalla, respetando margen para controles móviles.
- Los títulos de estadísticas identifican botones y acercamientos, en vez de presentar intentos como compras.

## Qué NO se hizo

- **No hay una implementación verificada de Compra Remota sin el poder oficial** en Sell Lemons. El comportamiento observado en Hoshi no permite deducir un método autorizado.
- No se agregó búsqueda de `RemoteEvent`/`RemoteFunction` privados, ni bypass de poderes de pago, ni nuevos métodos de input de ejecutores externos.
- No se garantiza que un botón visible pueda activarse ni que cualquier compra sea aceptada por el servidor.
- Los dos controles Auto Comprar y Recoger fruta continúan siendo independientes visualmente, pero esta versión no demuestra un scheduler paralelo ni recolección efectiva en Sell Lemons.
- `NOVA_BOOT_5_9.lua` es un cargador de la arquitectura heredada 5.x. No reemplaza scripts de servidor para 6.0.1/6.1, ni establece compatibilidad con ejecutores externos.

## Casos de prueba propuestos

1. Ejecutar `node tests/static_5_9.test.cjs` desde la raíz del repositorio. El CI lo ejecuta en cada push/PR de la rama.
2. Verificar la sintaxis con un compilador Luau real (pendiente).
3. Usar una experiencia de Roblox Studio autorizada para pruebas visuales en Device Simulator de teléfono; orientación vertical y horizontal.
4. Mover el HUD a los bordes y rotar el dispositivo: no debe perderse fuera de pantalla.
5. Con un BUY, dos BUY o ningún BUY visible, comprobar estados único / ambiguo / ausente; ninguno implica compra.
6. Cambiar de GUI o recrear un botón con igual nombre y comprobar que cualquier permiso anterior se invalida.
7. Activar Recolección y Auto Mejoras en un laboratorio autorizado y comprobar sus resultados por separado usando recibos del servidor.

## Reversión

Los archivos `NOVA_HUD_5_8_NEON.lua` y `NOVA_BOOT_5_8.lua` permanecen intactos en la rama de origen. Esta versión se publica como dos archivos nuevos en una rama independiente.

## Observaciones sobre el repositorio Hoshi

El archivo `selllemon.lua` publicado en `Fluxyyy333/HoshiOnTop` usa Luraph v14.7 y no expone el motor de compras en texto legible. No fue ejecutado, importado ni utilizado como fuente de código de NOVA.

## Evidencia pendiente

No se ha realizado renderizado en Roblox Studio/Android ni comprobación de compra en el juego original. Esta entrega es una mejora de interfaz, observabilidad y protección frente a controles ambiguos; no una demostración de Hoshi ni una promesa de compras.
