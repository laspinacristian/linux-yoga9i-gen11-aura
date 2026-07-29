# Getting the colours right

**Symptom:** everything looks oversaturated. Reds glow, skin tones are sunburnt,
photos look like someone dragged the saturation slider.

Nothing is broken and no patch is needed. It is a setting, and GNOME has no
button for it.

## Why

This panel is much wider than sRGB — its green is beyond DCI-P3:

```
Red   (0.682, 0.318)     Green (0.235, 0.724)
Blue  (0.141, 0.041)     White (0.313, 0.329)
```

Almost all content is sRGB and most applications never say so. GNOME has to
decide what those untagged pixels mean, and that decision is the monitor's
*colour mode*:

| Mode | What GNOME declares the output to be |
|---|---|
| `default` | sRGB. Content passes through untouched, so the panel shows its own far more saturated red for what should be sRGB red. This is where the oversaturation comes from. |
| `sdr-native` | The panel's real primaries, read from its EDID. sRGB content is converted into that wider gamut properly, so colours land where they should. |
| `bt2100` | HDR: BT.2020 and the PQ curve. Only offered with the HDR EDID installed. |

`default` is what you get out of the box.

## Fixing it

`gdctl` ships with mutter. Settings has no equivalent — the Displays panel only
has an HDR switch, which chooses between `default` and `bt2100` and never
offers the third one.

**Check what your monitor supports and how it is set now.** The colour mode only
shows up with `-p`:

```bash
gdctl show -p | grep color-mode
```

**Read your current mode and scale**, because you have to pass them back:

```bash
gdctl show | grep -A1 'Current mode'      # e.g. 2880x1800@120.000+vrr
gdctl show | grep Scale                   # e.g. 1.6666666269302368
```

**Then set it:**

```bash
gdctl set -P -LM eDP-1 --primary --mode 2880x1800@120.000+vrr \
          --scale 1.6666666269302368 --color-mode sdr-native
```

`--primary` is not decoration: a layout with no primary monitor is rejected
outright with *Config is missing primary logical*.

**GNOME will then ask whether to keep the change.** Click *Keep Changes*. Any
persistent configuration triggers that prompt, and if nobody answers it,
mutter puts the old one back after 20 seconds — so a command that appears to
have worked quietly undoes itself while you are not looking. `~/.config/monitors.xml`
is only written once you have confirmed, which is a good way to check that it
took.

`-P` makes it persistent, `-L` creates the logical monitor, `-M` picks the
connector. It applies immediately, no logout.

**Passing `--mode` and `--scale` is not optional.** `gdctl set` rebuilds the
whole monitor configuration, and anything you leave out is filled in from the
monitor's *preferred* values rather than your current ones. On this laptop the
preferred mode is 60 Hz, so omitting `--mode` quietly drops you from 120 Hz.
Read both out of `gdctl show` first and pass them back.

Use `-V` instead of `-P` to check a command without applying it.

## The login screen

GDM runs its own compositor and reads its own configuration. Copy yours across:

```bash
sudo install -m 644 ~/.config/monitors.xml \
     /var/lib/gdm/seat0/config/monitors.xml
sudo chown --reference=/var/lib/gdm/seat0/config \
     /var/lib/gdm/seat0/config/monitors.xml
sudo restorecon /var/lib/gdm/seat0/config/monitors.xml
```

Three things there are easy to get wrong. The path is per-seat now —
`/var/lib/gdm/seat0/config`, not the `/var/lib/gdm/.config` that older guides
mention. GDM runs as a systemd dynamic user, so its UID is not fixed and
`chown gdm:gdm` is wrong; copy the ownership from the directory instead. And on
Fedora the `restorecon` is required: without the right SELinux label GDM cannot
read the file and simply ignores it, silently.

It also carries your resolution and scale over, which is usually what you want.

## Does it survive?

Yes. Changing resolution or scale in Settings rewrites the configuration, but
mutter reuses the colour mode it last had for that monitor, so `sdr-native`
comes back through even though the Settings panel has no idea it exists.
Verified here by changing the scale and re-reading it.

If you ever do find it back on `default`, check with `gdctl show -p` and run the
`gdctl set` command again.
