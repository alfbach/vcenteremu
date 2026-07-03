<img align="right" src="logo.png" alt="vCenter Emulator Logo" height="100" />

# vCenter Emulator

Emulates a **VMware vCenter REST API** based on an **RVtools XLSX export**. The application runs on **RHEL 10** and **OpenShift 4**, provides a web interface for uploads, and serves multiple concurrent API clients.

![vCenter Emulator Web UI](screen1.png)

## Features

- Web UI for uploading RVtools files (`ExportAll2xlsx` or individual tabs)
- Parses the tabs `vInfo`, `vHost`, `vCluster`, `vDatastore`, `vNetwork`, `vDisk`, `vSource`
- vCenter-compatible REST endpoints under `/rest`
- Session authentication like vCenter (`vmware-api-session-id`)
- **Simulated write operations**: Power On/Off/Suspend/Reset, maintenance mode, annotation
- **Additional endpoints**: resource pools, folders, guest identity/networking
- Concurrent access via async FastAPI + optional multiple Uvicorn workers
- **TLS via nginx** on port **9443** (self-signed or custom certificate)
- **OpenShift 4** deployment with Route, PVC, and UBI-based container image

## Ports

| Port | Protocol | Usage |
|---|---|---|
| **8181** | HTTP | Application UI and API (direct access, development, RHEL without TLS) |
| **9443** | HTTPS | TLS via nginx (production on RHEL with `--with-tls`) |
| **8182** | HTTP (internal) | Backend only — used when nginx terminates TLS on 9443 |

**Examples**

| Deployment | Web UI | API base |
|---|---|---|
| Development / RHEL (HTTP) | `http://<host>:8181/` | `http://<host>:8181/rest` |
| RHEL with TLS (nginx) | `https://<host>:9443/` | `https://<host>:9443/rest` |
| OpenShift Route | `https://<route-host>/` | `https://<route-host>/rest` |

Environment variable: `VCENTEREMU_PORT` (default **8181**; set to **8182** when nginx handles TLS).

## Quick Start (Development)

### macOS / Cursor

```bash
bash scripts/dev-mac.sh
```

Then open **http://127.0.0.1:8181/** in your browser. If `customer.xlsx` is in the project root, it is loaded automatically via `.env`.

In Cursor:

- **Run and Debug** → `vCenter Emulator: Dev Server`
- **Terminal → Run Task** → `dev: setup + start (Mac)` or `dev: smoke test`

Smoke test (server must be running on port **8181**):

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
uvicorn app.main:app --host 0.0.0.0 --port 8181 --reload
```

| | URL |
|---|---|
| Web UI | `http://localhost:8181/` |
| Health | `http://localhost:8181/health` |
| API | `http://localhost:8181/rest/` |

## Download, install, and run on RHEL 10

Deploy on a fresh **Red Hat Enterprise Linux 10** server.

### Requirements

- RHEL 10 (or compatible Enterprise Linux) with `sudo` access
- Network access to install packages via `dnf`
- An RVtools XLSX export (e.g. `ExportAll2xlsx`)
- Firewall ports **8181** (HTTP) and/or **9443** (HTTPS) open for remote access

### 1. Download

```bash
sudo dnf install -y git
git clone https://github.com/alfbach/vcenteremu.git
cd vcenteremu
```

Alternatively, upload and extract a ZIP/tarball of the project.

### 2. Install

Run as **root**. The script installs prerequisites, deploys to `/opt/vcenteremu`, and registers a **systemd** service.

**Important:** Run `install.sh` from your **git clone** after `git pull`, not from an outdated `/opt/vcenteremu` copy. The script copies from the clone into `/opt/vcenteremu`.

```bash
git pull
sudo bash deploy/install.sh
```

**HTTPS on 9443 + firewall (recommended for production):**

```bash
sudo bash deploy/install.sh \
  --with-tls \
  --with-firewall \
  --hostname vcenteremu.example.com
```

| Component | Location / name |
|---|---|
| Application | `/opt/vcenteremu` |
| Upload storage | `/var/lib/vcenteremu/uploads` |
| Configuration | `/etc/vcenteremu/vcenteremu.env` |
| Logs | `/var/log/vcenteremu/` |
| systemd service | `vcenteremu.service` |
| Control script | `vcenteremu-ctl` |

Alternative wrapper: `sudo bash deploy/install-rhel10.sh`

### 3. Configure (optional)

Edit `/etc/vcenteremu/vcenteremu.env`:

```env
VCENTEREMU_API_USERNAME=administrator@vsphere.local
VCENTEREMU_API_PASSWORD=Emulator123!
VCENTEREMU_VCENTER_NAME=vcenteremu.example.com
VCENTEREMU_HOST=0.0.0.0
VCENTEREMU_PORT=8181
VCENTEREMU_WORKERS=4
VCENTEREMU_MAX_UPLOAD_MB=512
```

With TLS enabled, the installer sets `VCENTEREMU_HOST=127.0.0.1` and `VCENTEREMU_PORT=8182` (internal backend).

Change the default password before exposing the service to a network, then restart:

```bash
sudo systemctl restart vcenteremu
```

### 4. Run and verify

```bash
sudo systemctl enable --now vcenteremu
sudo systemctl status vcenteremu
```

| Mode | Web UI | API |
|---|---|---|
| HTTP (default) | `http://<server-fqdn>:8181/` | `http://<server-fqdn>:8181/rest/` |
| HTTPS (`--with-tls`) | `https://<server-fqdn>:9443/` | `https://<server-fqdn>:9443/rest/` |

HTTP on port **8181** redirects to HTTPS on **9443** when TLS is enabled.

**Health check (HTTP):**

```bash
curl -s http://127.0.0.1:8181/health
```

**Health check (HTTPS with TLS):**

```bash
curl -sk https://127.0.0.1:9443/health
```

**API smoke test (HTTP):**

```bash
TOKEN=$(curl -sk -u 'administrator@vsphere.local:Emulator123!' \
  -X POST 'http://127.0.0.1:8181/rest/com/vmware/cis/session')
curl -sk -H "vmware-api-session-id: ${TOKEN}" \
  'http://127.0.0.1:8181/rest/vcenter/vm' | head
```

**API smoke test (HTTPS with TLS):**

```bash
TOKEN=$(curl -sk -u 'administrator@vsphere.local:Emulator123!' \
  -X POST 'https://127.0.0.1:9443/rest/com/vmware/cis/session')
curl -sk -H "vmware-api-session-id: ${TOKEN}" \
  'https://127.0.0.1:9443/rest/vcenter/vm' | head
```

**Service management:**

```bash
sudo systemctl restart vcenteremu
sudo journalctl -u vcenteremu -f
sudo vcenteremu-ctl start|stop|restart|status
```

### TLS with nginx

If TLS was not enabled during installation:

```bash
sudo bash deploy/install-nginx-tls.sh vcenteremu.example.com
```

| Port | Role |
|---|---|
| **9443** | nginx HTTPS (TLS termination) |
| **8181** | HTTP redirect → `https://<host>:9443` |
| **8182** | Internal app backend (`127.0.0.1` only) |

Certificate path: `/etc/vcenteremu/tls/` (`cert.pem`, `key.pem`)

```bash
sudo systemctl restart nginx
sudo systemctl restart vcenteremu
```

## Install on OpenShift 4

Deploy on **Red Hat OpenShift Container Platform 4** with HTTPS via an OpenShift **Route**. The container listens on port **8181**; external access uses the standard Route hostname (typically port 443 on the router).

### Requirements

- OpenShift 4.x cluster with project-admin or cluster-admin access
- `oc` CLI installed and logged in
- Dynamic storage provisioner for the upload PVC
- RVtools XLSX export for upload via the web UI

### Architecture

| Component | Description |
|---|---|
| `Dockerfile` | UBI 9 Python 3.11, non-root (UID 1001), container port **8181** |
| `Deployment` | Single replica (in-memory inventory) |
| `PVC` | 5 GiB for uploaded XLSX files |
| `Route` | HTTPS edge termination on the cluster router |
| `ConfigMap` / `Secret` | Settings and API password |

Manifests: `deploy/openshift/`

### Option A — Automated install

```bash
chmod +x deploy/openshift/install-openshift.sh
./deploy/openshift/install-openshift.sh \
  --namespace vcenteremu \
  --hostname vcenteremu.apps.cluster.example.com
```

With a pre-built image:

```bash
./deploy/openshift/install-openshift.sh \
  --namespace vcenteremu \
  --from-image quay.io/your-org/vcenteremu:latest \
  --password 'YourSecurePassword'
```

Open the Route URL from the script output, e.g. `https://vcenteremu.apps.cluster.example.com/`.

### Option B — Manual install

```bash
oc login --token=<token> --server=https://api.cluster.example.com:6443
oc new-project vcenteremu

oc create secret generic vcenteremu-secret \
  --from-literal=VCENTEREMU_API_PASSWORD='YourSecurePassword'
oc apply -f deploy/openshift/configmap.yaml
oc apply -f deploy/openshift/buildconfig.yaml
oc start-build vcenteremu --wait
oc apply -f deploy/openshift/pvc.yaml
oc apply -f deploy/openshift/deployment.yaml
oc apply -f deploy/openshift/service.yaml
oc apply -f deploy/openshift/route.yaml
```

Verify:

```bash
oc get pods,route -n vcenteremu
ROUTE=$(oc get route vcenteremu -o jsonpath='{.spec.host}')
curl -sk "https://${ROUTE}/health"
```

### Option C — Kustomize

```bash
oc apply -k deploy/openshift/
oc create secret generic vcenteremu-secret \
  --from-literal=VCENTEREMU_API_PASSWORD='YourSecurePassword' \
  -n vcenteremu
```

### OpenShift notes

- **Single replica recommended** — inventory is in-memory per pod.
- **Container port 8181** — exposed via Service; Route provides external HTTPS.
- **Upload limit** — default 512 MiB (`VCENTEREMU_MAX_UPLOAD_MB` in ConfigMap).

## API Usage

Replace `<host>` with your server FQDN or `127.0.0.1`. Use port **8181** for HTTP or **9443** for HTTPS (nginx TLS).

### HTTP (port 8181)

```bash
# Session
curl -sk -u 'administrator@vsphere.local:Emulator123!' \
  -X POST 'http://<host>:8181/rest/com/vmware/cis/session'

# List VMs
curl -sk -H 'vmware-api-session-id: <token>' \
  'http://<host>:8181/rest/vcenter/vm'

# Power on (simulated)
curl -sk -H 'vmware-api-session-id: <token>' \
  -X POST 'http://<host>:8181/rest/vcenter/vm/vm-web-01/power/start'
```

### HTTPS (port 9443, RHEL with TLS)

```bash
# Session
curl -sk -u 'administrator@vsphere.local:Emulator123!' \
  -X POST 'https://<host>:9443/rest/com/vmware/cis/session'

# List VMs
curl -sk -H 'vmware-api-session-id: <token>' \
  'https://<host>:9443/rest/vcenter/vm'

# Host maintenance mode (simulated)
curl -sk -H 'vmware-api-session-id: <token>' \
  -X POST 'https://<host>:9443/rest/vcenter/host/host-esxi-01/maintenance/enter'
```

### OpenShift Route (standard HTTPS port 443)

```bash
ROUTE=$(oc get route vcenteremu -o jsonpath='{.spec.host}')
TOKEN=$(curl -sk -u 'administrator@vsphere.local:YourSecurePassword' \
  -X POST "https://${ROUTE}/rest/com/vmware/cis/session")
curl -sk -H "vmware-api-session-id: ${TOKEN}" \
  "https://${ROUTE}/rest/vcenter/vm" | head
```

See the web UI at `/` for all available endpoints and credentials.

## Notes

- This is an **emulator**, not a full vCenter replacement. Write operations only change in-memory state.
- A new upload replaces the inventory; simulated changes are lost in the process.
- For production: use TLS on port **9443**, strong passwords, and a proper CA certificate.

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
