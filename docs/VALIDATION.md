# Registro de validación

Fecha: 2026-10-29

Base de esta etapa: `fbc8780119ec31d20cf971a3377ee27707c2e36a` en
`refactor/remote-buy-v6`.

## Resultado ejecutado en el entorno de construcción

| Comprobación | Resultado |
| --- | --- |
| Pruebas de módulos puros con Luau CLI | 22/22 aprobadas |
| Parseo con Luau CLI | 24/24 archivos de `src/` y `demo/` aceptados |
| Política de APIs | aprobada |
| Construcción `default.project.json` con Rojo 7.7.1 | aprobada |
| Construcción `demo.project.json` con Rojo 7.7.1 | aprobada |
| Parseo XML de ambos `.rbxlx` | aprobado |
| Sintaxis de scripts Bash | aprobada |
| Validez de proyectos JSON | aprobada |
| Integridad del ZIP con `unzip -t` | aprobada |
| Rebuild de Rojo desde una extracción limpia del ZIP | aprobado |
| Roblox Studio / Device Simulator | no ejecutado en este entorno |

La política rechaza APIs de executor y loaders dinámicos en la arquitectura
nueva. También rechaza llamadas directas a remotes en `src/`; la única
invocación cliente-servidor permitida en `demo/` está aislada en
`NOVA_AuthorizedIntegration.lua`.

## Cobertura automatizada fuera del motor

- parsing y comparación de precios, monedas y sufijos grandes;
- re-vinculación por huella y rechazo de ambigüedad;
- imposibilidad de degradar un ID explícito a un candidato heurístico;
- separación entre evidencia observada y confirmada;
- bloqueo y desbloqueo correcto de AUTO;
- detención de AUTO mediante recibo terminal;
- proveedor deshabilitado cuando no existe integración explícita;
- validación del contrato del proveedor autorizado;
- catálogo servidor comprado en orden;
- saldo, revisión y contador autoritativos;
- rate limit del servidor;
- idempotencia de `requestId`;
- rechazo de un `controlId` no autorizado;
- rechazo por saldo insuficiente aunque el cliente envíe un precio falso;
- recibo final `terminal=true`.

## Prueba integral incluida, pendiente de ejecución real

`StudioFlowTest.client.lua` está dentro del lugar construido. Al pulsar
**EJECUTAR PRUEBA COMPLETA EN STUDIO** prueba dentro del motor:

`detectar BUY → leer precio → solicitar compra → validar recibo → habilitar AUTO
→ recorrer siete mejoras → verificar saldo/contador → detenerse`.

El resultado aparece como `PASS` o `FAIL` en la tarjeta y en Output. Este
entorno Linux no incluye Roblox Studio, por lo que no se registró un `PASS` de
Studio ni del simulador móvil. El arnés no se presenta como ejecutado solo por
haber sido construido.

## Estado funcional declarado

| Función | Estado |
| --- | --- |
| Servicio de compra y reglas de servidor | probado como módulo puro |
| Proyecto y lugar Rojo | construidos y validados estructuralmente |
| BUY verde, billetera, precio y contador | implementados; pendientes de Studio |
| Flujo completo autorizado | arnés implementado; pendiente de ejecutarse en Studio |
| Vinculación táctil `TouchTap` | implementada; pendiente de Device Simulator/hardware |
| Loader externo | no existe y no se declara compatible |
| Auto Ice, Auto Comprar legado y Auto Rebirth | no validados en servidor real |
