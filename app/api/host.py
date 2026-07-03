from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.auth.session_manager import Session, require_session
from app.store.inventory_store import inventory_store

router = APIRouter(prefix="/vcenter", tags=["host"])


def _get_host_or_404(inventory, host_id: str):
    host = inventory.hosts.get(host_id)
    if host is None:
        raise HTTPException(status_code=404, detail="Host not found")
    return host


@router.get("/host")
async def list_hosts(_: Session = Depends(require_session)) -> list[dict]:
    inventory = await inventory_store.get()
    if not inventory.is_loaded:
        raise HTTPException(status_code=503, detail="No inventory loaded")
    return [
        {
            "host": host.host_id,
            "name": host.name,
            "connection_state": host.connection_state,
            "power_state": "POWERED_ON",
        }
        for host in inventory.hosts.values()
    ]


@router.get("/host/{host_id}")
async def get_host(host_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    host = _get_host_or_404(inventory, host_id)
    return {
        "value": {
            "name": host.name,
            "connection_state": host.connection_state,
            "power_state": "POWERED_ON",
            "cpu": {
                "count": host.num_cpu,
                "cores_per_socket": max(host.cores // max(host.num_cpu, 1), 1),
                "model": host.cpu_model or None,
                "mhz": host.cpu_mhz or None,
            },
            "memory": {
                "size_MiB": host.memory_mib,
                "usage_percent": host.memory_usage_pct,
            },
            "version": host.esx_version or None,
            "maintenance_mode": host.maintenance_mode,
        }
    }


@router.get("/host/{host_id}/maintenance")
async def get_host_maintenance(host_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    host = _get_host_or_404(inventory, host_id)
    return {"value": {"maintenance_mode": host.maintenance_mode}}


@router.post("/host/{host_id}/maintenance/enter", status_code=200)
async def enter_maintenance(host_id: str, _: Session = Depends(require_session)) -> None:
    inventory = await inventory_store.get()
    _get_host_or_404(inventory, host_id)
    try:
        await inventory_store.update_host_maintenance(host_id, True)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Host not found") from exc


@router.post("/host/{host_id}/maintenance/exit", status_code=200)
async def exit_maintenance(host_id: str, _: Session = Depends(require_session)) -> None:
    inventory = await inventory_store.get()
    _get_host_or_404(inventory, host_id)
    try:
        await inventory_store.update_host_maintenance(host_id, False)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Host not found") from exc
