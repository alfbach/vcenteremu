from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="VCENTEREMU_", env_file=".env")

    host: str = "0.0.0.0"
    port: int = 8443
    workers: int = 1
    api_username: str = "administrator@vsphere.local"
    api_password: str = "Emulator123!"
    upload_dir: str = "/var/lib/vcenteremu/uploads"
    max_upload_mb: int = 256
    vcenter_name: str = "vcenteremu.local"
    vcenter_version: str = "8.0.3.00000"
    product_name: str = "VMware vCenter Server"
    session_ttl_seconds: int = 3600
    auto_load_xlsx: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings()
