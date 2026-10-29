# Instalación de NOVA 6.0 en Roblox Studio

## Opción A: paquete listo para Studio

1. Descarga `NOVA-HUD-6.0.1-Studio-Demo.zip` desde `dist/`.
2. Comprueba su SHA-256 con el archivo `.sha256` incluido junto al ZIP.
   En Windows puedes ejecutar:

   ```powershell
   CertUtil -hashfile NOVA-HUD-6.0.1-Studio-Demo.zip SHA256
   ```

3. Descomprime el ZIP.
4. Abre `NOVA-HUD-6.0.1-Studio-Demo.rbxlx` con Roblox Studio.
5. Pulsa **Play**. Deben aparecer el HUD NOVA y la tarjeta de demostración con
   el BUY verde.

Esta opción no requiere Rojo para ejecutar la copia ya construida.

## Opción B: construir o sincronizar con Rojo

La rama se validó con **Rojo 7.7.1**. Instala dos componentes de la misma
versión mayor:

- Rojo CLI 7;
- plugin Rojo 7 para Roblox Studio.

Si ya usas Rokit, el repositorio incluye `rokit.toml`; ejecuta:

```powershell
rokit install
```

Para obtener exactamente esta rama:

```powershell
git clone --branch refactor/remote-buy-v6 --single-branch https://github.com/nicolas01meneses-sudo/NOVA-HUD.git
cd NOVA-HUD
```

Instala el plugin compatible desde la página oficial de Rojo o ejecuta:

```powershell
rojo plugin install
```

Desde la raíz del repositorio construye el lugar:

```powershell
rojo build demo.project.json -o NOVA-HUD-6.0.1-Studio-Demo.rbxlx
```

Abre el archivo generado en Studio y pulsa **Play**.

Para sincronización en vivo:

```powershell
rojo serve demo.project.json
```

Después abre el plugin Rojo en Studio y conecta con `localhost:34872`.

## Diferencia entre los proyectos

- `default.project.json`: instala solo el núcleo NOVA. Al no existir un
  proveedor autorizado, Compra Remota queda en modo observación.
- `demo.project.json`: añade el servidor, catálogo, BUY verde, proveedor
  autorizado y prueba integral de Studio.

No uses el loader histórico de 5.6. Consulta `LOADER_COMPATIBILITY.md`.
