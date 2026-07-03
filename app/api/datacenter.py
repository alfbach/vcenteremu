from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.auth.session_manager import Session, require_session
from app.store.inventory_store import inventory_store

router = APIRouter(prefix="/vcenter", tags=["datacenter"])


@router.get("/datacenter")
async def list_datacenters(_: Session = Depends(require_session)) -> list[dict]:
    inventory = await inventory_store.get()
    if not inventory.is_loaded:
        raise HTTPException(status_code=503, detail="No inventory loaded")
    return [
        {"datacenter": dc.datacenter_id, "name": dc.name}
        for dc in inventory.datacenters.values()
    ]


@router.get("/datacenter/{datacenter_id}")
async def get_datacenter(datacenter_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    dc = next(
        (item for item in inventory.datacenters.values() if item.datacenter_id == datacenter_id),
        None,
    )
    if dc is None:
        raise HTTPException(status_code=404, detail="Datacenter not found")
    return {"value": {"name": dc.name}}
