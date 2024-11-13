import asyncio
import sys
from typing import Optional

import psutil
from diskcache import Cache
from kasa import Device, Discover, KasaException
from kasa.iot import IotPlug
from platformdirs import user_cache_dir
from typing_extensions import cast


class SmartPlugController(object):
    _cache = Cache(user_cache_dir("my-speakers"))

    _plug_alias: str
    _plug: IotPlug

    def __init__(self) -> None:
        super().__init__()

    async def set_plug(self, plug_alias: str) -> None:
        self._plug_alias = plug_alias
        self._plug = await self._get_plug()

    async def turn_off(self) -> None:
        await self._plug.turn_off()

    async def turn_on(self) -> None:
        await self._plug.turn_on()

    def is_on(self) -> bool:
        # TODO: This function does return a bool, but they're using a 'type: ignore'
        # on the property so type checkers can't verify the type. I should open an
        # issue.
        return cast(bool, self._plug.is_on)

    async def _get_plug(self) -> IotPlug:
        plug = await self._get_plug_from_cache()
        if plug is not None:
            return plug

        plug = await self._find_plug()
        if plug is not None:
            return plug

        raise Exception(f"Unable to find a plug with this alias: {self._plug_alias}")

    async def _get_plug_from_cache(self) -> Optional[IotPlug]:
        if self._plug_alias in SmartPlugController._cache:
            ip_address = cast(str, SmartPlugController._cache[self._plug_alias])
            assert isinstance(ip_address, str)
            plug = IotPlug(ip_address)
            try:
                await plug.update()
                return plug
            except (KasaException, TimeoutError) as _:
                return None

        return None

    async def _find_plug(self) -> Optional[IotPlug]:
        for ip_address, device in (await self._discover_devices()).items():
            if device.alias == self._plug_alias and device.is_plug:
                SmartPlugController._cache[self._plug_alias] = ip_address
                return cast(IotPlug, device)

        return None

    # TODO: Kasa's discovery fails when I'm connected to a VPN. I don't completely
    # understand why, but I know that it has something to do with the broadcast
    # address that they use, 255.255.255.255. I'm guessing this is because that IP is
    # supposed to be an alias for 'this network' which will mean that of the VPN
    # network when I'm connected to it and not that of my actual wifi/ethernet
    # network. To get around this, I look for the correct broadcast address myself
    # using psutil which gives me all addresses assigned to each NIC on my machine. I
    # then try discovery using all the addresses that are marked as broadcast
    # addresses until I find a Kasa device.
    async def _discover_devices(self) -> dict[str, Device]:
        for broadcast_address in self._get_broadcast_addresses():
            devices = await Discover.discover(target=broadcast_address)
            if devices:
                return devices

        return {}

    def _get_broadcast_addresses(self) -> set[str]:
        return {
            address.broadcast
            for addresses in psutil.net_if_addrs().values()
            for address in addresses
            if address.broadcast is not None
        }


async def main() -> None:
    try:
        plug_controller = SmartPlugController()
        await plug_controller.set_plug(plug_alias="plug")
    except Exception:
        sys.exit(2)

    if len(sys.argv) == 1:
        sys.exit(0 if plug_controller.is_on() else 1)
    elif sys.argv[1] == "on":
        await plug_controller.turn_on()
    elif sys.argv[1] == "off":
        await plug_controller.turn_off()


if __name__ == "__main__":
    asyncio.run(main())
