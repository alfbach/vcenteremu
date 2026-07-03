from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.auth.session_manager import Session, require_session
from app.store.inventory_store import inventory_store

router = APIRouter(prefix="/vcenter", tags=["datastore"])


@router.get("/datastore")
async def list_datastores(_: Session = Depends(require_session)) -> list[dict]:
    inventory = await inventory_store.get()
    if not inventory.is_loaded:
        raise HTTPException(status_code=503, detail="No inventory loaded")
    return [
        {
            "datastore": ds.datastore_id,
            "name": ds.name,
            "type": ds.type,
            "free_space": ds.free_mib * 1024 * 1024,
            "capacity": ds.capacity_mib * 1024 * 1024,
        }
        for ds in inventory.datastores.values()
    ]


@router.get("/datastore/{datastore_id}")
async def get_datastore(datastore_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    ds = inventory.datastores.get(datastore_id)
    if ds is None:
        raise HTTPException(status_code=404, detail="Datastore not found")
    return {
        "value": {
            "name": ds.name,
            "type": ds.type,
            "free_space": ds.free_mib * 1024 * 1024,
            "capacity": ds.capacity_mib * 1024 * 1024,
            "accessible": ds.accessible,
        }
    }
