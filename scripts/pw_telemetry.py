"""PipeWire and BlueZ hardware/codec telemetry helpers."""

import re
import subprocess
from pathlib import Path

from eq_manager import (
    AAC_MODE_RE,
    AAC_MODES,
    AAC_QUALITY_OPTIONS,
    CONF_PATH,
    LDAC_QUALITY_OPTIONS,
    QUALITY_RE,
    VALID_MODES,
    _load_pw_dump,
)


def read_quality() -> str:
    if not CONF_PATH.exists():
        return "mq"
    text = CONF_PATH.read_text(encoding="utf-8")
    match = QUALITY_RE.search(text)
    if not match:
        return "mq"
    val = match.group(2).strip().lower()
    return val if val in VALID_MODES else "mq"


def read_aac_mode() -> str:
    if not CONF_PATH.exists():
        return "5"
    text = CONF_PATH.read_text(encoding="utf-8")
    match = AAC_MODE_RE.search(text)
    if not match:
        return "5"
    val = match.group(2).strip()
    return val if val in AAC_MODES else "5"


def get_bt_device_info() -> tuple[str, str, str, str, list[dict]]:
    try:
        res = subprocess.run(
            ["pactl", "list", "cards"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if res.returncode != 0:
            return "", "", "", "", []
        candidates: list[tuple[str, str, str, str, list[dict]]] = []
        for block in res.stdout.split("Card #"):
            if "bluez_card." not in block:
                continue
            card_m = re.search(r"Name:\s*(\S+)", block)
            alias_m = re.search(r'device\.alias\s*=\s*"([^"]+)"', block)
            prof_m = re.search(r"Active Profile:\s*(\S+)", block)
            hci_m = re.search(r'api\.bluez5\.path\s*=\s*"/org/bluez/(hci\d+)/', block)
            active_prof = prof_m.group(1) if prof_m else ""
            codecs: list[dict] = []
            for line in block.splitlines():
                cm = re.match(r"^\s*(a2dp-sink\S*):\s*.*codec\s+([^)\s]+).*available:\s*yes", line)
                if cm:
                    p_name = cm.group(1).strip()
                    c_label = cm.group(2).strip().upper()
                    codecs.append({
                        "profile": p_name,
                        "label": c_label,
                        "active": p_name == active_prof,
                    })
            candidates.append((
                alias_m.group(1) if alias_m else "Bluetooth",
                active_prof,
                hci_m.group(1) if hci_m else "",
                card_m.group(1) if card_m else "",
                codecs,
            ))
        for item in candidates:
            if item[1].startswith("a2dp-sink"):
                return item
        for item in candidates:
            if item[4]:
                return item
        if candidates:
            return candidates[0]
    except (OSError, subprocess.SubprocessError, ValueError):
        return "", "", "", "", []
    return "", "", "", "", []


def get_sink_telemetry() -> dict:
    data = {
        "codec": "",
        "sample": "",
        "liveQuality": "",
        "volume": -1,
        "muted": False,
        "systemDevice": "",
        "sinkName": "",
        "isBluetooth": False,
    }
    try:
        res = subprocess.run(
            ["pactl", "list", "sinks"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if res.returncode != 0:
            return data
        blocks = res.stdout.split("Sink #")
        for block in blocks:
            if "bluez_output." not in block:
                continue
            name_m = re.search(r"Name:\s*(\S+)", block)
            codec_m = re.search(r'api\.bluez5\.codec\s*=\s*"([^"]+)"', block)
            sample_m = re.search(r"Sample Specification:\s*(.+)", block)
            qual_m = re.search(r'bluez5\.a2dp\.ldac\.quality\s*=\s*"([^"]+)"', block)
            vol_m = re.search(r"Volume:.*?(\d+)%", block)
            mute_m = re.search(r"Mute:\s*(yes|no)", block)
            data["sinkName"] = name_m.group(1).strip() if name_m else ""
            data["isBluetooth"] = True
            data["codec"] = codec_m.group(1).upper() if codec_m else ""
            data["sample"] = sample_m.group(1).strip() if sample_m else ""
            data["liveQuality"] = qual_m.group(1).strip().lower() if qual_m else ""
            data["volume"] = int(vol_m.group(1)) if vol_m else -1
            data["muted"] = bool(mute_m and mute_m.group(1) == "yes")
            return data

        # No BT sink connected: inspect active system sink (e.g. ALSA speakers/DAC)
        default_sink = ""
        ds = subprocess.run(
            ["pactl", "get-default-sink"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        if ds.returncode == 0:
            cand = ds.stdout.strip()
            if cand and cand != "effect_input.bt_eq" and "bluez_output." not in cand:
                default_sink = cand

        sys_block = ""
        for block in blocks:
            name_m = re.search(r"Name:\s*(\S+)", block)
            if not name_m:
                continue
            sname = name_m.group(1).strip()
            if sname == "effect_input.bt_eq" or "bluez_output." in sname:
                continue
            if default_sink and sname == default_sink:
                sys_block = block
                break
            if not sys_block or "alsa_output." in sname:
                sys_block = block

        if sys_block:
            sname_m = re.search(r"Name:\s*(\S+)", sys_block)
            desc_m = re.search(r"Description:\s*(.+)", sys_block)
            sample_m = re.search(r"Sample Specification:\s*(.+)", sys_block)
            vol_m = re.search(r"Volume:.*?(\d+)%", sys_block)
            mute_m = re.search(r"Mute:\s*(yes|no)", sys_block)
            data["sinkName"] = sname_m.group(1).strip() if sname_m else ""
            data["isBluetooth"] = False
            data["systemDevice"] = desc_m.group(1).strip() if desc_m else "System Audio"
            sample_str = sample_m.group(1).strip() if sample_m else ""
            hz_m = re.search(r"(\d+)\s*Hz", sample_str)
            if hz_m:
                khz = int(hz_m.group(1)) / 1000.0
                khz_str = f"{int(khz)}k" if khz.is_integer() else f"{khz:.1f}k"
                data["codec"] = f"PCM {khz_str}"
            else:
                data["codec"] = "PCM"
            data["sample"] = sample_str
            data["volume"] = int(vol_m.group(1)) if vol_m else -1
            data["muted"] = bool(mute_m and mute_m.group(1) == "yes")
    except (OSError, subprocess.SubprocessError, ValueError):
        return data
    return data


def get_pw_top_telemetry(target_sink: str = "") -> dict:
    data = {
        "streamState": "",
        "quant": 0,
        "rate": 0,
        "busy": "",
        "xruns": 0,
    }
    try:
        res = subprocess.run(
            ["pw-top", "-b", "-n", "1"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if res.returncode != 0:
            return data
        for line in res.stdout.splitlines():
            if target_sink:
                if target_sink not in line:
                    continue
            elif "bluez_output." not in line and "alsa_output." not in line:
                continue
            parts = line.split()
            if len(parts) >= 9:
                data["streamState"] = parts[0]
                data["quant"] = int(parts[2]) if parts[2].isdigit() else 0
                data["rate"] = int(parts[3]) if parts[3].isdigit() else 0
                data["busy"] = parts[5]
                data["xruns"] = int(parts[8]) if parts[8].isdigit() else 0
            break
    except (OSError, subprocess.SubprocessError, ValueError):
        return data
    return data


def get_usb_power_telemetry(hci: str = "") -> dict:
    data = {"hci": hci, "usbPower": "", "usbStatus": ""}
    try:
        candidates = [Path(f"/sys/class/bluetooth/{hci}/device")] if hci else sorted(Path("/sys/class/bluetooth").glob("hci*/device"))
        for bt_path in candidates:
            if not bt_path.exists():
                continue
            bt_dev = bt_path.resolve()
            for parent in [bt_dev, *bt_dev.parents]:
                ctrl = parent / "power/control"
                vid = parent / "idVendor"
                if ctrl.exists() and vid.exists():
                    stat = parent / "power/runtime_status"
                    data["hci"] = data["hci"] or bt_path.parent.name
                    data["usbPower"] = ctrl.read_text().strip()
                    data["usbStatus"] = stat.read_text().strip() if stat.exists() else ""
                    return data
    except (OSError, subprocess.SubprocessError, ValueError):
        return data
    return data


def get_quality_spec(active_codec: str) -> dict:
    codec = (active_codec or "LDAC").upper()
    if codec == "LDAC":
        q = read_quality()
        return {
            "configurable": True,
            "key": q,
            "label": VALID_MODES.get(q, q.upper()),
            "options": LDAC_QUALITY_OPTIONS,
            "note": "",
        }
    if codec == "AAC":
        m = read_aac_mode()
        return {
            "configurable": True,
            "key": m,
            "label": AAC_MODES.get(m, {}).get("title", f"VBR {m}"),
            "options": AAC_QUALITY_OPTIONS,
            "note": "",
        }
    if codec.startswith("PCM"):
        return {
            "configurable": False,
            "key": "",
            "label": active_codec,
            "options": [],
            "note": f"System output ({active_codec})",
        }
    return {
        "configurable": False,
        "key": "",
        "label": codec,
        "options": [],
        "note": f"Fixed bitrate ({codec} profile)",
    }


STANDARD_RATES = [44100, 48000, 88200, 96000, 192000]


def _format_rate_label(hz: int) -> str:
    khz = hz / 1000.0
    return f"{int(khz)}k" if khz.is_integer() else f"{khz:.1f}k"


def get_system_rate_info() -> tuple[int, int]:
    force_rate = 0
    clock_rate = 48000
    try:
        res = subprocess.run(
            ["pw-metadata", "-n", "settings", "0"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                if "key:'clock.force-rate'" in line:
                    m = re.search(r"value:'(\d+)'", line)
                    if m:
                        force_rate = int(m.group(1))
                elif "key:'clock.rate'" in line:
                    m = re.search(r"value:'(\d+)'", line)
                    if m:
                        clock_rate = int(m.group(1))
    except (OSError, subprocess.SubprocessError, ValueError):
        return force_rate, clock_rate
    return force_rate, clock_rate


def get_sink_supported_rates(active_codec: str, pw_nodes: list[dict] | None = None) -> list[int]:
    codec = (active_codec or "LDAC").upper()
    is_pcm = codec.startswith("PCM")
    try:
        nodes = pw_nodes if pw_nodes is not None else _load_pw_dump()
        for node in nodes:
            props = (node.get("info") or {}).get("props") or {}
            nname = str(props.get("node.name", ""))
            if not nname or nname == "effect_input.bt_eq":
                continue
            if props.get("media.class") != "Audio/Sink":
                continue
            if is_pcm and "bluez_output." in nname:
                continue
            if not is_pcm and "bluez_output." not in nname:
                continue
            ef = ((node.get("info") or {}).get("params") or {}).get("EnumFormat") or []
            concrete_rates: list[int] = []
            for fmt in ef:
                r = fmt.get("rate")
                if isinstance(r, dict) and "min" in r and "max" in r:
                    rmin, rmax = int(r["min"]), int(r["max"])
                    matched = [sr for sr in STANDARD_RATES if rmin <= sr <= rmax]
                    if matched:
                        return matched
                elif isinstance(r, int) and r > 0:
                    concrete_rates.append(r)
            if concrete_rates:
                return sorted(set(concrete_rates))
    except (OSError, subprocess.SubprocessError, ValueError, TypeError):
        if is_pcm:
            return [44100, 48000, 96000]
        return [44100, 48000]
    if is_pcm:
        return [44100, 48000, 96000]
    return [44100, 48000]


def set_sample_rate(hz_str: str, build_status_fn=None) -> dict:
    try:
        hz = int(hz_str.strip())
    except ValueError:
        return (build_status_fn or (lambda **kw: kw))(ok=False, error=f"Invalid sample rate: {hz_str}")
    if hz != 0 and hz not in STANDARD_RATES:
        return (build_status_fn or (lambda **kw: kw))(ok=False, error=f"Unsupported sample rate: {hz}")

    allowed_val = "[ 44100 48000 88200 96000 192000 ]"
    r1 = subprocess.run(
        ["pw-metadata", "-n", "settings", "0", "clock.allowed-rates", allowed_val],
        capture_output=True,
        text=True,
        timeout=3,
        check=False,
    )
    r2 = subprocess.run(
        ["pw-metadata", "-n", "settings", "0", "clock.force-rate", str(hz)],
        capture_output=True,
        text=True,
        timeout=3,
        check=False,
    )
    if r1.returncode != 0 or r2.returncode != 0:
        err = (r2.stderr or r1.stderr).strip() or "Failed to set sample rate via pw-metadata"
        return (build_status_fn or (lambda **kw: kw))(ok=False, error=err)
    return (build_status_fn or (lambda **kw: kw))(ok=True)

