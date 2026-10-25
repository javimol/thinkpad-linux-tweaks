# thinkpad-linux-tweaks

Scripts and configs I use to tune Linux on a **ThinkPad X1 Extreme Gen 2**.
Several of them work on other laptops too; each tool says what it needs.

Tested on: ThinkPad X1 Extreme Gen 2 (i7 + GTX 1650 Max-Q), Ubuntu 24.04, NVIDIA driver 595.

| Tool | What it does | Works on |
|---|---|---|
| [`gpu-toggle`](generic/gpu-toggle) | Switch between Intel-only and NVIDIA modes in one command, or automatically at boot | Any Ubuntu/Debian laptop with Intel + NVIDIA (Optimus) graphics |
| [`fingerprint-lid`](generic/fingerprint-lid.pam-config) | Skip the fingerprint reader while the lid is closed, so typed passwords work straight away | Any Ubuntu/Debian laptop with a fingerprint reader set up through `fprintd` |

## Install

```bash
git clone https://github.com/javimol/thinkpad-linux-tweaks.git
cd thinkpad-linux-tweaks
sudo ./install.sh gpu-toggle
```

Or just copy the script you want into your `PATH`.

## gpu-toggle

### Why

The NVIDIA GPU is powerful, but it comes at a cost: when it's in use, the
laptop can quickly heat up and the battery drains noticeably faster.

Most of the time you don't need it. Without an external monitor, the Intel
integrated GPU handles everyday work (browsing, coding, video) perfectly well.
Switching the NVIDIA GPU off keeps the laptop much cooler and makes the
battery last longer.

An external monitor, however, needs the NVIDIA GPU. Switching by hand with
`prime-select` and logging out every time gets tedious, so `gpu-toggle` does
it in one command:

- On the go, no external monitor: `gpu-toggle intel`
- At the desk with an external monitor: `gpu-toggle on-demand`

### Modes

`gpu-toggle` switches between these modes with `prime-select`:

- **intel**: NVIDIA GPU fully powered off (D3cold). Cooler, with longer battery life.
  `gpu-toggle` unloads the NVIDIA driver right away, so no reboot is needed.
- **on-demand**: Intel drives the desktop, NVIDIA is available. Needed for
  external monitors wired to the NVIDIA GPU (the case on the X1 Extreme's HDMI port).

```bash
gpu-toggle              # toggle between intel and on-demand
gpu-toggle nvidia       # switch to a specific mode (intel | on-demand | nvidia)
gpu-toggle status       # print the current mode and the GPU's power state
gpu-toggle -y intel     # skip the confirmation prompt
gpu-toggle report       # print system details for a test report
```

> ⚠️ Switching restarts your display manager, which **ends your desktop session
> immediately**. Save your work first.

### Automatic mode at boot

`gpu-toggle-auto.service` picks the mode before the login screen starts:
**external monitor connected → on-demand, otherwise → intel**. It briefly
loads the NVIDIA driver to check the GPU's ports (they are all wired to the
NVIDIA GPU), then switches if needed.

```bash
sudo ./install.sh gpu-toggle-auto
sudo systemctl disable gpu-toggle-auto   # to turn it off
journalctl -u gpu-toggle-auto -b         # what it decided at boot
```

- Booting takes longer when the mode changes, because `prime-select` rebuilds
  the initramfs. When the mode stays the same, it adds about a second.
- If you chose `nvidia` mode by hand, it is left alone.
- Monitors on a Thunderbolt dock may not be detected yet that early in boot.
- Plugging or unplugging a monitor after login still needs `gpu-toggle`.

**TLP users:** by default TLP keeps all PCI devices powered while on AC, so the
NVIDIA GPU never powers off. `install.sh` adds `/etc/tlp.d/50-gpu-toggle.conf`
to exempt the GPU and its PCIe port.

**Requirements**

- `prime-select`, from the `nvidia-prime` package (Ubuntu, Debian, Pop!_OS, Mint)
- The proprietary NVIDIA driver
- systemd. The display manager (GDM, SDDM, LightDM, ...) is detected automatically.
  If it can't be detected, log out or reboot after switching.

## fingerprint-lid

### Why

With fingerprint login on, `sudo` and the lock screen's password prompt try
the fingerprint reader first and wait up to 10 seconds for a finger. With the
lid closed and an external keyboard, you can't reach the reader, so every
password takes 10 seconds longer.

`fingerprint-lid` skips the reader while the lid is closed. With the lid open,
fingerprint login works as before.

```bash
sudo ./install.sh fingerprint-lid
```

It replaces Ubuntu's stock fingerprint PAM profile (`fprintd`) with one that
checks the lid first. To go back:

```bash
sudo pam-auth-update --disable fingerprint-lid
sudo pam-auth-update --enable fprintd
```

> ⚠️ This changes how you log in. Keep a root shell open (`sudo -i`) while you
> test `sudo` in another terminal, with the lid open and closed.

## Desktop tweaks

Small one-off settings, not tied to any hardware.

**Snap windows left and right without interruption (Ubuntu).** After you snap
a window to one half with Super+Right, Ubuntu's Tiling Assistant opens a
picker to fill the other half. The picker takes the keyboard, so pressing
Super+Left straight away doesn't move the window. To turn the picker off:

```bash
gsettings set org.gnome.shell.extensions.tiling-assistant enable-tiling-popup false
```

**Make Alt+Tab go back to the last window (Ubuntu).** When you focus a
snapped window, Tiling Assistant also raises the window snapped next to it.
That puts the neighbour ahead in the Alt+Tab order, so Alt+Tab jumps to it
instead of the window you just left. To raise only the window you pick:

```bash
gsettings set org.gnome.shell.extensions.tiling-assistant enable-raise-tile-group false
```

## Contributing

Tried a tool on another machine? Please
[open a test report](https://github.com/javimol/thinkpad-linux-tweaks/issues/new?template=tested-on.yml),
whether it worked or not, so the "Works on" column can grow.
Paste the output of `gpu-toggle report` (run it in intel mode).

<details>
<summary>Example: a working setup (X1 Extreme Gen 2, intel mode)</summary>

```text
## gpu-toggle report
Laptop:  LENOVO ThinkPad X1 Extreme 2nd (20QVCTO1WW)
Distro:  Ubuntu 24.04.5 LTS
Kernel:  7.0.0-38-generic
NVIDIA driver: 595.99.02
Mode:    intel
Display manager: gdm
TLP:     1.6.1-1ubuntu1
         defaults.conf L0041: RUNTIME_PM_ON_AC="on"
         defaults.conf L0042: RUNTIME_PM_ON_BAT="auto"
         /etc/tlp.d/50-gpu-toggle.conf L0003: RUNTIME_PM_ENABLE="01:00.0 01:00.1 00:01.0"
GPUs:
  00:02.0 VGA compatible controller [0300]: Intel Corporation CoffeeLake-H GT2 [UHD Graphics 630] [8086:3e9b]
  01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU117M [GeForce GTX 1650 Mobile / Max-Q] [10de:1f91] (rev a1)
NVIDIA power (device control runtime_status power_state):
  0000:01:00.0 auto suspended D3cold
  0000:01:00.1 auto suspended D3cold
  0000:00:01.0 auto suspended D3cold
NVIDIA ports:
  (NVIDIA driver not loaded)
Ports on other GPUs:
  card1-eDP-1 connected
gpu-toggle-auto: enabled
  External monitor: no -> 'intel'
```

What to look for:
- **NVIDIA power:** every line ends in `D3cold`, meaning the GPU gets no power.
  `D0` means it is fully on.
- **TLP:** if `RUNTIME_PM_ON_AC="on"` is set, the `RUNTIME_PM_ENABLE` line from
  `50-gpu-toggle.conf` must be there too, or the GPU stays on while on AC.
- **NVIDIA ports:** in intel mode the driver is unloaded, so no ports are listed.

</details>

Especially welcome:
- Test reports from other Intel + NVIDIA laptops
- Support for non-Ubuntu distros (Fedora, Arch, ...) that don't have `prime-select`
- New tweaks for the X1 Extreme or other ThinkPads (open a PR)

## License

[MIT](LICENSE)
