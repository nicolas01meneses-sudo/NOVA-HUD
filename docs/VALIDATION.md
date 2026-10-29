# Registro de validación

Fecha: 2026-10-29
Base: `main` en `35edc74f77db7ea70b6bc1f20479ded178bb8390`

## Resultado ejecutado antes de publicar

| Comprobación | Resultado |
| --- | --- |
| Pruebas de módulos puros con Luau CLI | 15/15 aprobadas |
| Parseo con Luau CLI | 17/17 archivos de `src/` aceptados |
| Política de APIs en `src/` | aprobada |
| Sintaxis de `scripts/check.sh` | aprobada |
| Validez de `default.project.json` | aprobada |
| Roblox Studio / servidor real | no ejecutado |

La política estática rechaza APIs de executor, loaders dinámicos y llamadas
directas a `FireServer`/`InvokeServer` dentro de la arquitectura nueva. Los
archivos históricos 3.x–5.6 no se presentan como código validado.

## Cobertura automatizada real

- precios agrupados, abreviados, con moneda y el sufijo localizado
  `sexdecillón` visto en la interfaz de referencia;
- rechazo de monedas incompatibles;
- re-vinculación de un control recreado mediante huella estable;
- rechazo de vínculos heurísticos ambiguos;
- prohibición de degradar un `NOVA_ControlId` explícito a un candidato sin ID;
- contador explícito como evidencia confirmatoria;
- bajada de saldo como evidencia observada, nunca confirmatoria;
- recibo exitoso dentro del evaluador de evidencia;
- adaptador de solo lectura sin capacidad de activación;
- exigencia de `requestId` para toda solicitud autorizada aceptada;
- bloqueo de AUTO después de evidencia no confirmada;
- desbloqueo de AUTO solo para un estado con activación autorizada;
- limpieza de autorización y evidencia al desvincular.

## Revisado estáticamente, no ejecutado en Studio

- construcción y destrucción del HUD 6.0;
- ciclo de vida de conexiones;
- escaneo acotado de `PlayerGui`, tags y atributos;
- corrección de coordenadas por `GuiInset` con fallback conservador;
- Salto infinito con opt-in del dueño;
- contrato del adaptador autorizado.

“Revisado estáticamente” no significa operativo. Hace falta una sesión de
Studio con una experiencia propia y controles instrumentados para validar esos
flujos.

## No probado ni declarado operativo

- Compra Remota automática en Sell Lemons;
- activación programática del BUY verde en una experiencia de terceros;
- Auto Comprar, Auto Ice o Auto Rebirth en un servidor real;
- Salto infinito durante una sesión real;
- callback de compra conectado a un servidor propietario;
- compatibilidad con ejecutores externos;
- cualquier interacción dependiente de controles o servicios privados de un
  juego de terceros.
