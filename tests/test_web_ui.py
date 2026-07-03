from __future__ import annotations

from app.web.i18n import get_translations, normalize_locale


def test_default_locale_is_english():
    t = get_translations("en")
    assert t["upload_button"] == "Load inventory"
    assert t["subtitle"].startswith("Upload an RVtools")


def test_german_translations():
    t = get_translations("de")
    assert t["upload_button"] == "Inventar laden"
    assert "hochladen" in t["subtitle"]


def test_normalize_locale_fallback():
    assert normalize_locale(None) == "en"
    assert normalize_locale("de") == "de"
    assert normalize_locale("fr") == "en"
    assert normalize_locale("DE") == "de"


def test_language_route_sets_cookie():
    from fastapi.testclient import TestClient

    from app.main import create_app

    client = TestClient(create_app())
    response = client.get("/language/de", follow_redirects=False)
    assert response.status_code == 303
    assert response.cookies.get("vcenteremu_lang") == "de"

    page = client.get("/", cookies={"vcenteremu_lang": "de"})
    assert page.status_code == 200
    assert "Inventar laden" in page.text


def test_static_logo_available():
    from fastapi.testclient import TestClient

    from app.main import create_app

    client = TestClient(create_app())
    response = client.get("/static/logo.png")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("image/")
