from __future__ import annotations

from contextlib import asynccontextmanager

from pathlib import Path

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app import __version__
from app.api import appliance, cluster, datastore, datacenter, folder, host, network, resource_pool, session, vm
from app.config import get_settings
from app.startup import bootstrap_inventory
from app.web.routes import router as web_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await bootstrap_inventory()
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="vCenter Emulator",
        description="Emulates a subset of the VMware vCenter REST API from RVtools XLSX exports.",
        version=__version__,
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    rest = FastAPI(title="vCenter REST API")
    rest.include_router(session.router)
    rest.include_router(vm.router)
    rest.include_router(host.router)
    rest.include_router(cluster.router)
    rest.include_router(datastore.router)
    rest.include_router(datacenter.router)
    rest.include_router(network.router)
    rest.include_router(resource_pool.router)
    rest.include_router(folder.router)
    rest.include_router(appliance.router)
    app.mount("/rest", rest)

    static_dir = Path(__file__).resolve().parent / "web" / "static"
    static_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

    app.include_router(web_router)
    app.state.settings = settings
    return app


app = create_app()


def run() -> None:
    settings = get_settings()
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        workers=settings.workers,
        reload=False,
    )


if __name__ == "__main__":
    run()
