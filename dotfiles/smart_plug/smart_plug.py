"""
Command-Line tool for controlling a Kasa smart plug. The kasa library used here
also has a CLI, but this one has two additional features:
    - Support for discovering devices when connected to a VPN without having to
      explicitly set a broadcast address.
    - Caching the IP address for a device

TODO: Consider upstreaming these features
"""

import argparse
import asyncio
import operator
import sys
from argparse import ArgumentParser, Namespace
from functools import reduce
from typing import Optional, Self

import psutil
from diskcache import Cache
from kasa import Device, Discover, KasaException
from kasa.iot import IotPlug
from platformdirs import user_cache_dir
from typing_extensions import cast

CLI_NAME = "plugctl"


class KasaPlug:
    # Key: plug alias, Value: IP address
    _ip_address_cache = Cache(user_cache_dir(CLI_NAME))

    _plug: IotPlug

    @classmethod
    async def connect(cls, alias: str) -> Self:
        instance = cls()

        plug = await instance._discover_plug(alias)
        if plug is not None:
            instance._plug = plug
        else:
            raise Exception(f"Unable to find a plug with alias: {alias}")

        return instance

    async def turn_off(self) -> None:
        await self._plug.turn_off()

    async def turn_on(self) -> None:
        await self._plug.turn_on()

    async def is_on(self) -> bool:
        await self._plug.update()
        # TODO: This function does return a bool, but they're using a 'type: ignore'
        # on the property so type checkers can't verify the type. I should open an
        # issue.
        return cast(bool, self._plug.is_on)

    async def _discover_plug(self, alias: str) -> Optional[IotPlug]:
        plug = await self._get_plug_from_cache(alias)
        if plug is not None:
            return plug

        devices_by_ip_address = await self._discover_devices()
        for ip_address, device in devices_by_ip_address.items():
            if device.alias == alias and isinstance(device, IotPlug):
                self._add_plug_to_cache(device)
                return device

        return None

    def _add_plug_to_cache(self, plug: IotPlug) -> None:
        KasaPlug._ip_address_cache[plug.alias] = plug.host

    async def _get_plug_from_cache(self, alias: str) -> Optional[IotPlug]:
        if alias not in KasaPlug._ip_address_cache:
            return None

        ip_address = KasaPlug._ip_address_cache[alias]
        assert isinstance(ip_address, str)

        try:
            # TODO: This returns a Device, but I think it should return an IotPlug.
            device = await IotPlug.connect(host=ip_address)
        except (KasaException, TimeoutError):
            del KasaPlug._ip_address_cache[alias]
            return None

        if isinstance(device, IotPlug):
            return device
        else:
            del KasaPlug._ip_address_cache[alias]
            return None

    async def _discover_devices(self) -> dict[str, Device]:
        # TODO: Kasa's discovery fails when I'm connected to a VPN. This is because
        # the default broadcast address (255.255.255.255) is an alias for 'this
        # network' which will mean that of the VPN network when I'm connected to it
        # and not that of my actual wifi/ethernet network. To get around this, I run
        # discovery on all the broadcast addresses found on my machine.
        discovery_awaitables_per_broadcast_address = [
            Discover.discover(target=address)
            for address in self._get_broadcast_addresses()
        ]
        devices_per_broadcast_address = await asyncio.gather(
            *discovery_awaitables_per_broadcast_address
        )
        merged_devices: dict[str, Device] = reduce(
            operator.or_, devices_per_broadcast_address, {}
        )

        return merged_devices

    def _get_broadcast_addresses(self) -> set[str]:
        ip_addresses_per_network_card = psutil.net_if_addrs().values()
        return {
            address.broadcast
            for addresses in ip_addresses_per_network_card
            for address in addresses
            if address.broadcast is not None
        }


def parse_args() -> Namespace:
    class MaxWidthHelpFormatter(argparse.HelpFormatter):
        def __init__(self, prog: str) -> None:
            super().__init__(prog, width=100)

    parser = ArgumentParser(
        prog=CLI_NAME,
        description="Control a Kasa smart plug.",
        formatter_class=MaxWidthHelpFormatter,
    )

    parser.add_argument("alias", help="The plug's name")
    parser.add_argument(
        "command",
        nargs="?",
        choices=["status", "on", "off"],
        default="status",
        help="""
            The action to perform on the plug. The default is status. status exits
            with 0 if the plug is on and 1 if it's off.
        """,
    )

    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    plug = await KasaPlug.connect(args.alias)
    match args.command:
        case "status":
            exit_code = 0 if await plug.is_on() else 1
            sys.exit(exit_code)
        case "on":
            await plug.turn_on()
        case "off":
            await plug.turn_off()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception:
        sys.exit(2)
