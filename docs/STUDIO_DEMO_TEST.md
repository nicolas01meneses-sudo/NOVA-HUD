# Prueba integral autorizada en Studio

## Prueba automática dentro del motor

1. Abre `NOVA-HUD-6.0.1-Studio-Demo.rbxlx`.
2. Inicia una sesión con **Play**, no solo **Run**, para crear `LocalPlayer`.
3. Sin comprar manualmente, pulsa **EJECUTAR PRUEBA COMPLETA EN STUDIO**.
4. Espera hasta 60 segundos. La tarjeta debe terminar en `PASS`.

El arnés ejecuta esta secuencia real dentro de Roblox:

1. detecta el BUY verde por `NOVA_ControlId`;
2. lee el primer precio;
3. conecta el adaptador autorizado;
4. compra una mejora mediante `RemoteFunction`;
5. exige un recibo correlacionado del servidor;
6. desbloquea AUTO después de esa confirmación;
7. continúa por las siete mejoras;
8. compara contador y saldo final;
9. exige un recibo terminal y comprueba que AUTO se detenga.

Resultado esperado:

```text
PASS: 7 upgrades; wallet $4500; terminal receipt confirmed
```

Si ya pulsaste BUY en esa sesión, detén Play e inicia otra sesión antes de
ejecutar la prueba completa.

## Recorrido manual de NOVA

1. Pulsa **VINCULAR BUY VISIBLE** en NOVA.
2. Toca o haz clic en el BUY verde. NOVA acepta controles táctiles mediante
   `TouchTap` y ratón mediante `InputEnded`.
3. Pulsa **PROBAR ADAPTADOR AUTORIZADO**.
4. Espera el estado `ready`.
5. Activa **AUTO REMOTE BUY** y observa cómo cambia la siguiente mejora.
6. Al terminar el catálogo, el estado debe ser `complete` y AUTO debe quedar
   apagado.

El toque usado para vincular también puede activar el BUY real. Esto es una
interacción normal de la interfaz; si necesitas una secuencia desde cero,
reinicia Play.

## Comprobación móvil requerida

En Studio abre **Device Simulator**, selecciona un teléfono y prueba retrato y
apaisado:

- banner de vinculación completamente visible;
- botón BUY con altura táctil de 62 px;
- controles NOVA con altura mínima de 44 px;
- HUD NOVA desplazable cuando falta altura;
- toque sobre BUY reconocido como `touch-tap`;
- prueba integral finalizada en `PASS`.

Después repite una sesión corta en un teléfono físico. El simulador comprueba
dimensiones e input, pero no sustituye una prueba completa de rendimiento en
hardware real.

## Registro honesto de ejecución

| Entorno | Estado al publicar esta rama |
| --- | --- |
| Tests Luau fuera del motor | ejecutados |
| Construcción Rojo del `.rbxlx` | ejecutada |
| Roblox Studio Desktop | pendiente: Studio no está disponible en el entorno de construcción |
| Device Simulator móvil | pendiente |
| Teléfono físico | pendiente |

No cambies estas filas a “ejecutado” sin guardar el resultado observado.
