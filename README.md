# BT & Audio EQ

Omarchy Quattro bar widget for controlling Bluetooth A2DP codecs, codec quality, PipeWire sample rates, live audio telemetry, and a 2-stage PipeWire Equalizer with AutoEq support.

## Features

- **A2DP Codec Switcher**: Lists available `a2dp-sink*` profiles from `pactl list cards` (`LDAC`, `AAC`, `SBC-XQ`, `SBC`, etc.) and switches profiles live.
- **Adaptive Quality Control**:
  - **LDAC**: `HQ` (990k), `SQ` (660k), `MQ` (330k), `Auto` (ABR) via `bluez5.a2dp.ldac.quality`.
  - **AAC**: `CBR` (`0`), `VBR 1`, `VBR 3`, `VBR 5` via `bluez5.a2dp.aac.bitratemode`.
  - **Fixed-bitrate profiles & System PCM**: Displays the active profile/output state.
- **Dynamic Sample Rate Selector**: Reads supported `EnumFormat` rates from `pw-dump` and switches `clock.allowed-rates` / `clock.force-rate` live via `pw-metadata`.
- **2-Stage PipeWire EQ + AutoEq**:
  - Stage 1: Parametric EQ (`PK` / `LSC` / `HSC` biquads) from the AutoEq database, automatically paused when Bluetooth disconnects and resumed on reconnect.
  - Stage 2: 10-band ISO graphic EQ (`31 Hz` – `16 kHz`, `±15 dB`) layered on top of Stage 1 with `Bass`, `V-Shape`, `Vocal`, `Warm`, `Flat`, and `Custom` presets.
- **Event-Driven Updates**: Uses `pactl subscribe` for instant connect/disconnect/profile updates with zero background Python polling when the panel is closed.

## Requirements

- Omarchy 4 (Quattro / Quickshell)
- `pipewire`, `wireplumber` (0.5+), `pipewire-pulse` (`pactl`), `pw-dump`, `pw-top`, `pw-metadata`, `pw-cli`
- `python3` (standard library only)
- `systemd --user` (for applying WirePlumber/PipeWire config changes)

## Files & Network Behavior

- **WirePlumber config**: Writes `bluez5.a2dp.ldac.quality` and `bluez5.a2dp.aac.bitratemode` to `~/.config/wireplumber/wireplumber.conf.d/50-bluez-ldac.conf` and restarts `wireplumber` on quality change.
- **PipeWire EQ config**: Writes the `Equalizer` `filter-chain` (`effect_input.bt_eq`) to `~/.config/pipewire/pipewire.conf.d/60-bt-eq.conf` and restarts `pipewire` only when the AutoEq filter slot layout changes.
- **State & Cache**: Stores EQ state and 7-day AutoEq index cache in `~/.local/state/simonez-btquality/`.
- **Network**: AutoEq search and profile download fetch over HTTPS strictly from `raw.githubusercontent.com` (`jaakkopasanen/AutoEq`) with response size limits (`2 MB` index, `128 KB` profile).

## License

MIT — see [LICENSE](LICENSE).
