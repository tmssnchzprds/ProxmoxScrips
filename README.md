# Proxmox Scripts Master

Scaffold para gestionar y ejecutar scripts de los repositorios `amd64` y `arm64`.

Estructura:

- `master.sh` - launcher principal TUI
- `lib/` - módulos: `ui.sh`, `repo.sh`, `scripts.sh`, `cluster.sh`, `proxmox_api.sh`, `security.sh`
- `cache/`, `logs/`, `config.conf`

Funciones incluidas (v1):
- Indexado de scripts y catálogo básico por categoría
- Interfaz TUI con `whiptail` (fallback consola)
- Búsqueda y menú por categorías
- Detección básica de scripts peligrosos y modo sandbox (si `firejail` está disponible)
- Auto-update (pull) de repositorios
- Detección de scripts duplicados

Próximos pasos sugeridos:
- Integrar instalador CT/VM usando `proxmox_api.sh`
- Añadir sandbox real (containers/VMs) para ejecución segura
- UI estilo Proxmox más avanzada (iconos, panel store)

Uso rápido:

```bash
chmod +x master.sh lib/*.sh
./master.sh
```

Configurar Proxmox API (PVE token)
 - Recomiendo usar `config.conf` para guardar `PM_API_URL` y `PVEAPITOKEN`.
 - Formato `PVEAPITOKEN`: `user@realm!tokenid=secret` (ejemplo: `root@pam!mytoken=abcdef12345`).
 - Para crear un token (GUI): Datacenter -> Permissions -> API Tokens -> Add. Selecciona usuario, tokenid y asigna roles.
 - Para probar la conexión desde la máquina donde ejecutes este repo:

```bash
export PM_API_URL="https://proxmox.example.com:8006"
export PVEAPITOKEN="root@pam!mytoken=abcdef12345"
curl -k -s -H "Authorization: PVEAPIToken=$PVEAPITOKEN" "$PM_API_URL/api2/json/version" | jq .
```

Notas sobre permisos:
 - El token necesita permisos para crear contenedores (nodo): `Sys.Modify`, `VM.Allocate`, `Datastore.Allocate` u otro rol con suficientes privilegios. Puedes crear un role específico y asignarlo al token si prefieres limitar permisos.

Uso en `config.conf`:
 - Edita `config.conf` y rellena `PM_API_URL` y `PVEAPITOKEN`. `master.sh` carga ese fichero al iniciar.

