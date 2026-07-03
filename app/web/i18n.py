from __future__ import annotations

from typing import Any

SUPPORTED_LOCALES = ("en", "de")
DEFAULT_LOCALE = "en"

TRANSLATIONS: dict[str, dict[str, Any]] = {
    "en": {
        "title": "vCenter Emulator",
        "subtitle": "Upload an RVtools XLSX export and expose a vCenter-compatible REST API.",
        "upload_success": "Upload successful:",
        "upload_success_detail": "was loaded and indexed.",
        "upload_heading": "Upload RVtools export",
        "upload_label": "RVtools export (.xlsx / .xlsm, e.g. ExportAll2xlsx)",
        "upload_button": "Load inventory",
        "upload_note": (
            "Multiple users can access the same emulated vCenter instance in parallel. "
            "A new upload replaces the current inventory for all clients."
        ),
        "inventory_heading": "Inventory status",
        "source": "Source",
        "vcenter": "vCenter",
        "loaded": "Loaded",
        "no_inventory": "No inventory loaded yet. Please upload an RVtools file.",
        "stat_networks": "Networks",
        "api_heading": "API access",
        "api_base_url": "Base URL",
        "api_user": "Username",
        "api_password": "Password",
        "api_session_header": "Session header",
        "api_health": "Health",
        "tls_heading": "TLS / production",
        "tls_note": (
            "For HTTPS on RHEL 10: "
            "<code>sudo bash deploy/install-nginx-tls.sh vcenteremu.local</code> "
            "— nginx on port 443, backend internally on 127.0.0.1:8080, self-signed certificate."
        ),
        "example_heading": "Example: session, VM list, and power on",
        "endpoints_heading": "Available endpoints",
        "lang_label": "Language",
        "endpoints": [
            ("POST", "/rest/com/vmware/cis/session", "Create session (Basic Auth)"),
            ("DELETE", "/rest/com/vmware/cis/session", "Delete session"),
            ("GET", "/rest/vcenter/vm", "List all VMs"),
            ("GET", "/rest/vcenter/vm/{vm}", "VM details"),
            ("PATCH", "/rest/vcenter/vm/{vm}", "Update annotation (simulated)"),
            ("GET", "/rest/vcenter/vm/{vm}/guest/identity", "Guest identity"),
            ("GET", "/rest/vcenter/vm/{vm}/guest/networking", "Guest networking"),
            ("POST", "/rest/vcenter/vm/{vm}/power/start", "Power on (simulated)"),
            ("POST", "/rest/vcenter/vm/{vm}/power/stop", "Power off (simulated)"),
            ("POST", "/rest/vcenter/vm/{vm}/power/suspend", "Suspend (simulated)"),
            ("POST", "/rest/vcenter/vm/{vm}/power/reset", "Reset (simulated)"),
            ("GET", "/rest/vcenter/host", "List all ESXi hosts"),
            ("GET", "/rest/vcenter/host/{host}", "Host details"),
            ("POST", "/rest/vcenter/host/{host}/maintenance/enter", "Enter maintenance mode (simulated)"),
            ("POST", "/rest/vcenter/host/{host}/maintenance/exit", "Exit maintenance mode"),
            ("GET", "/rest/vcenter/cluster", "List all clusters"),
            ("GET", "/rest/vcenter/datastore", "List all datastores"),
            ("GET", "/rest/vcenter/datacenter", "List all datacenters"),
            ("GET", "/rest/vcenter/network", "List all networks"),
            ("GET", "/rest/vcenter/resource-pool", "Resource pools"),
            ("GET", "/rest/vcenter/folder", "Folders"),
            ("GET", "/rest/appliance/system/version", "vCenter version"),
        ],
    },
    "de": {
        "title": "vCenter Emulator",
        "subtitle": "RVtools XLSX hochladen und eine vCenter-kompatible REST-API bereitstellen.",
        "upload_success": "Upload erfolgreich:",
        "upload_success_detail": "wurde geladen und indexiert.",
        "upload_heading": "RVtools Export hochladen",
        "upload_label": "RVtools Export (.xlsx / .xlsm, z. B. ExportAll2xlsx)",
        "upload_button": "Inventar laden",
        "upload_note": (
            "Mehrere Benutzer können parallel auf dieselbe emulierte vCenter-Instanz zugreifen. "
            "Ein neuer Upload ersetzt das aktuelle Inventar für alle Clients."
        ),
        "inventory_heading": "Inventar-Status",
        "source": "Quelle",
        "vcenter": "vCenter",
        "loaded": "Geladen",
        "no_inventory": "Noch kein Inventar geladen. Bitte eine RVtools-Datei hochladen.",
        "stat_networks": "Netzwerke",
        "api_heading": "API-Zugang",
        "api_base_url": "Basis-URL",
        "api_user": "Benutzer",
        "api_password": "Passwort",
        "api_session_header": "Session-Header",
        "api_health": "Health",
        "tls_heading": "TLS / Produktion",
        "tls_note": (
            "Für HTTPS auf RHEL 10: "
            "<code>sudo bash deploy/install-nginx-tls.sh vcenteremu.local</code> "
            "— nginx auf Port 443, Backend intern auf 127.0.0.1:8080, selbstsigniertes Zertifikat."
        ),
        "example_heading": "Beispiel: Session, VM-Liste und Power On",
        "endpoints_heading": "Verfügbare Endpunkte",
        "lang_label": "Sprache",
        "endpoints": [
            ("POST", "/rest/com/vmware/cis/session", "Session erstellen (Basic Auth)"),
            ("DELETE", "/rest/com/vmware/cis/session", "Session beenden"),
            ("GET", "/rest/vcenter/vm", "Alle VMs"),
            ("GET", "/rest/vcenter/vm/{vm}", "VM-Details"),
            ("PATCH", "/rest/vcenter/vm/{vm}", "Annotation ändern (simuliert)"),
            ("GET", "/rest/vcenter/vm/{vm}/guest/identity", "Guest-Identität"),
            ("GET", "/rest/vcenter/vm/{vm}/guest/networking", "Guest-Netzwerk"),
            ("POST", "/rest/vcenter/vm/{vm}/power/start", "Power On (simuliert)"),
            ("POST", "/rest/vcenter/vm/{vm}/power/stop", "Power Off (simuliert)"),
            ("POST", "/rest/vcenter/vm/{vm}/power/suspend", "Suspend (simuliert)"),
            ("POST", "/rest/vcenter/vm/{vm}/power/reset", "Reset (simuliert)"),
            ("GET", "/rest/vcenter/host", "Alle ESXi-Hosts"),
            ("GET", "/rest/vcenter/host/{host}", "Host-Details"),
            ("POST", "/rest/vcenter/host/{host}/maintenance/enter", "Wartungsmodus (simuliert)"),
            ("POST", "/rest/vcenter/host/{host}/maintenance/exit", "Wartungsmodus beenden"),
            ("GET", "/rest/vcenter/cluster", "Alle Cluster"),
            ("GET", "/rest/vcenter/datastore", "Alle Datastores"),
            ("GET", "/rest/vcenter/datacenter", "Alle Datacenter"),
            ("GET", "/rest/vcenter/network", "Alle Netzwerke"),
            ("GET", "/rest/vcenter/resource-pool", "Resource Pools"),
            ("GET", "/rest/vcenter/folder", "Ordner"),
            ("GET", "/rest/appliance/system/version", "vCenter-Version"),
        ],
    },
}


def normalize_locale(value: str | None) -> str:
    if not value:
        return DEFAULT_LOCALE
    locale = value.strip().lower()[:2]
    return locale if locale in SUPPORTED_LOCALES else DEFAULT_LOCALE


def get_translations(locale: str) -> dict[str, Any]:
    return TRANSLATIONS[normalize_locale(locale)]
