# Auditoría de NOVA HUD 5.6 NEON

Fecha: 2026-10-29
Base auditada: `main` en `35edc74f77db7ea70b6bc1f20479ded178bb8390`

## Alcance revisado

- Árbol completo del repositorio: 42 archivos y 63.299 líneas Luau.
- Evolución 3.2 → 5.6 y 72 commits.
- `NOVA_HUD_5_6_NEON.lua` (3.584 líneas) y su loader.
- Historial específico de Compra Remota en 5.5 y 5.6.
- Grabación del fallo y grabación de referencia del BUY verde.

## Diagnóstico de Compra Remota

El video de referencia muestra el flujo deseado: el BUY verde avanza por
mejoras como Foundation, Railings, Windows, Balcony o Plants mientras el
personaje permanece quieto. La grabación de NOVA 5.6 muestra que la vinculación
entra y sale de los modos flecha/BUY, pero termina sin encontrar un
`GuiButton` debajo del toque.

Problemas confirmados en el código:

1. **Activación no compatible con Studio.** `VirtualUser` intenta generar el
   toque y `fireclickdetector` no pertenece a la API pública de Roblox Studio.
2. **Modelo de dos controles frágil.** La 5.6 guarda la flecha y un BUY de
   confirmación como instancias separadas. Si el menú se recrea al abrirse, la
   referencia al BUY queda obsoleta.
3. **Hit testing inconsistente.** `GetGuiObjectsAtPosition()` espera
   coordenadas relativas al área posterior al GUI inset. La versión anterior
   reutiliza la posición cruda del input y después hace una búsqueda manual sin
   ordenar por DisplayOrder/ZIndex.
4. **Solo acepta `GuiButton`.** Un control compuesto por un `Frame` activo,
   un contenedor transparente o una jerarquía distinta no puede vincularse.
5. **Heurística por región de pantalla.** Los límites porcentuales fijos pueden
   rechazar diseños válidos en otras relaciones de aspecto.
6. **Prueba falsa positiva.** Una bajada de saldo marca `remoteReady=true`,
   aunque el contador no haya cambiado. La bajada puede corresponder a otra
   acción y no demuestra que Compra Remota funcione.
7. **Contador no correlacionado.** Se toma el primer texto parecido a “buttons
   bought”; antes y después podrían ser etiquetas diferentes.
8. **Escaneo costoso.** El HUD recorre grandes porciones de `Workspace` y
   `PlayerGui` repetidamente, algo especialmente sensible en móvil.
9. **Estado monolítico.** Más de 100 campos viven en `NOVA_CORE`; detección,
   UI, movimiento, compra y verificación están acoplados en un solo archivo.
10. **Ciclo de vida incompleto.** Varias conexiones a servicios globales no
    están agrupadas en un administrador único, lo que complica recargas.
11. **Loader mutable.** El loader descarga desde `main` y usa `loadstring`; una
    versión numerada puede cambiar sin que cambie el loader.
12. **Sin pruebas ni contrato de integración.** No había tests, README,
    estructura de módulos ni forma explícita de distinguir APIs observables de
    una acción autorizada por el dueño del juego.

## Compatibilidad de funciones 5.6

| Función 5.6 | API o enfoque anterior | Estado en la rama 6.0 |
| --- | --- | --- |
| Escáner, precios y diagnóstico | Lectura amplia de instancias/texto | Núcleo migrado con alcance limitado; tests puros y revisión estática |
| Compra Remota | `VirtualUser` y vínculo por instancia/coordenada | Núcleo migrado a observación o adaptador autorizado; sin prueba en vivo |
| Auto Comprar Tierra/Marte | TP local + Click/Prompt/Touch | Archivo legado conservado; no migrado ni validado |
| Mejorar puestos | Mismo motor físico/UI de compra | Archivo legado conservado; requiere integración autorizada |
| Auto Ice, lote y salto entre rocas | Click/Prompt + TP local | Archivo legado conservado; no migrado ni validado |
| Recoger fruta/dinero | Click/Prompt/Touch | Archivo legado conservado; no migrado ni validado |
| Auto Rebirth x10 | Lectura y pulsación de UI | Archivo legado conservado; requiere integración autorizada |
| Salto infinito | `JumpRequest` + `Humanoid:ChangeState` | Migrado con API oficial y opt-in; solo revisión estática |
| Radar/resaltado | `Highlight` | Legado conservado; compatible en principio, sin prueba en vivo |
| Inspección y herramientas manuales | Raycast, lectura y resaltado | Legado conservado; el escáner seguro cubre solo una parte |
| Apariencia NEON y escala 10–150 % | UI local | Legado conservado; HUD 6.0 mínimo revisado estáticamente |

## Decisión de arquitectura

La rama 6.0 no intenta “arreglar” la simulación de toques. La reemplaza por:

- observación manual por defecto;
- controles identificados por atributo/tag cuando el dueño del juego coopera;
- huellas que sobreviven a recreaciones de UI;
- evidencia separada en `confirmed`, `observed`, `rejected` e `inconclusive`;
- automatización bloqueada hasta obtener prueba autoritativa;
- callback autorizado e inyectado, sin buscar remotes privados.
