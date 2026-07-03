from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.auth.session_manager import Session, require_session
from app.store.inventory_store import inventory_store

router = APIRouter(prefix="/vcenter", tags=["resource-pool"])


@router.get("/resource-pool")
async def list_resource_pools(_: Session = Depends(require_session)) -> list[dict]:
    inventory = await inventory_store.get()
    if not inventory.is_loaded:
        raise HTTPException(status_code=503, detail="No inventory loaded")
    return [
        {
            "resource_pool": pool.resource_pool_id,
            "name": pool.name,
            "datacenter": pool.datacenter or None,
            "cluster": pool.cluster or None,
        }
        for pool in inventory.resource_pools.values()
    ]


@router.get("/resource-pool/{resource_pool_id}")
async def get_resource_pool(
    resource_pool_id: str,
    _: Session = Depends(require_session),
) -> dict:
    inventory = await inventory_store.get()
    pool = next(
        (item for item in inventory.resource_pools.values() if item.resource_pool_id == resource_pool_id),
        None,
    )
    if pool is None:
        raise HTTPException(status_code=404, detail="Resource pool not found")
    return {
        "value": {
            "name": pool.name,
            "datacenter": pool.datacenter or None,
            "cluster": pool.cluster or None,
        }
    }
