from __future__ import annotations

from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from fastapi import APIRouter, File, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from app.config import get_settings
from app.parser.rvtools import parse_rvtools_xlsx
from app.store.inventory_store import inventory_store
from app.web.i18n import get_translations, normalize_locale

router = APIRouter(tags=["web"])
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parent / "templates"))
LANG_COOKIE = "vcenteremu_lang"


def _public_base_url(request: Request) -> str:
    forwarded_proto = request.headers.get("x-forwarded-proto")
    scheme = forwarded_proto.split(",", 1)[0].strip() if forwarded_proto else request.url.scheme
    host = request.headers.get("x-forwarded-host") or request.headers.get("host") or request.url.netloc
    return f"{scheme}://{host}".rstrip("/")


def _locale_from_request(request: Request) -> str:
    query_lang = request.query_params.get("lang")
    if query_lang:
        return normalize_locale(query_lang)
    cookie_lang = request.cookies.get(LANG_COOKIE)
    if cookie_lang:
        return normalize_locale(cookie_lang)
    return normalize_locale(None)


def _template_context(request: Request, **extra: Any) -> dict[str, Any]:
    settings = get_settings()
    locale = _locale_from_request(request)
    base_url = _public_base_url(request)
    return {
        "request": request,
        "inventory": extra.pop("inventory", None),
        "settings": settings,
        "base_url": base_url,
        "api_base": f"{base_url}/rest",
        "locale": locale,
        "t": get_translations(locale),
        **extra,
    }


@router.get("/language/{lang}")
async def set_language(lang: str, request: Request) -> RedirectResponse:
    locale = normalize_locale(lang)
    referer = request.headers.get("referer") or "/"
    path = urlparse(referer).path or "/"
    response = RedirectResponse(url=path, status_code=303)
    response.set_cookie(LANG_COOKIE, locale, max_age=365 * 24 * 3600, samesite="lax")
    return response


@router.get("/", response_class=HTMLResponse)
async def dashboard(request: Request) -> HTMLResponse:
    inventory = await inventory_store.get()
    context = _template_context(request, inventory=inventory)
    return templates.TemplateResponse(request, "index.html", context)


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

    context = _template_context(
        request,
        inventory=inventory,
        upload_success=True,
        uploaded_file=file.filename,
    )
    return templates.TemplateResponse(request, "index.html", context)


@router.get("/health")
async def health() -> dict:
    inventory = await inventory_store.get()
    return {
        "status": "ok",
        "inventory_loaded": inventory.is_loaded,
        "stats": inventory.stats,
    }
