from __future__ import annotations

from pathlib import Path

import pytest

from app.parser.rvtools import parse_rvtools_xlsx

CUSTOMER_XLSX = Path(__file__).resolve().parents[1] / "customer.xlsx"


@pytest.mark.skipif(not CUSTOMER_XLSX.exists(), reason="customer.xlsx not present")
def test_customer_xlsx_parse_counts():
    inventory = parse_rvtools_xlsx(CUSTOMER_XLSX.read_bytes(), "customer.xlsx")
    assert inventory.is_loaded
    assert inventory.stats["vms"] >= 2000
    assert inventory.stats["hosts"] >= 200
    assert inventory.stats["clusters"] >= 30
    assert inventory.stats["datastores"] >= 300


@pytest.mark.skipif(not CUSTOMER_XLSX.exists(), reason="customer.xlsx not present")
def test_customer_xlsx_field_quality():
    inventory = parse_rvtools_xlsx(CUSTOMER_XLSX.read_bytes(), "customer.xlsx")

    with_memory = sum(1 for vm in inventory.vms.values() if vm.memory_mib > 0)
    with_guest = sum(1 for vm in inventory.vms.values() if vm.guest_os and vm.guest_os != "OTHER")
    with_ip = sum(1 for vm in inventory.vms.values() if vm.ip_address)
    with_nics = sum(1 for vm in inventory.vm_nics.values() if vm)

    assert with_memory > inventory.stats["vms"] * 0.9
    assert with_guest > inventory.stats["vms"] * 0.8
    assert with_ip > inventory.stats["vms"] * 0.5
    assert with_nics > inventory.stats["vms"] * 0.8

    host = next(iter(inventory.hosts.values()))
    assert host.memory_mib > 0
    assert host.cpu_mhz > 0

    ds = next(iter(inventory.datastores.values()))
    assert ds.capacity_mib > 0
    assert ds.free_mib >= 0

    assert inventory.vcenter_uuid
    assert inventory.product_version or inventory.vcenter_server


@pytest.mark.skipif(not CUSTOMER_XLSX.exists(), reason="customer.xlsx not present")
def test_customer_xlsx_api_integration():
    import asyncio

    from fastapi.testclient import TestClient

    from app.main import create_app
    from app.store.inventory_store import inventory_store

    inventory = parse_rvtools_xlsx(CUSTOMER_XLSX.read_bytes(), "customer.xlsx")
    asyncio.run(inventory_store.replace(inventory))

    client = TestClient(create_app())
    token = client.post(
        "/rest/com/vmware/cis/session",
        auth=("administrator@vsphere.local", "Emulator123!"),
    ).json()
    headers = {"vmware-api-session-id": token}

    vms = client.get("/rest/vcenter/vm", headers=headers)
    assert vms.status_code == 200
    assert len(vms.json()) == inventory.stats["vms"]

    vm_id = vms.json()[0]["vm"]
    detail = client.get(f"/rest/vcenter/vm/{vm_id}", headers=headers)
    assert detail.status_code == 200
    assert detail.json()["value"]["memory"]["size_MiB"] > 0

    powered_off = next(
        (item["vm"] for item in vms.json() if item["power_state"] == "POWERED_OFF"),
        vm_id,
    )
    start = client.post(f"/rest/vcenter/vm/{powered_off}/power/start", headers=headers)
    assert start.status_code == 200
    assert (
        client.get(f"/rest/vcenter/vm/{powered_off}", headers=headers).json()["value"]["power_state"]
        == "POWERED_ON"
    )

    version = client.get("/rest/appliance/system/version", headers=headers)
    assert version.status_code == 200
    assert version.json()["value"]["version"]
