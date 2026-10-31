# NOVA HUD 5.12 — estabilidad y rendimiento (informe Gemini)

Rama: `ui/neon-5-12-stability`, basada en `ui/neon-5-11-independent-engines`. No se sobrescriben versiones anteriores.

## Evidencia comparada

El informe de Gemini propone un scheduler independiente, listeners de moneda, CollectionService, `GetPartBoundsInRadius` y un candado para compras. Esas son **propuestas**, no resultados de ejecutar NOVA o Hoshi. En la revisión del código real de 5.11 verificamos:

- Ya existen **dos tareas de Luau** separadas, una para recolectar y otra para Auto Comprar/UI; no es necesario reemplazarlas por un Heartbeat a 60 Hz.
- El mapa ya se indexa una vez y después se actualiza mediante `Workspace.DescendantAdded`/`DescendantRemoving`.
- Las compras normales ya mantienen el estado `buyPending` mientras esperan evidencia; se conserva como candado lógico.
- No sabemos que Sell Lemons publique tags de objetos o una carpeta de objetos coleccionables usable con `OverlapParams`. Cambiar a consultas espaciales a ciegas podría **perder objetivos**.
- Los scripts de juegos de Hoshi disponibles en GitHub están **ofuscados**; no sabemos el mecanismo de Compra Remota. Su repositorio no contiene solo un bootstrap.
- El repositorio NOVA está disponible directamente en GitHub aunque no haya aparecido indexado en el buscador de Gemini.

## Cambios concretos

1. **Marcadores incrementales:** Radar reutiliza hasta 22 `Highlight` ya existentes; crea solo los nuevos y elimina los que ya no son relevantes. Antes los destruía/recreaba en cada refresh, con trabajo visual innecesario en Android.
2. **Limpieza al recargar:** la destrucción del HUD detiene el ciclo y destruye los marcadores que creó la versión actual. Evita residuos al cargar otra versión.
3. **Escaneo protegido:** `safeRefresh()` utiliza `pcall`, cuenta errores de escaneo y aplica pausas progresivas con límite para evitar reintentos demasiado frecuentes.
4. **Auto Comprar protegido:** `safeRunAutoBuy()` no deja morir la tarea principal ante una excepción. Si falla 3 veces de forma consecutiva, apaga Auto Comprar y Auto Puestos y borra la compra pendiente. No declara compras sin evidencia.
5. **Recolección protegida:** el motor existente ya tenía `pcall`; ahora añade pausas progresivas y, tras 4 errores consecutivos, desactiva sus interruptores y muestra el motivo.
6. **Diagnóstico visible:** en Build se muestran errores de escaneo/compra/recolección por separado, además de intentos y compras verificadas.

## Cambios deliberadamente NO aplicados

- No se introduce un Heartbeat a 60 Hz solo por usarlo; con la lógica actual aumentaría las evaluaciones del scheduler sin necesidad verificada.
- No se asumen rutas `leaderstats.Cash` ni tags `CollectionService` que tal vez no existan en Sell Lemons.
- No se añade movimiento de objetos, spoofing de toques, `RemoteEvent` privados ni bypass del poder Remote Buy.
- No se cambia el motor de compra normal que puede acercar el personaje ni se declara equivalencia con Hoshi.
- No se promete reducción concreta de FPS/CPU o compra/recolección funcional: esas métricas exigen pruebas reales en Android y Roblox.

## Verificación

- `node tests/static_5_12.test.cjs` incluye regresiones estáticas.
- `.github/workflows/nova512-static.yml` compila el HUD y el loader con el compilador oficial Luau, fijado por commit.
- **Pendiente:** pruebas reales de interfaz, memoria, CPU, movimiento y resultados de compras/recolección en un entorno autorizado. Compilar no equivale a funcionamiento en juego.

## Diagnóstico recomendado desde celular

Si el HUD arranca, abrir Build y observar «Errores: escaneo X | compra Y | recoger Z». Activar un sistema cada vez y después ambos. Los valores cero significan que no hubo excepciones detectadas por los protectores, **no** que se hayan comprado mejoras ni recogido limones. Revisar por separado el dinero y contador del juego.

## Rollback

Volver a `NOVA_BOOT_5_11.lua` en `ui/neon-5-11-independent-engines` si la interfaz 5.12 tiene regresiones. Ambas versiones están en ramas separadas.
