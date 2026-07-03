from __future__ import annotations

from fastapi import APIRouter, Depends

from app.auth.session_manager import Session, require_session
from app.config import Settings, get_settings
from app.store.inventory_store import inventory_store

router = APIRouter(prefix="/appliance", tags=["appliance"])


@router.get("/system/version")
async def get_version(
    _: Session = Depends(require_session),
    settings: Settings = Depends(get_settings),
) -> dict:
    inventory = await inventory_store.get()
    return {
        "value": {
            "product": settings.product_name,
            "version": inventory.product_version or settings.vcenter_version,
            "build": inventory.build or "vcenteremu",
            "summary": "vCenter Emulator",
            "released": "2026-07-03",
            "type": "vCenter Server",
            "name": inventory.vcenter_server or settings.vcenter_name,
        }
    }
