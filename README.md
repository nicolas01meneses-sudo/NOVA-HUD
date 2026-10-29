# NOVA HUD

NOVA HUD está migrando del prototipo monolítico **5.6 NEON** a un proyecto
modular para Roblox Studio. El código nuevo es de solo lectura por defecto:
puede descubrir y describir controles, leer precios identificados, conservar
una huella estable del control y comprobar cambios en la interfaz, pero no
simula input ni busca remotes privados.

## Ramas

- `main`: prototipos históricos 3.x–5.6 en un solo archivo y sus loaders.
- `refactor/remote-buy-v6`: arquitectura 6.0 segura, pruebas y auditoría.

Los archivos 5.6 se mantienen para comparación. Son **experimentos legados**,
no evidencia de que Compra Remota, Auto Comprar, Auto Ice o Auto Rebirth
funcionen en un juego real.

## Por qué cambió Compra Remota

`GuiButton.Activated` es un evento generado por interacción; no es un método
que otro `LocalScript` pueda invocar. NOVA 5.6 intentaba cubrir esa diferencia
con `VirtualUser` y `fireclickdetector`. Este último no es una API de Roblox
Studio y `VirtualUser` no es un contrato de input de producción para este uso.

La versión 6 separa dos modos:

1. **Observación (predeterminado).** Vincula un control visible, pide al
   jugador que lo pulse manualmente y clasifica la evidencia de UI.
2. **Adaptador autorizado.** El dueño de una experiencia aporta un callback
   que ejecuta una compra validada por su servidor. NOVA nunca busca ni adivina
   un `RemoteEvent` o `RemoteFunction`.

Solo un recibo autorizado o un contador de compras estable y explícitamente
identificado puede producir `confirmed`. Una bajada de saldo, un precio que
cambia o un botón que desaparece se reportan como `observed` y nunca
desbloquean compras automáticas.

## Estructura para Studio

El repositorio incluye un proyecto [Rojo](https://rojo.space/):

```text
src/shared/  -> ReplicatedStorage/NOVA
src/client/  -> StarterPlayer/StarterPlayerScripts/NOVA
```

`src/shared/Integration.lua` está desactivado intencionalmente. El dueño del
juego debe habilitarlo y aportar callbacks antes de permitir automatización.

## Validación

Ejecuta:

```bash
bash scripts/check.sh
```

El script rechaza APIs de executor en `src/`, compila cuando
`luau-compile` está disponible y ejecuta las pruebas de módulos puros cuando
`luau` está instalado. Consulta `docs/VALIDATION.md` para ver evidencia exacta
y límites.

## Documentación oficial de Roblox

- [GuiButton](https://create.roblox.com/docs/reference/engine/classes/GuiButton)
- [BasePlayerGui:GetGuiObjectsAtPosition](https://create.roblox.com/docs/reference/engine/classes/BasePlayerGui)
- [ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt)
- [Seguridad del límite cliente-servidor](https://create.roblox.com/docs/scripting/security/client-server-boundary)
