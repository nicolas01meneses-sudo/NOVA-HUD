# Compatibilidad de loader

## Estado

**No existe un loader externo compatible con la arquitectura modular 6.0.**

Los loaders históricos de NOVA 5.6 descargan un archivo con `HttpGet` y lo
ejecutan con `loadstring`. No instalan `ServerScriptService`, los módulos
compartidos, el proveedor autorizado ni el límite cliente-servidor de esta
versión. Por lo tanto, no son compatibles y permanecen únicamente como
historial.

## Entradas soportadas

- abrir el lugar `.rbxlx` incluido en el paquete;
- construir con `rojo build demo.project.json`;
- sincronizar con `rojo serve demo.project.json` y el plugin de Studio.

No se declara compatibilidad con ejecutores externos. Tampoco se incluye un
“loader universal” de una sola línea, porque Compra Remota autorizada necesita
un `Script` de servidor y no puede validarse únicamente desde un `LocalScript`.
