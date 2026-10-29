# Arquitectura 6.0

## Flujo de Compra Remota

1. `ControlScanner` enumera controles visibles de `PlayerGui` con un límite
   fijo. Prefiere `NOVA_Role`, `NOVA_ControlId` y tags de `CollectionService`.
2. `HitTest` prueba primero coordenadas corregidas por `GuiInset` y conserva el
   orden visual que entrega Roblox.
3. `ControlFingerprint` almacena identidad semántica y geometría normalizada;
   no conserva una instancia como única fuente de verdad.
4. `UiSnapshot` toma una muestra del control, precio, billetera y contador
   explícitamente identificados.
5. `RemotePurchaseController` opera como máquina de estados y nunca mezcla una
   compra pendiente con otra.
6. `PurchaseEvidence` compara antes/después. Solo un recibo autorizado o un
   contador estable que aumenta confirma la compra.
7. `ReadOnlyAdapter` exige que el usuario pulse BUY manualmente.
8. `AuthorizedCallbackAdapter` solo se habilita cuando el dueño marca
   `Integration.Authorized=true`, activa la capacidad y aporta callbacks.

## Contrato para un juego propio

Los controles cooperantes deben usar:

- atributo `NOVA_Role`: `remote-buy`, `remote-confirm` o `purchase`;
- atributo `NOVA_ControlId`: identificador estable y no secreto;
- opcional `NOVA_Price` y `NOVA_Currency`;
- tag `NOVA_WalletLabel` para una billetera observable;
- tag `NOVA_PurchaseCounter` y atributo `NOVA_Count` para el contador.

El callback de compra debe validar en servidor propiedad, saldo, precio,
progresión, rate limit e idempotencia. NOVA no incluye una puerta trasera ni
un remote genérico que acepte instancias arbitrarias.

## Estados

`unlinked → linked → testing → ready/manual-verified/observed/rejected`

`auto` solo se alcanza desde `ready`, con un adaptador capaz de activar y una
prueba `confirmed`. Dos intentos automáticos no confirmados detienen el ciclo.
