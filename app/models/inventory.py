from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any


def _slug(value: str) -> str:
    return "".join(ch if ch.isalnum() else "-" for ch in value.lower()).strip("-")


@dataclass
class VMRecord:
    name: str
    power_state: str = "POWERED_OFF"
    guest_os: str = "OTHER"
    cpus: int = 1
    memory_mib: int = 1024
    nics: int = 1
    disks: int = 0
    disk_capacity_mib: int = 0
    datacenter: str = ""
    cluster: str = ""
    host: str = ""
    resource_pool: str = ""
    folder: str = ""
    uuid: str = ""
    vm_id: str = ""
    ip_address: str = ""
    dns_name: str = ""
    networks: list[str] = field(default_factory=list)
    annotation: str = ""
    template: bool = False
    extra: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.vm_id:
            self.vm_id = f"vm-{_slug(self.name) or 'unknown'}"


@dataclass
class HostRecord:
    name: str
    datacenter: str = ""
    cluster: str = ""
    cpu_model: str = ""
    cpu_mhz: int = 0
    num_cpu: int = 0
    cores: int = 0
    memory_mib: int = 0
    memory_usage_pct: float = 0.0
    cpu_usage_pct: float = 0.0
    esx_version: str = ""
    host_id: str = ""
    connection_state: str = "CONNECTED"
    maintenance_mode: bool = False
    extra: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.host_id:
            self.host_id = f"host-{_slug(self.name) or 'unknown'}"


@dataclass
class ClusterRecord:
    name: str
    datacenter: str = ""
    num_hosts: int = 0
    total_cpu_mhz: int = 0
    total_memory_mib: int = 0
    ha_enabled: bool = False
    drs_enabled: bool = False
    cluster_id: str = ""
    extra: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.cluster_id:
            self.cluster_id = f"domain-c{_slug(self.name) or 'unknown'}"


@dataclass
class DatastoreRecord:
    name: str
    type: str = "VMFS"
    capacity_mib: int = 0
    free_mib: int = 0
    used_mib: int = 0
    accessible: bool = True
    hosts: list[str] = field(default_factory=list)
    datastore_id: str = ""
    extra: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.datastore_id:
            self.datastore_id = f"datastore-{_slug(self.name) or 'unknown'}"


@dataclass
class NetworkRecord:
    name: str
    datacenter: str = ""
    network_type: str = "STANDARD_PORTGROUP"
    network_id: str = ""
    extra: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.network_id:
            scope = _slug(self.datacenter) if self.datacenter else "global"
            self.network_id = f"network-{_slug(self.name) or 'unknown'}-{scope}"


@dataclass
class ResourcePoolRecord:
    name: str
    datacenter: str = ""
    cluster: str = ""
    resource_pool_id: str = ""
    extra: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.resource_pool_id:
            self.resource_pool_id = f"resgroup-{_slug(self.name) or 'unknown'}"


@dataclass
class FolderRecord:
    name: str
    datacenter: str = ""
    folder_type: str = "VIRTUAL_MACHINE"
    folder_id: str = ""
    extra: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.folder_id:
            self.folder_id = f"group-v{_slug(self.name) or 'unknown'}"


@dataclass
class DatacenterRecord:
    name: str
    datacenter_id: str = ""
    extra: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.datacenter_id:
            self.datacenter_id = f"datacenter-{_slug(self.name) or 'unknown'}"


@dataclass
class Inventory:
    source_file: str = ""
    loaded_at: datetime | None = None
    vcenter_server: str = ""
    vcenter_uuid: str = ""
    product_version: str = ""
    build: str = ""
    datacenters: dict[str, DatacenterRecord] = field(default_factory=dict)
    clusters: dict[str, ClusterRecord] = field(default_factory=dict)
    hosts: dict[str, HostRecord] = field(default_factory=dict)
    vms: dict[str, VMRecord] = field(default_factory=dict)
    datastores: dict[str, DatastoreRecord] = field(default_factory=dict)
    networks: dict[str, NetworkRecord] = field(default_factory=dict)
    resource_pools: dict[str, ResourcePoolRecord] = field(default_factory=dict)
    folders: dict[str, FolderRecord] = field(default_factory=dict)
    vm_disks: dict[str, list[dict[str, Any]]] = field(default_factory=dict)
    vm_nics: dict[str, list[dict[str, Any]]] = field(default_factory=dict)
    stats: dict[str, int] = field(default_factory=dict)

    @property
    def is_loaded(self) -> bool:
        return bool(self.vms or self.hosts)
