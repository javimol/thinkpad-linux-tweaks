# thinkpad-linux-tweaks

Scripts and configs I use to tune Linux on a **ThinkPad X1 Extreme Gen 2**.
Several of them work on other laptops too; each tool says what it needs.

Tested on: ThinkPad X1 Extreme Gen 2 (i7 + GTX 1650 Max-Q), Ubuntu 24.04, NVIDIA driver 595.

| Tool | What it does | Works on |
|---|---|---|
| [`gpu-toggle`](generic/gpu-toggle) | Switch between Intel-only and NVIDIA modes in one command | Any Ubuntu/Debian laptop with Intel + NVIDIA (Optimus) graphics |

## Install

```bash
git clone https://github.com/javimol/thinkpad-linux-tweaks.git
cd thinkpad-linux-tweaks
sudo ./install.sh gpu-toggle
```

Or just copy the script you want into your `PATH`.

## gpu-toggle

Hybrid-graphics laptops run hotter and louder with the NVIDIA GPU active.
`gpu-toggle` flips between two modes with `prime-select`:

- **intel**: NVIDIA GPU off. Cooler, quieter, better battery.
- **on-demand**: Intel drives the desktop, NVIDIA is available. Needed for
  external monitors wired to the NVIDIA GPU (the case on the X1 Extreme's HDMI port).

```bash
gpu-toggle              # toggle between intel and on-demand
gpu-toggle nvidia       # switch to a specific mode (intel | on-demand | nvidia)
gpu-toggle status       # print the current mode
gpu-toggle -y intel     # skip the confirmation prompt
```

> ⚠️ Switching restarts your display manager, which **ends your desktop session
> immediately**. Save your work first.

**Requirements**

- `prime-select`, from the `nvidia-prime` package (Ubuntu, Debian, Pop!_OS, Mint)
- The proprietary NVIDIA driver
- systemd. The display manager (GDM, SDDM, LightDM, ...) is detected automatically.
  If it can't be detected, log out or reboot after switching.

## Contributing

Tried a tool on another machine? Please open an issue or PR saying what
worked, so the "Works on" column can grow.

## License

[MIT](LICENSE)
