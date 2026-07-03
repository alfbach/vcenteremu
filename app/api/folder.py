from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.auth.session_manager import Session, require_session
from app.store.inventory_store import inventory_store

router = APIRouter(prefix="/vcenter", tags=["folder"])


@router.get("/folder")
async def list_folders(_: Session = Depends(require_session)) -> list[dict]:
    inventory = await inventory_store.get()
    if not inventory.is_loaded:
        raise HTTPException(status_code=503, detail="No inventory loaded")
    return [
        {
            "folder": folder.folder_id,
            "name": folder.name,
            "type": folder.folder_type,
            "datacenter": folder.datacenter or None,
        }
        for folder in inventory.folders.values()
    ]


@router.get("/folder/{folder_id}")
async def get_folder(folder_id: str, _: Session = Depends(require_session)) -> dict:
    inventory = await inventory_store.get()
    folder = next(
        (item for item in inventory.folders.values() if item.folder_id == folder_id),
        None,
    )
    if folder is None:
        raise HTTPException(status_code=404, detail="Folder not found")
    return {
        "value": {
            "name": folder.name,
            "type": folder.folder_type,
            "datacenter": folder.datacenter or None,
        }
    }
