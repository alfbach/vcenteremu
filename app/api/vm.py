from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.auth.session_manager import Session, require_session
from app.store.inventory_store import inventory_store

router = APIRouter(prefix="/vcenter", tags=["vm"])


def _require_inventory_loaded(inventory) -> None:
    if not inventory.is_loaded:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No RVtools inventory loaded. Upload an XLSX file via the web UI.",
        )


def _get_vm_or_404(inventory, vm_id: str):
    vm = inventory.vms.get(vm_id)
    if vm is None:
        raise HTTPException(status_code=404, detail="Virtual machine not found")
    return vm


def _vm_detail(inventory, vm_id: str, vm) -> dict:
    disks = inventory.vm_disks.get(vm_id, [])
    nics = inventory.vm_nics.get(vm_id, [])
    return {
        "value": {
            "name": vm.name,
            "power_state": vm.power_state,
            "guest_OS": vm.guest_os,
            "cpu": {
                "count": vm.cpus,
                "cores_per_socket": vm.cpus,
                "hot_add_enabled": False,
            },
            "memory": {
                "size_MiB": vm.memory_mib,
                "hot_add_enabled": False,
            },
            "identity": {
                "name": vm.name,
                "instance_uuid": vm.uuid or None,
            },
            "disks": [
                {
                    "key": f"disk-{index + 1}",
                    "value": {
                        "label": disk.get("label", f"Hard disk {index + 1}"),
                        "capacity": disk.get("capacity_mib", 0),
                        "type": "SCSI",
                    },
                }
                for index, disk in enumerate(disks)
            ],
            "nics": [
                {
                    "key": f"nic-{index + 1}",
                    "value": {
                        "label": f"Network adapter {index + 1}",
                        "mac_address": nic.get("mac_address") or None,
                        "state": "CONNECTED" if nic.get("connected", True) else "DISCONNECTED",
                        "backing": {
                            "network": nic.get("network") or None,
                            "type": "STANDARD_PORTGROUP",
                        },
                    },
                }
                for index, nic in enumerate(nics)
            ],
            "annotation": vm.annotation or None,
            "template": vm.template,
        }
    }


@router.get("/vm")
async def list_vms(_: Session = Depends(require_session)) -> list[dict]:
    inventory = await inventory_store.get()
    _require_inventory_loaded(inventory)
    return [
        {
            "vm": vm.vm_id,
            "name": vm.name,
            "power_state": vm.power_state,
            "cpu_count": vm.cpus,
            "memory_size_MiB": vm.memory_mib,
        }
        for vm in inventory.vms.values()
    ]


@router.get("/vm/{vm_id}")
async def get_vm(vm_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    _require_inventory_loaded(inventory)
    vm = _get_vm_or_404(inventory, vm_id)
    return _vm_detail(inventory, vm_id, vm)


class VMAnnotationUpdate(BaseModel):
    annotation: str


@router.patch("/vm/{vm_id}")
async def update_vm(
    vm_id: str,
    body: VMAnnotationUpdate,
    _: Session = Depends(require_session),
) -> dict:
    inventory = await inventory_store.get()
    _require_inventory_loaded(inventory)
    _get_vm_or_404(inventory, vm_id)
    try:
        vm = await inventory_store.update_vm_annotation(vm_id, body.annotation)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Virtual machine not found") from exc
    return {"value": {"name": vm.name, "annotation": vm.annotation}}


@router.get("/vm/{vm_id}/guest/identity")
async def get_vm_guest_identity(vm_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    _require_inventory_loaded(inventory)
    vm = _get_vm_or_404(inventory, vm_id)
    family = "WINDOWS" if "windows" in vm.guest_os.lower() else "LINUX"
    return {
        "value": {
            "name": vm.dns_name or vm.name,
            "host_name": vm.dns_name or vm.name,
            "ip_address": vm.ip_address or None,
            "family_name": family,
        }
    }


@router.get("/vm/{vm_id}/guest/networking")
async def get_vm_guest_networking(vm_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    _require_inventory_loaded(inventory)
    _get_vm_or_404(inventory, vm_id)
    nics = inventory.vm_nics.get(vm_id, [])
    return {
        "value": {
            "interfaces": [
                {
                    "mac_address": nic.get("mac_address") or None,
                    "ip": {"ip_addresses": [nic["ipv4"]]} if nic.get("ipv4") else None,
                    "nic": nic.get("network") or None,
                }
                for nic in nics
            ]
        }
    }


async def _power_action(vm_id: str, target_state: str, allowed_from: set[str]) -> None:
    inventory = await inventory_store.get()
    _require_inventory_loaded(inventory)
    vm = _get_vm_or_404(inventory, vm_id)
    if vm.power_state not in allowed_from:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot change power state from {vm.power_state} to {target_state}",
        )
    try:
        await inventory_store.update_vm_power(vm_id, target_state)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Virtual machine not found") from exc


@router.post("/vm/{vm_id}/power/start", status_code=200)
async def power_start(vm_id: str, _: Session = Depends(require_session)) -> None:
    await _power_action(vm_id, "POWERED_ON", {"POWERED_OFF", "SUSPENDED"})


@router.post("/vm/{vm_id}/power/stop", status_code=200)
async def power_stop(vm_id: str, _: Session = Depends(require_session)) -> None:
    await _power_action(vm_id, "POWERED_OFF", {"POWERED_ON", "SUSPENDED"})


@router.post("/vm/{vm_id}/power/suspend", status_code=200)
async def power_suspend(vm_id: str, _: Session = Depends(require_session)) -> None:
    await _power_action(vm_id, "SUSPENDED", {"POWERED_ON"})


@router.post("/vm/{vm_id}/power/reset", status_code=200)
async def power_reset(vm_id: str, _: Session = Depends(require_session)) -> None:
    inventory = await inventory_store.get()
    _require_inventory_loaded(inventory)
    vm = _get_vm_or_404(inventory, vm_id)
    if vm.power_state != "POWERED_ON":
        raise HTTPException(status_code=400, detail="VM must be powered on to reset")
    await inventory_store.update_vm_power(vm_id, "POWERED_ON")
