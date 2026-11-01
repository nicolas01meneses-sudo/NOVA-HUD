# NOVA HUD 5.12.3 — saldo no reconocido con números grandes

## Problema observado

Video original: `281159.mp4` (27,6 segundos), Mundo **MARTE**, NOVA **5.12.2**. En el segundo 9 aparece:
- Saldo en HUD oficial: **Φ254.847 novemvigintillón**
- Estado del NOVA: **«Zona en espera: saldo no reconocido»**
- Estadísticas: **0 intentos** de compras.

Este video NO demuestra que Auto Comprar siga saltando hasta Oxygen Center. La zona 4 que se veía en el video anterior fue abordada en 5.12.2. El fallo demostrado en el nuevo video es de **lectura de monedas**, y detiene el motor antes de tomar cualquier decisión de compra.

## Diagnóstico del código

En NOVA 5.12.2, `amountFromText` sólo reconocía nombres aislados, por ejemplo, `vigintillón` (rango 21) y `trigintillón` (rango 31), pero faltaba `novemvigintillón`. Como `walletMoney()` devuelve `nil` ante una unidad desconocida, `pricedBuildQueue()` cancela la cola y muestra exactamente el aviso observado.

## Corrección

- Generación de sufijos latinos `-illion`, `-illón`, `-illon` y `-illones` para nombres con bases de decenas 20–99 y sus prefijos. **`novemvigintillón` se registra como rango 30**.
- Los montos siguen representándose como `{rank,n,label}`, sin convertir números de magnitud extremadamente alta a `double`.
- Acepta `Ó` en mayúscula en nombres de unidades, junto a su forma minúscula.
- Unidades desconocidas siguen rechazándose de manera segura. No adivina su valor.
- La misma lectura mejorada se aplica a cantidades de dinero y precios etiquetados si usan estos nombres.
- Se mantienen la selección estricta de Zona 1 de 5.12.2, el arrastre 5.12.1 y los motores separados.
- **No cambia permisos ni garantiza que el servidor acepte las compras**.

## Pruebas

- `node tests/static_5_12_3.test.cjs`: comprobaciones estructurales.
- `node tests/static_5_12_3.test.cjs .luau-upstream/build/luau`: extrae `moneyUnits`, `amountFromText`, `normalizarMonto` y `cheaper` directamente del script publicado, ejecuta afirmaciones en el intérprete oficial Luau y comprueba la cifra exacta del video.
- CI compila HUD y loader con versión de Luau fijada.

**Pendiente**: validar el saldo detectado y el comportamiento de Auto Comprar en Android/Sell Lemons. El video solo demuestra el error anterior, no que las compras funcionen tras esta corrección.

## Comprobación en el teléfono

1. Abrir NOVA 5.12.3 en Marte y activar Auto Comprar.
2. Si muestra `Saldo: Φ254.847 novemvigintillón`, ya no debería bloquearse por «saldo no reconocido».
3. Si ahora dice `Sin primer puesto fiable`, es una protección independiente: ve a Oxygen Pump y pulsa **Build → MARCAR INICIO AQUÍ (ZONA 1)**.
4. Si aparece «sin precio» o «saldo insuficiente», mostrar la pantalla Build y el precio del botón. Estos son errores independientes, no una lectura de saldo fallida.
5. Revisar que no seleccione zona 4 antes de terminar la zona 1.

## Reversión

La 5.12.2 permanece disponible en su rama anterior sin alteraciones.
