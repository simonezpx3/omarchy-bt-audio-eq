"""PipeWire 2-stage Equalizer and AutoEq profile manager."""

import json
import os
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONF_PATH = Path.home() / ".config/wireplumber/wireplumber.conf.d/50-bluez-ldac.conf"
PIPEWIRE_EQ_CONF = Path.home() / ".config/pipewire/pipewire.conf.d/60-bt-eq.conf"
EQ_STATE_PATH = Path.home() / ".local/state/simonez-btquality/eq_state.json"
AUTOEQ_INDEX_CACHE = Path.home() / ".local/state/simonez-btquality/autoeq_index.json"
AUTOEQ_INDEX_URL = "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/INDEX.md"
AUTOEQ_RESULTS_BASE = "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/"
AUTOEQ_LINE_RE = re.compile(r"^- \[([^\]]+)\]\(\./([^)]+)\)\s+by\s+(.+)$")
AUTOEQ_FILTER_RE = re.compile(r"Filter\s+\d+:\s+ON\s+\w+\s+Fc\s+(\d+)\s+Hz\s+Gain\s+([+-]?\d+(?:\.\d+)?)\s+dB")
AUTOEQ_PARAM_RE = re.compile(r"Filter\s+\d+:\s+ON\s+(PK|LSC|HSC)\s+Fc\s+(\d+(?:\.\d+)?)\s+Hz\s+Gain\s+([+-]?\d+(?:\.\d+)?)\s+dB\s+Q\s+(\d+(?:\.\d+)?)")
ISO_FREQS = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
FILTER_TYPE_MAP = {
    "PK": "bq_peaking",
    "LSC": "bq_lowshelf",
    "HSC": "bq_highshelf",
}

VALID_MODES = {
    "hq": "HQ",
    "sq": "SQ",
    "mq": "MQ",
    "auto": "AUTO",
}
ALIASES = {
    "adaptive": "auto",
}
LDAC_QUALITY_OPTIONS = [
    {"key": "hq", "title": "HQ", "sub": "990k", "shortcut": "1"},
    {"key": "sq", "title": "SQ", "sub": "660k", "shortcut": "2"},
    {"key": "mq", "title": "MQ", "sub": "330k", "shortcut": "3"},
    {"key": "auto", "title": "Auto", "sub": "Adap", "shortcut": "4"},
]
AAC_MODES = {
    "0": {"title": "CBR", "sub": "Fixed"},
    "1": {"title": "VBR 1", "sub": "Low"},
    "2": {"title": "VBR 2", "sub": "Low+"},
    "3": {"title": "VBR 3", "sub": "Med"},
    "4": {"title": "VBR 4", "sub": "High"},
    "5": {"title": "VBR 5", "sub": "Max"},
}
AAC_QUALITY_OPTIONS = [
    {"key": "0", "title": "CBR", "sub": "Fixed", "shortcut": "1"},
    {"key": "1", "title": "VBR 1", "sub": "Low", "shortcut": "2"},
    {"key": "3", "title": "VBR 3", "sub": "Med", "shortcut": "3"},
    {"key": "5", "title": "VBR 5", "sub": "Max", "shortcut": "4"},
]
EQ_PRESETS = {
    "Flat": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "Bass": [5.0, 4.5, 3.0, 1.5, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0],
    "V-Shape": [4.5, 3.5, 1.5, -1.0, -2.0, -2.0, 0.5, 2.5, 4.0, 4.5],
    "Vocal": [-2.5, -2.0, -1.0, 0.0, 1.5, 3.0, 3.5, 2.5, 1.0, 0.0],
    "Warm": [2.5, 2.0, 1.5, 1.0, 0.5, 0.0, -0.5, -1.5, -2.0, -1.0],
    "Clarity": [-1.0, -0.5, 0.0, 0.0, 0.5, 1.5, 2.5, 3.5, 4.0, 3.5],
}
QUALITY_RE = re.compile(r'(bluez5\.a2dp\.ldac\.quality\s*=\s*")([^"]+)(")')
AAC_MODE_RE = re.compile(r'(bluez5\.a2dp\.aac\.bitratemode\s*=\s*)(\d+)')



def load_eq_state() -> dict:
    default = {
        "enabled": False,
        "preset": "Flat",
        "autoeq": "",
        "autoeqActive": False,
        "autoeqAutoPaused": False,
        "bands": [0.0] * 10,
        "customBands": [0.0] * 10,
        "autoeqBands": [0.0] * 10,
        "autoeqBaseBands": [0.0] * 10,
        "autoeqFilters": [],
    }
    if not EQ_STATE_PATH.exists():
        return default
    try:
        data = json.loads(EQ_STATE_PATH.read_text(encoding="utf-8"))
        bands = [max(-15.0, min(15.0, float(x))) for x in data.get("bands", [0.0] * 10)[:10]]
        custom = [max(-15.0, min(15.0, float(x))) for x in data.get("customBands", [0.0] * 10)[:10]]
        autoeq_b = [max(-15.0, min(15.0, float(x))) for x in data.get("autoeqBands", [0.0] * 10)[:10]]
        autoeq_base = [max(-15.0, min(15.0, float(x))) for x in data.get("autoeqBaseBands", [0.0] * 10)[:10]]
        for lst in (bands, custom, autoeq_b, autoeq_base):
            while len(lst) < 10:
                lst.append(0.0)
        return {
            "enabled": bool(data.get("enabled", False)),
            "preset": str(data.get("preset", "Custom")),
            "autoeq": str(data.get("autoeq", "")),
            "autoeqActive": bool(data.get("autoeqActive", data.get("preset") == "AutoEq")),
            "autoeqAutoPaused": bool(data.get("autoeqAutoPaused", False)),
            "bands": bands,
            "customBands": custom,
            "autoeqBands": autoeq_b,
            "autoeqBaseBands": autoeq_base,
            "autoeqFilters": list(data.get("autoeqFilters", [])),
        }
    except (OSError, json.JSONDecodeError, ValueError, TypeError):
        return default


MAX_INDEX_BYTES = 2 * 1024 * 1024
MAX_PROFILE_BYTES = 128 * 1024
ALLOWED_AUTOEQ_HOST = "raw.githubusercontent.com"


def _atomic_write_text(path: Path, content: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def _fetch_bounded_text(url: str, max_bytes: int) -> str:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.netloc != ALLOWED_AUTOEQ_HOST:
        raise ValueError("Disallowed AutoEq URL")
    req = urllib.request.Request(url, headers={"User-Agent": "simonez-btquality/1.0"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        final_parsed = urllib.parse.urlparse(resp.geturl())
        if final_parsed.scheme != "https" or final_parsed.netloc != ALLOWED_AUTOEQ_HOST:
            raise ValueError("Disallowed AutoEq redirect")
        raw = resp.read(max_bytes + 1)
    if len(raw) > max_bytes:
        raise ValueError("AutoEq response exceeded byte limit")
    return raw.decode("utf-8", errors="replace")


def ensure_autoeq_index() -> list[dict]:
    if AUTOEQ_INDEX_CACHE.exists():
        age = time.time() - AUTOEQ_INDEX_CACHE.stat().st_mtime
        if age < 7 * 86400:
            try:
                return json.loads(AUTOEQ_INDEX_CACHE.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError, ValueError):
                AUTOEQ_INDEX_CACHE.unlink(missing_ok=True)

    text = _fetch_bounded_text(AUTOEQ_INDEX_URL, MAX_INDEX_BYTES)

    entries = []
    for line in text.splitlines():
        m = AUTOEQ_LINE_RE.match(line.strip())
        if not m:
            continue
        entries.append({
            "name": m.group(1).strip(),
            "path": m.group(2).strip(),
            "source": m.group(3).strip(),
        })

    _atomic_write_text(AUTOEQ_INDEX_CACHE, json.dumps(entries))
    return entries


def search_autoeq(query: str, limit: int = 12) -> dict:
    tokens = [t.lower() for t in query.strip().split() if t]
    if not tokens:
        return {"ok": True, "results": []}
    try:
        entries = ensure_autoeq_index()
    except (OSError, urllib.error.URLError, ValueError) as exc:
        return {"ok": False, "results": [], "error": f"AutoEq index fetch failed: {exc}"}

    matches = []
    for e in entries:
        hay = f"{e['name']} {e['source']}".lower()
        if all(t in hay for t in tokens):
            matches.append(e)
            if len(matches) >= limit:
                break
    return {"ok": True, "results": matches, "error": ""}


def write_pipewire_eq_conf(aeq_filters: list[dict]) -> None:
    padded = list(aeq_filters)
    while len(padded) < 12:
        padded.append({"type": "PK", "freq": 1000.0, "q": 1.0, "gain": 0.0})
    nodes_lines = []
    node_names = []
    for idx, f in enumerate(padded, start=1):
        name = f"aeq_{idx}"
        node_names.append(name)
        label = FILTER_TYPE_MAP.get(f.get("type", "PK"), "bq_peaking")
        freq = float(f.get("freq", 1000.0))
        q_val = float(f.get("q", 1.0))
        gain = float(f.get("gain", 0.0))
        nodes_lines.append(
            f'                    {{ type = builtin name = {name} label = {label} control = {{ "Freq" = {freq} "Q" = {q_val} "Gain" = {gain} }} }}'
        )

    iso_defs = [
        (1, "bq_lowshelf", 31.0, 0.707),
        (2, "bq_peaking", 62.0, 1.4),
        (3, "bq_peaking", 125.0, 1.4),
        (4, "bq_peaking", 250.0, 1.4),
        (5, "bq_peaking", 500.0, 1.4),
        (6, "bq_peaking", 1000.0, 1.4),
        (7, "bq_peaking", 2000.0, 1.4),
        (8, "bq_peaking", 4000.0, 1.4),
        (9, "bq_peaking", 8000.0, 1.4),
        (10, "bq_highshelf", 16000.0, 0.707),
    ]
    for idx, label, freq, q_val in iso_defs:
        name = f"eq_band_{idx}"
        node_names.append(name)
        nodes_lines.append(
            f'                    {{ type = builtin name = {name} label = {label} control = {{ "Freq" = {freq} "Q" = {q_val} "Gain" = 0.0 }} }}'
        )

    links_lines = [
        f'                    {{ output = "{node_names[i]}:Out" input = "{node_names[i + 1]}:In" }}'
        for i in range(len(node_names) - 1)
    ]

    conf_text = (
        "context.modules = [\n"
        "    { name = libpipewire-module-filter-chain\n"
        "        args = {\n"
        '            node.description = "Equalizer"\n'
        '            media.name       = "Equalizer"\n'
        "            filter.graph = {\n"
        "                nodes = [\n"
        + "\n".join(nodes_lines) + "\n"
        "                ]\n"
        "                links = [\n"
        + "\n".join(links_lines) + "\n"
        "                ]\n"
        "            }\n"
        "            audio.channels = 2\n"
        "            audio.position = [ FL FR ]\n"
        "            capture.props = {\n"
        '                node.name   = "effect_input.bt_eq"\n'
        '                media.class = Audio/Sink\n'
        "            }\n"
        "            playback.props = {\n"
        '                node.name    = "effect_output.bt_eq"\n'
        "                node.passive = true\n"
        "            }\n"
        "        }\n"
        "    }\n"
        "]\n"
    )
    _atomic_write_text(PIPEWIRE_EQ_CONF, conf_text, mode=0o644)


def apply_autoeq(rel_path: str, label: str = "", build_status_fn=None) -> dict:
    raw_path = rel_path.strip()
    if not raw_path or ".." in raw_path or "\\" in raw_path or "://" in raw_path or raw_path.startswith("/"):
        return (build_status_fn or (lambda **kw: kw))(ok=False, error="Invalid AutoEq path")
    clean_path = raw_path.lstrip("./")
    if not clean_path:
        return (build_status_fn or (lambda **kw: kw))(ok=False, error="Invalid AutoEq path")

    model_enc = clean_path.split("/")[-1]
    param_url = f"{AUTOEQ_RESULTS_BASE}{clean_path}/{model_enc}%20ParametricEQ.txt"
    fixed_url = f"{AUTOEQ_RESULTS_BASE}{clean_path}/{model_enc}%20FixedBandEQ.txt"

    filters: list[dict] = []
    bands = [0.0] * 10
    try:
        text = _fetch_bounded_text(param_url, MAX_PROFILE_BYTES)
        for m in AUTOEQ_PARAM_RE.finditer(text):
            filters.append({
                "type": m.group(1),
                "freq": float(m.group(2)),
                "gain": round(max(-15.0, min(15.0, float(m.group(3)))), 2),
                "q": float(m.group(4)),
            })
    except (OSError, urllib.error.URLError, ValueError):
        filters = []

    fixed_bands = [0.0] * 10
    try:
        text = _fetch_bounded_text(fixed_url, MAX_PROFILE_BYTES)
        freq_map: dict[int, float] = {}
        for m in AUTOEQ_FILTER_RE.finditer(text):
            freq_map[int(m.group(1))] = round(max(-15.0, min(15.0, float(m.group(2)))), 1)
        if len(freq_map) >= 5:
            fixed_bands = [freq_map.get(f, 0.0) for f in ISO_FREQS]
    except (OSError, urllib.error.URLError, ValueError):
        fixed_bands = [0.0] * 10

    if not filters and all(v == 0.0 for v in fixed_bands):
        return (build_status_fn or (lambda **kw: kw))(ok=False, error="AutoEq profile did not contain expected filters")

    bands = list(fixed_bands)
    base_bands = list(fixed_bands) if filters else [0.0] * 10

    state = load_eq_state()
    state["enabled"] = True
    state["preset"] = "Flat"
    state["autoeq"] = label.strip() or urllib.parse.unquote(model_enc)
    state["autoeqActive"] = bool(filters)
    state["autoeqFilters"] = filters
    state["bands"] = bands
    state["autoeqBands"] = list(bands)
    state["autoeqBaseBands"] = base_bands
    save_eq_state(state)

    if filters:
        # Check if current 60-bt-eq.conf already has the exact same filter types in aeq_1..N
        existing_types: list[str] = []
        if PIPEWIRE_EQ_CONF.exists():
            conf_txt = PIPEWIRE_EQ_CONF.read_text(encoding="utf-8")
            existing_types = re.findall(r"name = aeq_\d+ label = (bq_\w+)", conf_txt)
        target_types = [FILTER_TYPE_MAP.get(f.get("type", "PK"), "bq_peaking") for f in filters]

        if existing_types[:len(target_types)] != target_types:
            write_pipewire_eq_conf(filters)
            subprocess.run(
                ["systemctl", "--user", "restart", "pipewire"],
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            # Wait for both effect_input.bt_eq and bluez_output to come back
            for _ in range(16):
                time.sleep(0.5)
                if find_eq_node_id() and find_bt_sink_name():
                    break

    ok, err = apply_eq_live(state)
    return (build_status_fn or (lambda **kw: kw))(ok=ok, error=err)


def save_eq_state(state: dict) -> None:
    _atomic_write_text(EQ_STATE_PATH, json.dumps(state))


def _load_pw_dump() -> list[dict]:
    try:
        res = subprocess.run(
            ["pw-dump"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if res.returncode == 0:
            data = json.loads(res.stdout)
            if isinstance(data, list):
                return data
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError, ValueError):
        return []
    return []


def find_eq_node_id(pw_nodes: list[dict] | None = None) -> str:
    nodes = pw_nodes if pw_nodes is not None else _load_pw_dump()
    for obj in nodes:
        if obj.get("type") != "PipeWire:Interface:Node":
            continue
        props = (obj.get("info") or {}).get("props") or {}
        if props.get("node.name") == "effect_input.bt_eq":
            return str(obj.get("id", ""))
    return ""


def find_bt_sink_name() -> str:
    try:
        res = subprocess.run(
            ["pactl", "list", "short", "sinks"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        for line in res.stdout.splitlines():
            parts = line.split("\t")
            if len(parts) >= 2 and "bluez_output." in parts[1]:
                return parts[1]
    except (OSError, subprocess.SubprocessError, ValueError):
        return ""
    return ""


def _combine_with_autoeq(overlay: list[float], base: list[float]) -> list[float]:
    return [max(-15.0, min(15.0, round((base[i] + overlay[i]) * 2.0) / 2.0)) for i in range(10)]


def _extract_overlay(bands: list[float], base: list[float]) -> list[float]:
    return [max(-15.0, min(15.0, round((bands[i] - base[i]) * 2.0) / 2.0)) for i in range(10)]


def _active_graphic_overlay(state: dict) -> list[float]:
    if not state.get("enabled"):
        return [0.0] * 10
    if state.get("autoeqActive"):
        return _extract_overlay(state.get("bands", [0.0] * 10), state.get("autoeqBaseBands", [0.0] * 10))
    return list(state.get("bands", [0.0] * 10))


def apply_eq_live(state: dict, pw_nodes: list[dict] | None = None) -> tuple[bool, str]:
    node_id = find_eq_node_id(pw_nodes=pw_nodes)
    if not node_id:
        return False, "BT EQ node not found in PipeWire"

    aeq_filters = state.get("autoeqFilters", [])
    aeq_on = bool(state.get("enabled") and state.get("autoeqActive"))
    base_bands = state.get("autoeqBaseBands", [0.0] * 10) if aeq_on else ([0.0] * 10)
    gains = [round(state["bands"][i] - base_bands[i], 2) for i in range(10)] if state["enabled"] else ([0.0] * 10)
    pairs = [f'"eq_band_{i + 1}:Gain" {gains[i]}' for i in range(10)]

    conf_slots = len(aeq_filters)
    if PIPEWIRE_EQ_CONF.exists():
        try:
            conf_slots = max(conf_slots, len(re.findall(r"name = aeq_\d+", PIPEWIRE_EQ_CONF.read_text(encoding="utf-8"))))
        except OSError:
            conf_slots = max(conf_slots, 0)
    for idx in range(1, conf_slots + 1):
        if idx <= len(aeq_filters):
            f = aeq_filters[idx - 1]
            g = float(f.get("gain", 0.0)) if aeq_on else 0.0
            freq = float(f.get("freq", 1000.0))
            q_val = float(f.get("q", 1.0))
            pairs.append(f'"aeq_{idx}:Freq" {freq} "aeq_{idx}:Q" {q_val} "aeq_{idx}:Gain" {g}')
        else:
            pairs.append(f'"aeq_{idx}:Gain" 0.0')
    param_str = f"{{ params = [ {' '.join(pairs)} ] }}"
    res = subprocess.run(
        ["pw-cli", "set-param", node_id, "Props", param_str],
        capture_output=True,
        text=True,
        timeout=3,
        check=False,
    )
    if res.returncode != 0:
        return False, res.stderr.strip() or "pw-cli set-param failed"

    if state["enabled"]:
        subprocess.run(
            ["pactl", "set-default-sink", "effect_input.bt_eq"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
    else:
        target_sink = find_bt_sink_name()
        if not target_sink:
            try:
                s_res = subprocess.run(
                    ["pactl", "list", "short", "sinks"],
                    capture_output=True,
                    text=True,
                    timeout=3,
                    check=False,
                )
                for line in s_res.stdout.splitlines():
                    parts = line.split("\t")
                    if len(parts) >= 2 and parts[1] != "effect_input.bt_eq" and "bluez_output." not in parts[1]:
                        target_sink = parts[1]
                        break
            except (OSError, subprocess.SubprocessError, ValueError):
                target_sink = ""
        if target_sink:
            subprocess.run(
                ["pactl", "set-default-sink", target_sink],
                capture_output=True,
                text=True,
                timeout=3,
                check=False,
            )
    return True, ""


