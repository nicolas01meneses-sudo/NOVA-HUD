# NOVA HUD 5.7 NEON — escaneo automático y diseño móvil

Rama: `ui/auto-scan-neon-5-7`

Base: `NOVA_HUD_5_6_1_NEON.lua` (sin sobrescribirla).

## Solicitado y realizado

| Solicitud | Cambio |
| --- | --- |
| Eliminar opciones manuales de Scanner | Se quitó la pestaña `Scanner`, su lista de botones de prueba y su captura manual de objetos |
| Eliminar botón `ESCANEAR` | Sustituido por tarjeta informativa `ESCANEO AUTOMÁTICO`, sin acciones |
| Escaneo constante | `refresh()/scanWorld()` siguen funcionando al iniciar y de forma periódica, independientemente de la pestaña visible |
| Arreglar textos fuera de los recuadros | Etiquetas de estado con alturas recalculadas según el texto y el ancho disponible; demás etiquetas se contraen o truncan dentro de sus límites |
| Arreglar números y títulos superpuestos | Tarjeta de estadísticas distribuida en cuadrícula 2 × 2; números grandes abreviados |
| Arreglar títulos de sliders | Título, valor, carril y extremos en filas separadas |
| Mantener controles útiles | `Detener todas las funciones` pasó a Config y `Resaltar objetivos` pasó a Visual |

## Frecuencia del escáner

- Inicio: un escaneo inicial inmediato.
- Compra física / mejoras activas: cada 1,2 s aproximadamente.
- Hielo activo sin compra: cada 2,2 s aproximadamente.
- Reposo: cada 3,5 s aproximadamente.

Las frecuencias son objetivos del bucle, no promesas de tiempo real. Se respeta el rendimiento del dispositivo y del motor.

## Funciones legadas

Se conservaron los bloques existentes para Auto Ice, Auto Comprar, Mejorar Puestos, Compra Remota, Salto infinito y configuración visual. Esta actualización es **de interfaz y escáner automático**, no una validación ni una nueva implementación de Compra Remota.

## Carga de la versión

El archivo `NOVA_BOOT_5_7.lua` carga `NOVA_HUD_5_7_NEON.lua` desde esta rama y muestra mensajes de error de descarga, compilación o ejecución. No garantiza compatibilidad con ejecutores externos ni una compra aceptada por Sell Lemons.

## Verificaciones

- Archivo de la nueva versión y loader publicados en GitHub.
- Comprobación estática de delimitadores balanceados.
- Se revisó que el escáner manual y la pestaña Scanner no figuran en el archivo.
- Se verificó que la actualización conserva funciones legadas por búsqueda de anclas.
- **Pendiente:** compilación con el parser Luau real, renderizado en Roblox, teléfono móvil, distintas escalas, y pruebas de comportamiento del juego.

## Prueba visual sugerida

1. Iniciar HUD y entrar a Mundo 1 y Marte.
2. Comprobar que el panel inferior dice `ESCANEO AUTOMÁTICO` y muestra los contadores sin botón.
3. Confirmar que no existe pestaña `Scanner`.
4. Revisar tarjetas con textos largos en Mundo 1, Marte, Build y Config.
5. Probar deslizador de hielo, velocidad y escalas de HUD.
6. Confirmar que las cuatro estadísticas aparecen en dos filas sin solapamiento.
7. Enviar capturas o video si aparece recorte o desbordamiento para ajustar la resolución concreta.
