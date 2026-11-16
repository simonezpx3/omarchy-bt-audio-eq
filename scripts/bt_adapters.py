"""BlueZ multi-adapter discovery, pairing, and state persistence helpers."""

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

LAST_DEVICE_PATH = Path.home() / ".local/state/simonez-btquality/last_device.json"
HEX_CHARS = set("0123456789abcdefABCDEF")


def is_mac(value: str) -> bool:
    """Return True if value is a valid 6-octet colon-separated MAC address."""
    parts = value.split(":")
    return len(parts) == 6 and all(len(p) == 2 and all(c in HEX_CHARS for c in p) for p in parts)


def card_to_mac(card_name: str) -> str:
    """Convert bluez_card.XX_XX_XX_XX_XX_XX to XX:XX:XX:XX:XX:XX."""
    if not card_name.startswith("bluez_card."):
        return ""
    raw = card_name[len("bluez_card.") :].split(".", 1)[0].replace("_", ":").upper()
    return raw if is_mac(raw) else ""


def load_last_bt_device() -> dict:
    """Load last seen Bluetooth audio device {mac, name} from state file."""
    try:
        if LAST_DEVICE_PATH.exists():
            data = json.loads(LAST_DEVICE_PATH.read_text(encoding="utf-8"))
            if isinstance(data, dict) and is_mac(str(data.get("mac", ""))):
                return data
    except (OSError, ValueError):
        pass
    return {}


def save_last_bt_device(mac: str, name: str = "") -> None:
    """Persist last seen Bluetooth audio device {mac, name} atomically (0600)."""
    if not is_mac(mac):
        return
    try:
        LAST_DEVICE_PATH.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp_name = tempfile.mkstemp(
            prefix=f".{LAST_DEVICE_PATH.name}.",
            dir=str(LAST_DEVICE_PATH.parent),
        )
        try:
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(json.dumps({"mac": mac, "name": name}))
            os.replace(tmp_name, LAST_DEVICE_PATH)
        except Exception:
            try:
                os.unlink(tmp_name)
            except OSError:
                pass
            raise
    except OSError:
        pass


def first_paired_device_on_adapter(ctrl_mac: str) -> tuple[str, str]:
    """Return (mac, name) of the first paired device on controller ctrl_mac."""
    if not ctrl_mac:
        return "", ""
    try:
        res = subprocess.run(
            ["bluetoothctl"],
            input=f"select {ctrl_mac}\ndevices Paired\nquit\n",
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        for line in res.stdout.splitlines():
            parts = line.strip().split(None, 2)
            if len(parts) >= 3 and parts[0] == "Device" and is_mac(parts[1]):
                return parts[1].upper(), parts[2].strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return "", ""


def _is_device_paired_on_adapter(ctrl_mac: str, dev_mac: str) -> bool:
    """Check if dev_mac is paired on controller ctrl_mac via bluetoothctl."""
    if not ctrl_mac or not dev_mac:
        return False
    try:
        res = subprocess.run(
            ["bluetoothctl"],
            input=f"select {ctrl_mac}\ninfo {dev_mac}\nquit\n",
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        return bool(re.search(r"Paired:\s*yes", res.stdout, re.IGNORECASE))
    except (OSError, subprocess.SubprocessError):
        return False


def _get_adapter_powered(hci_name: str) -> bool:
    """Return True if BlueZ adapter hci_name is powered on."""
    if not re.match(r"^hci\d+$", hci_name):
        return False
    try:
        res = subprocess.run(
            [
                "busctl",
                "get-property",
                "org.bluez",
                f"/org/bluez/{hci_name}",
                "org.bluez.Adapter1",
                "Powered",
            ],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        return res.returncode == 0 and "true" in res.stdout.lower()
    except (OSError, subprocess.SubprocessError):
        return False


def get_bt_adapters(active_hci: str = "", active_card: str = "") -> list[dict]:
    """Return available Bluetooth adapters with active/default/powered/paired status."""
    mac_to_hci: dict[str, str] = {}
    bt_dir = Path("/sys/class/bluetooth")
    if bt_dir.exists():
        for entry in bt_dir.iterdir():
            if not re.match(r"^hci\d+$", entry.name):
                continue
            try:
                dbus_res = subprocess.run(
                    [
                        "busctl",
                        "get-property",
                        "org.bluez",
                        f"/org/bluez/{entry.name}",
                        "org.bluez.Adapter1",
                        "Address",
                    ],
                    capture_output=True,
                    text=True,
                    timeout=2,
                    check=False,
                )
                quoted = dbus_res.stdout.split('"')
                if dbus_res.returncode == 0 and len(quoted) >= 2 and is_mac(quoted[1]):
                    mac_to_hci[quoted[1].upper()] = entry.name
            except (OSError, subprocess.SubprocessError):
                continue

    adapters: list[dict] = []
    try:
        res = subprocess.run(
            ["bluetoothctl", "list"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                parts = line.strip().split(None, 2)
                if len(parts) < 3 or parts[0] != "Controller" or not is_mac(parts[1]):
                    continue
                mac = parts[1].upper()
                rest = parts[2].strip()
                is_default = rest.endswith("default]")
                alias = rest.rsplit(" ", 1)[0].strip() if is_default and " " in rest else rest
                hci_name = mac_to_hci.get(mac, "")
                if not hci_name:
                    continue
                adapters.append({
                    "hci": hci_name,
                    "label": hci_name.upper(),
                    "address": mac,
                    "name": alias,
                    "default": is_default,
                    "active": hci_name == active_hci,
                    "powered": _get_adapter_powered(hci_name),
                    "paired": False,
                })
    except (OSError, subprocess.SubprocessError):
        return []

    adapters.sort(key=lambda item: int(item["hci"][3:]))
    dev_mac = card_to_mac(active_card) or load_last_bt_device().get("mac", "")
    if dev_mac and len(adapters) >= 2:
        for item in adapters:
            item["paired"] = (
                True
                if item["active"]
                else _is_device_paired_on_adapter(item["address"], dev_mac)
            )
    elif len(adapters) >= 2:
        for item in adapters:
            paired_mac, _ = first_paired_device_on_adapter(item["address"])
            item["paired"] = bool(paired_mac)
    elif dev_mac:
        for item in adapters:
            item["paired"] = item["active"]
    return adapters
