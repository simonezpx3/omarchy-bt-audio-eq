#!/usr/bin/env python3
"""CLI entrypoint for BT & Audio EQ Omarchy plugin."""

import json
import re
import subprocess
import sys
import time

from eq_manager import (
    AAC_MODE_RE,
    AAC_MODES,
    ALIASES,
    CONF_PATH,
    EQ_PRESETS,
    PIPEWIRE_EQ_CONF,  # noqa: F401
    VALID_MODES,
    _active_graphic_overlay,
    _atomic_write_text,
    _combine_with_autoeq,
    _extract_overlay,
    _fetch_bounded_text,  # noqa: F401
    _load_pw_dump,
    apply_eq_live,
    find_eq_node_id,
    load_eq_state,
    save_eq_state,
    search_autoeq,
    write_pipewire_eq_conf,  # noqa: F401
)
from eq_manager import (
    apply_autoeq as _eq_apply_autoeq,
)
from bt_adapters import (
    card_to_mac,
    first_paired_device_on_adapter,
    get_bt_adapters,
    load_last_bt_device,
    save_last_bt_device,
)
from pw_telemetry import (
    _format_rate_label,
    get_bt_device_info,
    get_pw_top_telemetry,
    get_quality_spec,
    get_sink_supported_rates,
    get_sink_telemetry,
    get_system_rate_info,
    get_usb_power_telemetry,
    read_aac_mode,
    read_quality,
)
from pw_telemetry import (
    set_sample_rate as _pw_set_sample_rate,
)


def apply_autoeq(rel_path: str, label: str = "") -> dict:
    return _eq_apply_autoeq(rel_path, label, build_status_fn=build_status)


def set_sample_rate(hz_str: str) -> dict:
    return _pw_set_sample_rate(hz_str, build_status_fn=build_status)


def build_status(ok: bool = True, error: str = "") -> dict:
    quality = read_quality()
    aac_mode = read_aac_mode()
    device, profile, hci, card, codecs = get_bt_device_info()
    if card:
        active_mac = card_to_mac(card)
        if active_mac:
            save_last_bt_device(active_mac, device)
    telemetry = {}
    telemetry.update(get_sink_telemetry())
    telemetry.update(get_pw_top_telemetry(telemetry.get("sinkName", "")))
    telemetry.update(get_usb_power_telemetry(hci))
    pw_nodes = _load_pw_dump()
    active_codec = telemetry.get("codec") or next((c["label"] for c in codecs if c.get("active")), "")
    bt_connected = bool(device) and not active_codec.upper().startswith("PCM")
    eq_state = load_eq_state()
    if not bt_connected and eq_state.get("autoeqActive") and not eq_state.get("autoeqAutoPaused"):
        overlay = _extract_overlay(eq_state.get("bands", [0.0] * 10), eq_state.get("autoeqBaseBands", [0.0] * 10))
        eq_state["autoeqAutoPaused"] = True
        eq_state["autoeqActive"] = False
        eq_state["bands"] = overlay
        save_eq_state(eq_state)
        apply_eq_live(eq_state, pw_nodes=pw_nodes)
    elif bt_connected and eq_state.get("autoeqAutoPaused") and eq_state.get("autoeqFilters"):
        overlay = _active_graphic_overlay(eq_state)
        eq_state["autoeqAutoPaused"] = False
        eq_state["autoeqActive"] = True
        eq_state["bands"] = _combine_with_autoeq(overlay, eq_state.get("autoeqBaseBands", [0.0] * 10))
        eq_state["autoeqBands"] = list(eq_state["bands"])
        save_eq_state(eq_state)
        apply_eq_live(eq_state, pw_nodes=pw_nodes)
    elif bt_connected and eq_state.get("enabled"):
        ds = subprocess.run(
            ["pactl", "get-default-sink"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        if ds.returncode == 0 and ds.stdout.strip() != "effect_input.bt_eq" and find_eq_node_id(pw_nodes=pw_nodes):
            subprocess.run(
                ["pactl", "set-default-sink", "effect_input.bt_eq"],
                capture_output=True,
                text=True,
                timeout=3,
                check=False,
            )

    qspec = get_quality_spec(active_codec)
    force_rate, clock_rate = get_system_rate_info()
    supported_rates = get_sink_supported_rates(active_codec, pw_nodes=pw_nodes)
    hz_m = re.search(r"(\d+)\s*Hz", telemetry.get("sample", ""))
    sample_hz = int(hz_m.group(1)) if hz_m else 0
    if active_codec.upper().startswith("PCM") and force_rate > 0:
        active_rate = force_rate
    else:
        active_rate = telemetry.get("rate") or sample_hz or (force_rate if force_rate > 0 else clock_rate)
    return {
        "ok": ok,
        "quality": qspec["key"] if qspec["configurable"] else quality,
        "ldacQuality": quality,
        "aacMode": aac_mode,
        "label": qspec["label"] if qspec["configurable"] else VALID_MODES.get(quality, quality.upper()),
        "qualityConfigurable": qspec["configurable"],
        "qualityOptions": qspec["options"],
        "qualityNote": qspec["note"],
        "rateOptions": [{"hz": r, "label": _format_rate_label(r)} for r in supported_rates],
        "activeRate": active_rate,
        "forceRate": force_rate,
        "device": device,
        "profile": profile,
        "card": card,
        "adapters": get_bt_adapters(active_hci=hci, active_card=card),
        "codecs": codecs,
        "telemetry": telemetry,
        "eq": eq_state,
        "error": error,
    }


def set_codec(target_profile: str) -> dict:
    prof = target_profile.strip()
    if not prof.startswith("a2dp-sink"):
        return build_status(ok=False, error=f"Unsupported codec profile: {target_profile}")
    _, _, _, card, _ = get_bt_device_info()
    if not card:
        return build_status(ok=False, error="No Bluetooth audio card connected")
    res = subprocess.run(
        ["pactl", "set-card-profile", card, prof],
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )
    if res.returncode != 0:
        return build_status(ok=False, error=res.stderr.strip() or "Failed to switch codec")
    time.sleep(0.3)
    return build_status(ok=True)


def _upsert_wireplumber_prop(prop_name: str, prop_regex: re.Pattern, value_literal: str) -> None:
    CONF_PATH.parent.mkdir(parents=True, exist_ok=True)
    if CONF_PATH.exists():
        text = CONF_PATH.read_text(encoding="utf-8")
        if prop_regex.search(text):
            updated = prop_regex.sub(rf"\g<1>{value_literal}", text)
        else:
            line = f"  {prop_name} = {value_literal}"
            if "monitor.bluez.properties = {" in text:
                updated = text.replace(
                    "monitor.bluez.properties = {",
                    f"monitor.bluez.properties = {{\n{line}",
                    1,
                )
            else:
                updated = text + f"\nmonitor.bluez.properties = {{\n{line}\n}}\n"
            if "update-props = {" in updated:
                updated = updated.replace(
                    "update-props = {",
                    f"update-props = {{\n        {prop_name} = {value_literal}",
                    1,
                )
    else:
        updated = (
            "# WirePlumber 0.5 Bluetooth A2DP Codec Quality Tuning\n"
            f"monitor.bluez.properties = {{\n  {prop_name} = {value_literal}\n}}\n\n"
            "monitor.bluez.rules = [\n"
            "  {\n"
            "    matches = [\n"
            "      {\n"
            '        node.name = "~bluez_output.*"\n'
            "      }\n"
            "    ]\n"
            "    actions = {\n"
            "      update-props = {\n"
            f"        {prop_name} = {value_literal}\n"
            "      }\n"
            "    }\n"
            "  }\n"
            "]\n"
        )

    _atomic_write_text(CONF_PATH, updated, mode=0o644)


def set_quality(target: str) -> dict:
    raw = target.strip().lower()
    mode = ALIASES.get(raw, raw)
    if mode in VALID_MODES:
        _upsert_wireplumber_prop("bluez5.a2dp.ldac.quality", re.compile(r'(bluez5\.a2dp\.ldac\.quality\s*=\s*)"[^"]+"'), f'"{mode}"')
    elif mode in AAC_MODES:
        _upsert_wireplumber_prop("bluez5.a2dp.aac.bitratemode", AAC_MODE_RE, mode)
    else:
        return build_status(ok=False, error=f"Unsupported quality mode: {target}")

    res = subprocess.run(
        ["systemctl", "--user", "restart", "wireplumber"],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if res.returncode != 0:
        err = res.stderr.strip() or "Failed to restart wireplumber"
        return build_status(ok=False, error=err)

    return build_status(ok=True)


def set_adapter(target_hci: str) -> dict:
    """Switch active Bluetooth audio device to target_hci adapter."""
    target_name = target_hci.strip().lower()
    if not re.match(r"^hci\d+$", target_name):
        return build_status(ok=False, error=f"Invalid adapter: {target_hci}")

    device, _, active_hci, card, _ = get_bt_device_info()
    adapters = get_bt_adapters(active_hci=active_hci, active_card=card)
    target = next((a for a in adapters if a["hci"] == target_name), None)
    if not target:
        return build_status(ok=False, error=f"Adapter {target_name} not found")
    if target["active"]:
        return build_status(ok=True)

    last_dev = load_last_bt_device()
    dev_mac = card_to_mac(card) or last_dev.get("mac", "")
    dev_label = device or last_dev.get("name", "")
    if not dev_mac:
        dev_mac, paired_name = first_paired_device_on_adapter(target["address"])
        dev_label = dev_label or paired_name
    if not dev_mac:
        return build_status(ok=False, error="No Bluetooth audio device found")
    if not target.get("paired"):
        label = dev_label or dev_mac
        return build_status(ok=False, error=f"{label} is not paired on {target_name}")

    current = next((a for a in adapters if a["hci"] == active_hci), None)
    try:
        if current and active_hci:
            subprocess.run(
                ["bluetoothctl"],
                input=f"select {current['address']}\ndisconnect {dev_mac}\nquit\n",
                capture_output=True,
                text=True,
                timeout=8,
                check=False,
            )
            for _ in range(6):
                time.sleep(0.25)
                if not get_bt_device_info()[2]:
                    break
        subprocess.run(
            ["bluetoothctl"],
            input=f"select {target['address']}\npower on\nconnect {dev_mac}\nquit\n",
            capture_output=True,
            text=True,
            timeout=12,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return build_status(ok=False, error=f"Adapter switch failed: {exc}")

    for _ in range(10):
        _, new_profile, new_hci, new_card, _ = get_bt_device_info()
        if new_hci == target_name:
            if new_card and (not new_profile or new_profile == "off"):
                subprocess.run(
                    ["pactl", "set-card-profile", new_card, "a2dp-sink"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                    check=False,
                )
            return build_status(ok=True)
        time.sleep(0.3)

    return build_status(ok=False, error=f"Failed to connect {device or dev_mac} on {target_name}")


def set_adapter_power(target_hci: str, state: str) -> dict:
    """Power Bluetooth adapter target_hci on or off via BlueZ D-Bus."""
    target_name = target_hci.strip().lower()
    if not re.match(r"^hci\d+$", target_name):
        return build_status(ok=False, error=f"Invalid adapter: {target_hci}")

    norm = state.strip().lower()
    if norm in ("on", "true", "1"):
        val = "true"
    elif norm in ("off", "false", "0"):
        val = "false"
    else:
        return build_status(ok=False, error=f"Invalid power state: {state}")

    try:
        res = subprocess.run(
            [
                "busctl",
                "set-property",
                "org.bluez",
                f"/org/bluez/{target_name}",
                "org.bluez.Adapter1",
                "Powered",
                "b",
                val,
            ],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if res.returncode != 0:
            err = res.stderr.strip() or f"Failed to set {target_name} power {norm}"
            return build_status(ok=False, error=err)
    except (OSError, subprocess.SubprocessError) as exc:
        return build_status(ok=False, error=f"Adapter power failed: {exc}")

    time.sleep(0.25)
    return build_status(ok=True)


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] == "get":
        print(json.dumps(build_status()))
        return 0
    if args[0] == "set" and len(args) >= 2:
        status = set_quality(args[1])
        print(json.dumps(status))
        return 0 if status["ok"] else 1
    if args[0] == "codec-set" and len(args) >= 2:
        status = set_codec(args[1])
        print(json.dumps(status))
        return 0 if status["ok"] else 1
    if args[0] == "rate-set" and len(args) >= 2:
        status = set_sample_rate(args[1])
        print(json.dumps(status))
        return 0 if status["ok"] else 1
    if args[0] == "adapter-set" and len(args) >= 2:
        status = set_adapter(args[1])
        print(json.dumps(status))
        return 0 if status["ok"] else 1
    if args[0] == "adapter-power" and len(args) >= 3:
        status = set_adapter_power(args[1], args[2])
        print(json.dumps(status))
        return 0 if status["ok"] else 1
    if args[0] == "eq-toggle":
        state = load_eq_state()
        state["enabled"] = not state["enabled"]
        save_eq_state(state)
        ok, err = apply_eq_live(state)
        print(json.dumps(build_status(ok=ok, error=err)))
        return 0 if ok else 1
    if args[0] == "eq-preset" and len(args) >= 2:
        name = args[1]
        state = load_eq_state()
        base = state.get("autoeqBaseBands", [0.0] * 10)
        if name == "Custom":
            overlay = list(state.get("customBands", [0.0] * 10))
            state["enabled"] = True
            state["preset"] = "Custom"
            state["bands"] = _combine_with_autoeq(overlay, base) if state.get("autoeqActive") else overlay
        elif name == "AutoEq":
            state["enabled"] = True
            state["preset"] = "AutoEq"
            state["autoeqActive"] = bool(state.get("autoeqFilters"))
            state["bands"] = list(state.get("autoeqBands", [0.0] * 10))
        elif name in EQ_PRESETS:
            overlay = list(EQ_PRESETS[name])
            state["enabled"] = True
            state["preset"] = name
            state["bands"] = _combine_with_autoeq(overlay, base) if state.get("autoeqActive") else overlay
        else:
            print(json.dumps(build_status(ok=False, error=f"Unknown preset: {name}")))
            return 1
        save_eq_state(state)
        ok, err = apply_eq_live(state)
        print(json.dumps(build_status(ok=ok, error=err)))
        return 0 if ok else 1
    if args[0] == "autoeq-toggle":
        state = load_eq_state()
        base = state.get("autoeqBaseBands", [0.0] * 10)
        if state.get("autoeqActive"):
            overlay = _extract_overlay(state.get("bands", [0.0] * 10), base)
            state["autoeqActive"] = False
            state["bands"] = overlay
            if state.get("preset") == "AutoEq":
                state["preset"] = "Flat" if all(abs(x) < 0.05 for x in overlay) else "Custom"
        else:
            if not state.get("autoeqFilters"):
                print(json.dumps(build_status(ok=False, error="No AutoEq profile selected")))
                return 1
            overlay = _active_graphic_overlay(state)
            state["enabled"] = True
            state["autoeqActive"] = True
            state["bands"] = _combine_with_autoeq(overlay, base)
            state["autoeqBands"] = list(state["bands"])
            if not state.get("preset") or state.get("preset") == "Flat":
                state["preset"] = "Flat"
        save_eq_state(state)
        ok, err = apply_eq_live(state)
        print(json.dumps(build_status(ok=ok, error=err)))
        return 0 if ok else 1
    if args[0] == "eq-save-custom":
        state = load_eq_state()
        state["customBands"] = _active_graphic_overlay(state)
        state["preset"] = "Custom"
        save_eq_state(state)
        print(json.dumps(build_status(ok=True)))
        return 0
    if args[0] == "eq-reset-custom":
        state = load_eq_state()
        state["customBands"] = [0.0] * 10
        ok, err = True, ""
        if state.get("preset") == "Custom":
            base = state.get("autoeqBaseBands", [0.0] * 10)
            state["bands"] = list(base) if state.get("autoeqActive") else ([0.0] * 10)
            if state.get("autoeqActive"):
                state["autoeqBands"] = list(state["bands"])
            save_eq_state(state)
            ok, err = apply_eq_live(state)
        else:
            save_eq_state(state)
        print(json.dumps(build_status(ok=ok, error=err)))
        return 0 if ok else 1
    if args[0] == "autoeq-search" and len(args) >= 2:
        res = search_autoeq(" ".join(args[1:]))
        print(json.dumps(res))
        return 0 if res["ok"] else 1
    if args[0] == "autoeq-apply" and len(args) >= 2:
        label = args[2] if len(args) >= 3 else ""
        status = apply_autoeq(args[1], label)
        print(json.dumps(status))
        return 0 if status["ok"] else 1
    if args[0] == "eq-set" and len(args) >= 3:
        idx = int(args[1])
        val = float(args[2])
        if idx < 0 or idx > 9:
            print(json.dumps(build_status(ok=False, error="Band index must be 0..9")))
            return 1
        state = load_eq_state()
        state["enabled"] = True
        state["bands"][idx] = max(-15.0, min(15.0, round(val * 2.0) / 2.0))
        state["preset"] = "Custom"
        state["customBands"] = _active_graphic_overlay(state)
        if state.get("autoeqActive"):
            state["autoeqBands"] = list(state["bands"])
        save_eq_state(state)
        ok, err = apply_eq_live(state)
        print(json.dumps(build_status(ok=ok, error=err)))
        return 0 if ok else 1
    if args[0] == "eq-band" and len(args) >= 3:
        idx = int(args[1])
        delta = float(args[2])
        if idx < 0 or idx > 9:
            print(json.dumps(build_status(ok=False, error="Band index must be 0..9")))
            return 1
        state = load_eq_state()
        state["enabled"] = True
        state["bands"][idx] = max(-15.0, min(15.0, round((state["bands"][idx] + delta) * 2.0) / 2.0))
        state["preset"] = "Custom"
        state["customBands"] = _active_graphic_overlay(state)
        if state.get("autoeqActive"):
            state["autoeqBands"] = list(state["bands"])
        save_eq_state(state)
        ok, err = apply_eq_live(state)
        print(json.dumps(build_status(ok=ok, error=err)))
        return 0 if ok else 1

    print(json.dumps(build_status(ok=False, error="Usage: bt_ldac_quality.py [get|set <mode>|eq-toggle|eq-preset <name>|eq-band <0..4> <delta>]")))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
