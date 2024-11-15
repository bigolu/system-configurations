import argparse
import asyncio
import sys
from argparse import ArgumentParser, Namespace
from typing import Optional, TypeGuard

import psutil
from diskcache import Cache
from kasa import Device, DeviceType, Discover, KasaException
from kasa.iot import IotPlug
from platformdirs import user_cache_dir
from typing_extensions import cast


class SmartPlugController(object):
    _cache = Cache(user_cache_dir("plugctl"))

    _plug: Optional[IotPlug]

    def __init__(self) -> None:
        super().__init__()

    async def connect(self, alias: str) -> None:
        self._plug = await self._discover_plug(alias)
        if self._plug is None:
            raise Exception(f"Unable to find a plug with alias: {alias}")

    async def turn_off(self) -> None:
        assert self._is_plug_present(self._plug)
        await self._plug.turn_off()

    async def turn_on(self) -> None:
        assert self._is_plug_present(self._plug)
        await self._plug.turn_on()

    async def is_on(self) -> bool:
        assert self._is_plug_present(self._plug)
        await self._plug.update()
        # TODO: This function does return a bool, but they're using a 'type: ignore'
        # on the property so type checkers can't verify the type. I should open an
        # issue.
        return cast(bool, self._plug.is_on)

    def _is_plug_present(self, plug: Optional[IotPlug]) -> TypeGuard[IotPlug]:
        if plug is not None:
            return True
        else:
            raise Exception("You need to be connected to a plug to call this method")

    async def _discover_plug(self, alias: str) -> Optional[IotPlug]:
        plug = await self._get_plug_from_cache(alias)
        if plug is not None:
            return plug

        for ip_address, device in (await self._discover_devices()).items():
            if device.alias == alias and self._is_plug(device):
                SmartPlugController._cache[alias] = ip_address
                return device

        return None

    def _is_plug(self, device: Device) -> TypeGuard[IotPlug]:
        return device.device_type is DeviceType.Plug

    async def _get_plug_from_cache(self, alias: str) -> Optional[IotPlug]:
        if alias not in SmartPlugController._cache:
            return None

        ip_address = SmartPlugController._cache[alias]
        assert isinstance(ip_address, str)

        plug = IotPlug(ip_address)
        try:
            await plug.update()
        except (KasaException, TimeoutError):
            del self._cache[alias]
            return None

        return plug

    # TODO: Kasa's discovery fails when I'm connected to a VPN. This is because the
    # default broadcast address (255.255.255.255) is an alias for 'this network'
    # which will mean that of the VPN network when I'm connected to it and not that
    # of my actual wifi/ethernet network. To get around this, I look for the correct
    # broadcast address myself using psutil which gives me all addresses assigned to
    # each NIC on my machine. I then try discovery using all the addresses that are
    # marked as broadcast addresses until I find a Kasa device.
    async def _discover_devices(self) -> dict[str, Device]:
        devices_per_broadcast_address = await asyncio.gather(
            *[
                Discover.discover(target=address)
                for address in self._get_broadcast_addresses()
            ]
        )

        for devices in devices_per_broadcast_address:
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


def parse_args() -> Namespace:
    class MaxWidthHelpFormatter(argparse.HelpFormatter):
        def __init__(self, prog: str) -> None:
            super().__init__(prog, width=80)

    parser = ArgumentParser(
        description="Control a Kasa smart plug.", formatter_class=MaxWidthHelpFormatter
    )

    parser.add_argument("alias", help="The plug's name")
    parser.add_argument(
        "command",
        nargs="?",
        choices=["status", "on", "off"],
        default="status",
        help="The action to perform on the plug. The default is status. status exits with 0 if the plug is on and 1 if it's off",
    )

    return parser.parse_args()


async def main() -> None:
    args = parse_args()

    plug_controller = SmartPlugController()
    await plug_controller.connect(args.alias)

    match args.command:
        case "status":
            sys.exit(0 if await plug_controller.is_on() else 1)
        case "on":
            await plug_controller.turn_on()
        case "off":
            await plug_controller.turn_off()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception:
        sys.exit(2)
