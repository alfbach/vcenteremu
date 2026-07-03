from __future__ import annotations

import logging
from pathlib import Path

from app.config import get_settings
from app.parser.rvtools import parse_rvtools_xlsx
from app.store.inventory_store import inventory_store

logger = logging.getLogger(__name__)


async def bootstrap_inventory() -> None:
    settings = get_settings()
    if not settings.auto_load_xlsx:
        return

    path = Path(settings.auto_load_xlsx).expanduser()
    if not path.is_file():
        logger.warning("Auto-load file not found: %s", path)
        return

    logger.info("Loading inventory from %s ...", path)
    inventory = parse_rvtools_xlsx(path.read_bytes(), source_file=path.name)
    await inventory_store.replace(inventory)
    logger.info(
        "Inventory loaded: %s VMs, %s hosts",
        inventory.stats.get("vms", 0),
        inventory.stats.get("hosts", 0),
    )
