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
import itertools
import sys
import traceback
from argparse import ArgumentParser, Namespace
from typing import Iterable, Optional, Self

import psutil
from diskcache import Cache
from kasa import Device, Discover, KasaException
from kasa.iot import IotPlug
from platformdirs import user_cache_dir
from typing_extensions import cast

CLI_NAME = "speakerctl"


class KasaPlug:
    # Key: plug alias, Value: IP address
    _ip_address_cache = Cache(user_cache_dir(CLI_NAME))

    _alias = "plug"

    _plug: IotPlug

    @classmethod
    async def connect(cls, attempts: int) -> Self:
        instance = cls()
        instance._plug = await instance._find_plug(attempts)

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

    @classmethod
    async def _find_plug(cls, attempts: int) -> IotPlug:
        plug = await cls._get_plug_from_cache()
        if plug is not None:
            return plug

        plug = await cls._discover_plug(attempts)
        if plug is not None:
            cls._add_plug_to_cache(plug)
            return plug

        raise Exception(f"Unable to find a plug with alias: {cls._alias}")

    @classmethod
    def _add_plug_to_cache(cls, plug: IotPlug) -> None:
        cls._ip_address_cache[plug.alias] = plug.host

    @classmethod
    async def _get_plug_from_cache(cls) -> Optional[IotPlug]:
        if cls._alias not in cls._ip_address_cache:
            return None

        ip_address = cls._ip_address_cache[cls._alias]
        assert isinstance(ip_address, str)

        try:
            # TODO: The connect method is defined on the Device class, but I think
            # the subclasses should override it to ensure that the device returned
            # matches their class.
            device = await IotPlug.connect(host=ip_address)
        except (KasaException, TimeoutError):
            del cls._ip_address_cache[cls._alias]
            return None

        if isinstance(device, IotPlug) and device.alias == cls._alias:
            return device
        else:
            del cls._ip_address_cache[cls._alias]
            return None

    @classmethod
    async def _discover_plug(cls, attempts: int) -> Optional[IotPlug]:
        for unused in range(attempts):
            for device in await cls._discover_devices():
                if isinstance(device, IotPlug) and device.alias == cls._alias:
                    return device

        return None

    @classmethod
    async def _discover_devices(cls) -> Iterable[Device]:
        # TODO: Kasa's discovery fails when I'm connected to a VPN. This is because
        # the default broadcast address (255.255.255.255) is an alias for 'this
        # network' which will mean that of my VPN's virtual network card when I'm
        # connected to it and not that of my actual wifi/ethernet network card. To
        # get around this, I run discovery on all my network cards' broadcast
        # addresses.
        devices_dicts_per_broadcast_address = await asyncio.gather(
            *(
                Discover.discover(target=address)
                for address in cls._get_broadcast_addresses()
            )
        )
        devices_per_broadcast_address = (
            device_dict.values() for device_dict in devices_dicts_per_broadcast_address
        )

        return itertools.chain(*devices_per_broadcast_address)

    @classmethod
    def _get_broadcast_addresses(cls) -> Iterable[str]:
        addresses_per_network_card = psutil.net_if_addrs().values()
        return (
            address.broadcast
            for addresses in addresses_per_network_card
            for address in addresses
            if address.broadcast is not None
        )


def parse_args() -> Namespace:
    class MaxWidthHelpFormatter(argparse.HelpFormatter):
        def __init__(self, prog: str) -> None:
            super().__init__(prog, width=100)

    parser = ArgumentParser(
        prog=CLI_NAME,
        description="Control a Kasa smart plug.",
        formatter_class=MaxWidthHelpFormatter,
    )

    parser.add_argument(
        "--attempts",
        type=int,
        default=1,
        help="The number of discovery attempts to make",
    )
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
    plug = await KasaPlug.connect(args.attempts)
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
        traceback.print_exc()
        sys.exit(2)
