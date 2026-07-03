from __future__ import annotations

import asyncio
from copy import deepcopy

from app.models.inventory import HostRecord, Inventory, VMRecord


class InventoryStore:
    """Thread-safe async inventory store for concurrent API clients."""

    def __init__(self) -> None:
        self._inventory = Inventory()
        self._lock = asyncio.Lock()

    async def replace(self, inventory: Inventory) -> Inventory:
        async with self._lock:
            self._inventory = inventory
            return self._inventory

    async def get(self) -> Inventory:
        async with self._lock:
            return deepcopy(self._inventory)

    async def snapshot(self) -> Inventory:
        return await self.get()

    async def update_vm_power(self, vm_id: str, power_state: str) -> VMRecord:
        async with self._lock:
            vm = self._inventory.vms.get(vm_id)
            if vm is None:
                raise KeyError(vm_id)
            vm.power_state = power_state
            return deepcopy(vm)

    async def update_vm_annotation(self, vm_id: str, annotation: str) -> VMRecord:
        async with self._lock:
            vm = self._inventory.vms.get(vm_id)
            if vm is None:
                raise KeyError(vm_id)
            vm.annotation = annotation
            return deepcopy(vm)

    async def update_host_maintenance(self, host_id: str, maintenance_mode: bool) -> HostRecord:
        async with self._lock:
            host = self._inventory.hosts.get(host_id)
            if host is None:
                raise KeyError(host_id)
            host.maintenance_mode = maintenance_mode
            return deepcopy(host)


inventory_store = InventoryStore()
