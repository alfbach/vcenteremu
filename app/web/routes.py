from __future__ import annotations

import os
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.config import get_settings
from app.parser.rvtools import parse_rvtools_xlsx
from app.store.inventory_store import inventory_store

router = APIRouter(tags=["web"])
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parent / "templates"))


def _public_base_url(request: Request) -> str:
    forwarded_proto = request.headers.get("x-forwarded-proto")
    scheme = forwarded_proto.split(",", 1)[0].strip() if forwarded_proto else request.url.scheme
    host = request.headers.get("x-forwarded-host") or request.headers.get("host") or request.url.netloc
    return f"{scheme}://{host}".rstrip("/")


@router.get("/", response_class=HTMLResponse)
async def dashboard(request: Request) -> HTMLResponse:
    settings = get_settings()
    inventory = await inventory_store.get()
    base_url = _public_base_url(request)
    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "inventory": inventory,
            "settings": settings,
            "base_url": base_url,
            "api_base": f"{base_url}/rest",
        },
    )


@router.post("/upload", response_class=HTMLResponse)
async def upload_rvtools(request: Request, file: UploadFile = File(...)) -> HTMLResponse:
    settings = get_settings()
    if not file.filename or not file.filename.lower().endswith((".xlsx", ".xlsm")):
        raise HTTPException(status_code=400, detail="Only .xlsx or .xlsm RVtools exports are supported")

    content = await file.read()
    max_bytes = settings.max_upload_mb * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(status_code=413, detail=f"File exceeds {settings.max_upload_mb} MB limit")

    try:
        inventory = parse_rvtools_xlsx(content, source_file=file.filename)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to parse RVtools file: {exc}") from exc

    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    target = upload_dir / file.filename
    target.write_bytes(content)

    await inventory_store.replace(inventory)

    base_url = _public_base_url(request)
    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "inventory": inventory,
            "settings": settings,
            "base_url": base_url,
            "api_base": f"{base_url}/rest",
            "upload_success": True,
            "uploaded_file": file.filename,
        },
    )


@router.get("/health")
async def health() -> dict:
    inventory = await inventory_store.get()
    return {
        "status": "ok",
        "inventory_loaded": inventory.is_loaded,
        "stats": inventory.stats,
    }
