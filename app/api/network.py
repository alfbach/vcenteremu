from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.auth.session_manager import Session, require_session
from app.store.inventory_store import inventory_store

router = APIRouter(prefix="/vcenter", tags=["network"])


@router.get("/network")
async def list_networks(_: Session = Depends(require_session)) -> list[dict]:
    inventory = await inventory_store.get()
    if not inventory.is_loaded:
        raise HTTPException(status_code=503, detail="No inventory loaded")
    return [
        {
            "network": net.network_id,
            "name": net.name,
            "type": net.network_type,
        }
        for net in inventory.networks.values()
    ]


@router.get("/network/{network_id}")
async def get_network(network_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    net = inventory.networks.get(network_id)
    if net is None:
        raise HTTPException(status_code=404, detail="Network not found")
    return {
        "value": {
            "name": net.name,
            "type": net.network_type,
        }
    }
