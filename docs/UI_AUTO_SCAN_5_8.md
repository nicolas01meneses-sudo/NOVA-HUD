# NOVA HUD 5.8 NEON — escaneo automático sin vinculación manual

**Rama:** `ui/auto-scan-neon-5-8`  
**Base:** `ui/auto-scan-neon-5-7`  
**Archivos nuevos:** `NOVA_HUD_5_8_NEON.lua` y `NOVA_BOOT_5_8.lua`.

## Lo que se corrigió

En 5.7 el botón `VINCULAR BUY VERDE` iniciaba `remoteBeginLink`, ocultaba la interfaz y abría un aviso azul de `TOCA BUY VERDE` que permanecía hasta un toque identificado, cancelación o 60 segundos. Esa vía manual ya no se ofrece.

En 5.8:
- Ya no existe el botón de vinculación ni se crea su banner.
- Ya no se aprenden coordenadas con dos toques ni se simulan pulsaciones remotas por posición.
- `refresh()` llama `refreshOfficialRemoteBuy()` para buscar automáticamente un `GuiButton` visible aproximadamente cada tres segundos.
- Si no puede identificar un control único, **no adivina**. La interfaz muestra que no hay un BUY de GUI reconocible. Si el control cambia o desaparece, se borra la validación anterior y AUTO se detiene.
- La prueba deliberada de **PROBAR 1 COMPRA REMOTA** y los contadores de intentos, observaciones y confirmaciones se conservan.
- La confirmación sigue exigiendo un incremento verificable en el contador observado; una variación del saldo o del texto no basta para habilitar AUTO.

## Lo que NO afirma esta versión

- Encontrar un `GuiButton` no significa que el jugador haya desbloqueado Remote Buy.
- Encontrar el control no da acceso a eventos del servidor ni garantiza que una compra se ejecute.
- La búsqueda es de **controles de GUI**. No descubre automáticamente todos los pads físicos del mapa.
- No se ha probado el motor Luau ni el resultado dentro de Sell Lemons o en un teléfono.
- El loader 5.8 es una continuación del cargador **histórico 5.x**, no una instalación de NOVA 6.0.1 ni una garantía de funcionamiento en ejecutores externos.

## Archivo anterior intacto

`NOVA_HUD_5_7_NEON.lua` sigue disponible en la rama, al igual que el loader 5.7. Para volver, cambia a esos archivos.

## Verificaciones efectuadas

- 11 comprobaciones estáticas ejecutadas durante la publicación del código nuevo.
- 12 aserciones automatizables incluidas en `tests/static_5_8.test.cjs` (ejecutar en la raíz con `node tests/static_5_8.test.cjs`).
- Se confirmó que la rama fuente `ui/auto-scan-neon-5-7` no se sobrescribió.

## Pruebas pendientes — no marcar como completadas sin evidencia

1. Ejecutar `node tests/static_5_8.test.cjs` en una copia local.
2. Compilar con el parser Luau real.
3. Revisar el HUD en una experiencia **autorizada** de Roblox Studio y comprobar que no aparece el banner azul.
4. Probar detección automática con ningún BUY, un BUY visible, dos botones ambiguos y un BUY que desaparece.
5. Revisar anchuras y textos en el Device Simulator y en Android físico.
6. Para pruebas de compras funcionales, usar la rama `refactor/remote-buy-v6` y un servidor de prueba que autorice las operaciones y devuelva resultados comprobables.

## Relación con el informe Gemini

El PDF de investigación aportado por el usuario distingue detección visual, activación y confirmación de servidor. Esta modificación aplica esa distinción; las afirmaciones sobre sistemas internos de experiencias ajenas siguen sin verificarse.
