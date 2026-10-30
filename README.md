# thinkpad-linux-tweaks

Scripts and configs I use to tune Linux on a **ThinkPad X1 Extreme Gen 2**.
Several of them work on other laptops too; each tool says what it needs.

Tested on: ThinkPad X1 Extreme Gen 2 (i7 + GTX 1650 Max-Q), Ubuntu 24.04, NVIDIA driver 595.

| Tool | What it does | Works on |
|---|---|---|
| [`gpu-toggle`](generic/gpu-toggle) | Switch between Intel-only and NVIDIA modes in one command, or automatically at boot | Any Ubuntu/Debian laptop with Intel + NVIDIA (Optimus) graphics |
| [`fingerprint-lid`](generic/fingerprint-lid.pam-config) | Skip the fingerprint reader while the lid is closed, so typed passwords work straight away | Any Ubuntu/Debian laptop with a fingerprint reader set up through `fprintd` |
| [`shortcut-check`](generic/shortcut-check) | Find GNOME keyboard shortcuts changed from the default, and reset them one by one | Any GNOME desktop |
| [`chrome-intel`](generic/chrome-intel) | Make Google Chrome decode video on the Intel GPU instead of the CPU | Any laptop with an Intel GPU running Google Chrome (X11 or Wayland) |

## Install

```bash
git clone https://github.com/javimol/thinkpad-linux-tweaks.git
cd thinkpad-linux-tweaks
sudo ./install.sh <tool>...   # one or more tools from the list below
./install.sh --list           # show the available tools
```

| Install command | What it installs |
|---|---|
| `sudo ./install.sh gpu-toggle` | The `gpu-toggle` command |
| `sudo ./install.sh gpu-toggle-auto` | `gpu-toggle` plus the service that picks the mode at boot |
| `sudo ./install.sh fingerprint-lid` | The PAM profile that skips the fingerprint reader with the lid closed |
| `sudo ./install.sh shortcut-check` | The `shortcut-check` command (run it without `sudo`) |
| `sudo ./install.sh chrome-intel` | The `chrome-intel` launcher (then run `chrome-intel --setup` without `sudo`) |

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

## Use it with the lid closed

Two settings for working with the lid closed on an external monitor, from
power-on to login.

**Power on without opening the lid (ThinkPad).** The BIOS setting
"Power On with AC Attach" starts the laptop when power is plugged in. You can
set it from Linux (it takes effect at the next reboot):

```bash
echo Enable | sudo tee /sys/class/firmware-attributes/thinklmi/attributes/OnByAcAttach/current_value
```

To start it: shut down, unplug all power (including a USB-C monitor that
charges the laptop), wait about 10 seconds, and plug back in. Shutting down
while plugged in leaves it off. This doesn't work if a BIOS supervisor password
is set; use the BIOS menu (F1 at boot) instead.

It fires once, when the laptop goes from no power to power. A USB-C monitor
that charges the laptop counts as power: if it's still connected, plugging in
the charger isn't a new event, and the laptop stays off. If the monitor powers
the laptop on during the night, that uses up the event too.

The BIOS setting "Wake by Thunderbolt" can also start the laptop on its own
when a monitor on the USB-C port changes state, for example coming out of
standby. If the laptop turns itself on at night, disable it:

```bash
echo Disable | sudo tee /sys/class/firmware-attributes/thinklmi/attributes/WakeByThunderbolt/current_value
```

**Don't suspend at login.** If you start the laptop with the lid closed, it
can go to sleep the moment you log in, which looks like the external monitor
going black. systemd is meant to ignore the lid while an external monitor is
connected, but it doesn't see monitors on NVIDIA ports. GNOME covers for that
once you're logged in, but not during the second or so it takes to log in. To
never suspend on lid close while on AC:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
printf '[Login]\nHandleLidSwitchExternalPower=ignore\n' | sudo tee /etc/systemd/logind.conf.d/50-lid-on-ac.conf
```

Reboot to apply it. On battery, closing the lid still suspends. On AC with no
monitor, it no longer does; suspend from the menu instead.

## Desktop tweaks

Small one-off settings that work on any laptop.

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

**Make the screenshot key work on a Logitech keyboard (GNOME).** The
screenshot key on Logitech keyboards such as the MX Keys Mini sends
Super+Shift+S, the Windows snipping-tool shortcut, not Print. GNOME doesn't
bind it, so the key does nothing. To open GNOME's screenshot tool with it,
keeping Print as well:

```bash
gsettings set org.gnome.shell.keybindings show-screenshot-ui "['Print', '<Shift><Super>s']"
```

Depending on Fn Lock, you press the key on its own or with Fn. To see what
any key sends, run `xinput test "<keyboard name>"` (names from `xinput list`)
and press it. On Wayland, use `sudo libinput debug-events` instead.

**Keep window shortcuts working while a menu is open (GNOME).** On X11, an
open menu (Chrome's ⋮ menu, a right-click menu, ...) takes the whole keyboard,
so GNOME shortcuts such as Super+Shift+Left/Right (move a window to another
monitor) or Ctrl+Alt+Left/Right (switch workspace) do nothing until you press
Esc. On Wayland, GNOME sees every key first, so they work with a menu open.
To switch, log out, click the gear icon on the login screen and pick
"Ubuntu on Wayland". The login screen remembers the choice; pick "Ubuntu" to
go back to X11. `chrome-intel` works on both.

**Find shortcuts that changed by accident (GNOME).** If you record a shortcut
in Settings while Fn Lock is off, the F-keys send their media functions, so
Alt+F4 gets saved as `<Alt>AudioMicMute` and stops working. `shortcut-check`
lists every shortcut that differs from the default, flags the ones saved with
a media key, and asks whether to reset each one:

```bash
shortcut-check          # ask about each changed shortcut: reset or keep
shortcut-check --list   # just print the changed shortcuts
shortcut-check --all    # print every shortcut, marking the changed ones
```

**Decode video in Chrome on the Intel GPU (X11 or Wayland).** Chrome plays
video on the CPU on this laptop, even though the Intel GPU can decode it.
Chrome only uses hardware decode when its Vulkan device and its video device
are both the Intel GPU. With the NVIDIA driver loaded (on-demand mode) it picks NVIDIA for both,
and Chrome doesn't decode on NVIDIA by default. `chrome-intel` starts Chrome
with both pinned to Intel. That works the same in intel and on-demand mode,
and leaves the NVIDIA GPU free to power off:

```bash
chrome-intel --setup   # make the Chrome menu entry and web apps use it
chrome-intel --undo    # back to the stock launchers
```

Then quit Chrome completely (Ctrl+Shift+Q) and start it from the menu. To
check, play a video, open `chrome://media-internals`, select the player and
look for `kVideoDecoderName: VaapiVideoDecoder`. `FFmpegVideoDecoder` or
`VpxVideoDecoder` means it is still decoding on the CPU. Chrome rewrites a web
app's shortcut when you reinstall the app, so run `--setup` again after that.

`Dav1dVideoDecoder` means the video is AV1. The UHD 630 can't decode AV1 in
hardware, and YouTube often sends it. To get VP9 instead, which the GPU does
decode, install the
[enhanced-h264ify](https://chromewebstore.google.com/detail/enhanced-h264ify/omkfmpieigblcllmkgbflkikinpkodlk)
extension and, in its options, block only AV1. Its defaults block everything
but H.264, which caps YouTube at 1080p. Right-click a YouTube video, then
"Stats for nerds": the Codecs line should show `vp09`, not `av01`.

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
