from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.auth.session_manager import Session, require_session
from app.store.inventory_store import inventory_store

router = APIRouter(prefix="/vcenter", tags=["cluster"])


@router.get("/cluster")
async def list_clusters(_: Session = Depends(require_session)) -> list[dict]:
    inventory = await inventory_store.get()
    if not inventory.is_loaded:
        raise HTTPException(status_code=503, detail="No inventory loaded")
    return [
        {
            "cluster": cluster.cluster_id,
            "name": cluster.name,
            "drs_enabled": cluster.drs_enabled,
            "ha_enabled": cluster.ha_enabled,
        }
        for cluster in inventory.clusters.values()
    ]


@router.get("/cluster/{cluster_id}")
async def get_cluster(cluster_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    cluster = inventory.clusters.get(cluster_id)
    if cluster is None:
        raise HTTPException(status_code=404, detail="Cluster not found")
    return {
        "value": {
            "name": cluster.name,
            "drs_enabled": cluster.drs_enabled,
            "ha_enabled": cluster.ha_enabled,
            "resource_pool": None,
        }
    }
