import asyncio
import sys
from typing import Optional

import psutil
from diskcache import Cache
from kasa import Discover, SmartDevice, SmartDeviceException, SmartPlug
from platformdirs import user_cache_dir
from typing_extensions import cast


class SmartPlugController(object):
    _cache = Cache(user_cache_dir("my-speakers"))

    _plug_alias: str
    _plug: SmartPlug

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

    async def _get_plug(self) -> SmartPlug:
        plug = await self._get_plug_from_cache()
        if plug is not None:
            return plug

        plug = await self._find_plug()
        if plug is not None:
            return plug

        raise Exception(f"Unable to find a plug with this alias: {self._plug_alias}")

    async def _get_plug_from_cache(self) -> Optional[SmartPlug]:
        if self._plug_alias in SmartPlugController._cache:
            ip_address = cast(str, SmartPlugController._cache[self._plug_alias])
            assert isinstance(ip_address, str)
            plug = SmartPlug(ip_address)
            try:
                # Creating a SmartPlug instance successfully does not necessarily
                # mean that there is a smart plug at that ip address since requests
                # won't be made to the plug until you call a method on the SmartPlug.
                # To make sure there's still a smart plug at this ip address I'm
                # calling SmartPlug.update().
                await plug.update()
                return plug
            except (SmartDeviceException, TimeoutError) as _:
                return None

        return None

    async def _find_plug(self) -> Optional[SmartPlug]:
        for ip_address, device in (await self._discover_devices()).items():
            if device.alias == self._plug_alias and device.is_plug:
                self._add_plug_address_to_cache(ip_address)
                return cast(SmartPlug, device)

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
    async def _discover_devices(self) -> dict[str, SmartDevice]:
        devices_per_broadcast_address = [
            await self._discover_devices_for_broadcast_address(address)
            for address in self._get_broadcast_addresses()
        ]
        return next(
            filter(bool, devices_per_broadcast_address),
            cast(dict[str, SmartDevice], {}),
        )

    async def _discover_devices_for_broadcast_address(
        self, broadcast_address: str
    ) -> dict[str, SmartDevice]:
        return await Discover.discover(target=broadcast_address)

    def _get_broadcast_addresses(self) -> set[str]:
        return {
            address.broadcast
            for addresses in psutil.net_if_addrs().values()
            for address in addresses
            if address.broadcast is not None
        }

    def _add_plug_address_to_cache(self, ip_address: str) -> None:
        SmartPlugController._cache[self._plug_alias] = ip_address


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
