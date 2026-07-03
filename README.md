# vCenter Emulator

Emulates a **VMware vCenter REST API** based on an **RVtools XLSX export**. The application runs on **RHEL 10**, provides a web interface for uploads, and serves multiple concurrent API clients.

## Features

- Web UI for uploading RVtools files (`ExportAll2xlsx` or individual tabs)
- Parses the tabs `vInfo`, `vHost`, `vCluster`, `vDatastore`, `vNetwork`, `vDisk`, `vSource`
- vCenter-compatible REST endpoints under `/rest`
- Session authentication like vCenter (`vmware-api-session-id`)
- **Simulated write operations**: Power On/Off/Suspend/Reset, maintenance mode, annotation
- **Additional endpoints**: resource pools, folders, guest identity/networking
- Concurrent access via async FastAPI + optional multiple Uvicorn workers
- **TLS via nginx** (self-signed or custom certificate)

## Quick Start (Development)

### macOS / Cursor

```bash
bash scripts/dev-mac.sh
```

Then open **http://127.0.0.1:8443/** in your browser. If `customer.xlsx` is in the project root, it is loaded automatically via `.env`.

In Cursor:
- **Run and Debug** → `vCenter Emulator: Dev Server`
- **Terminal → Run Task** → `dev: setup + start (Mac)` or `dev: smoke test`

Smoke test (server must be running):

```bash
bash scripts/smoke-test-mac.sh
```

Copy `.env.example` to `.env` to customize local settings.

### Manual setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install -e .
export VCENTEREMU_UPLOAD_DIR=./uploads
mkdir -p uploads
uvicorn app.main:app --host 0.0.0.0 --port 8443 --reload
```

Web UI: `http://localhost:8443/`

## Installation on RHEL 10

Full installation including all system prerequisites:

```bash
sudo bash deploy/install.sh
```

With TLS (nginx) and firewall:

```bash
sudo bash deploy/install.sh --with-tls --with-firewall --hostname vcenteremu.local
```

The script installs, among other things:
- `python3`, `python3-pip`, `python3-devel`
- Build tools: `gcc`, `gcc-c++`, `make`
- `openssl`, `curl`, `rsync`, `systemd`
- Python venv + application dependencies
- systemd service `vcenteremu`
- Control script `vcenteremu-ctl`

Alternative (compatibility wrapper): `sudo bash deploy/install-rhel10.sh`

Optional configuration in `/etc/vcenteremu/vcenteremu.env`:

```env
VCENTEREMU_API_USERNAME=administrator@vsphere.local
VCENTEREMU_API_PASSWORD=Emulator123!
VCENTEREMU_VCENTER_NAME=vcenteremu.local
VCENTEREMU_HOST=0.0.0.0
VCENTEREMU_PORT=8443
VCENTEREMU_WORKERS=4
VCENTEREMU_MAX_UPLOAD_MB=256
```

### TLS with nginx (recommended for production)

```bash
sudo bash deploy/install-nginx-tls.sh vcenteremu.local
```

- nginx listens on **443** (HTTPS)
- Backend internally on **127.0.0.1:8080**
- Self-signed certificate under `/etc/vcenteremu/tls/`
- Custom certificate: place `cert.pem` and `key.pem` there and restart nginx

Service management:

```bash
sudo systemctl status vcenteremu
sudo systemctl restart vcenteremu

# or manually without systemd:
sudo vcenteremu-ctl start|stop|restart|status
sudo vcenteremu-ctl foreground   # foreground / debugging
```

## API Usage

1. Create a session:

```bash
curl -sk -u 'administrator@vsphere.local:Emulator123!' \
  -X POST 'https://vcenteremu.local/rest/com/vmware/cis/session'
```

2. Query inventory:

```bash
curl -sk -H 'vmware-api-session-id: <token>' \
  'https://vcenteremu.local/rest/vcenter/vm'
```

3. Power on a VM (simulated — only changes the emulated power state):

```bash
curl -sk -H 'vmware-api-session-id: <token>' \
  -X POST 'https://vcenteremu.local/rest/vcenter/vm/vm-web-01/power/start'
```

4. Put a host into maintenance mode (simulated):

```bash
curl -sk -H 'vmware-api-session-id: <token>' \
  -X POST 'https://vcenteremu.local/rest/vcenter/host/host-esxi-01/maintenance/enter'
```

See the web UI at `/` for additional endpoints.

## Notes

- This is an **emulator**, not a full vCenter replacement. Write operations only change in-memory state.
- A new upload replaces the inventory; simulated changes are lost in the process.
- For production: use TLS, strong passwords, and a proper CA certificate if applicable.

## Tests

```bash
pip install pytest httpx
pytest -q
```

## License

This project is licensed under the **GNU General Public License Version 2 (GPL-2.0)**.

You may use, modify, and distribute this software under the terms of the GPL-2.0. If you distribute it, you must provide the source code (or complete corresponding source) and include the license.

Full license text: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html

## Disclaimer

This software is provided **“as is”**, without warranty of any kind. **No guarantee** is made regarding accuracy, completeness, availability, or fitness for a particular purpose.

Use is at **your own risk**. The authors and contributors shall not be liable for any direct or indirect damages, data loss, downtime, misconfiguration, or other adverse consequences arising from the use or inability to use this software, to the extent permitted by applicable law.

This project is an **unofficial emulator** and is not affiliated with VMware or Broadcom. VMware, vCenter, vSphere, and RVtools are trademarks or products of their respective owners.
