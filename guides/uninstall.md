# Undoing the install

Everything `install.sh` does, in reverse. Nothing here is destructive to the
rest of the system.

## 1. Let Fedora choose the kernel again

```bash
sudo sed -i 's/^UPDATEDEFAULT=.*/UPDATEDEFAULT=yes/' /etc/sysconfig/kernel
sudo grubby --info=ALL | grep -E '^(index|kernel)'
sudo grubby --set-default=/boot/vmlinuz-<a stock Fedora version>.x86_64
```

Pick a kernel whose version does not contain `yoga9i_gen11_aura`. If there isn't
one, install a stock kernel first:

```bash
sudo dnf install --refresh kernel
```

## 2. Reboot into that kernel

You cannot remove the kernel you are running. Reboot first, then continue.

## 3. Remove the patched kernel

```bash
sudo dnf remove kernel-core-$(uname -r | sed 's/\.x86_64$//' | grep yoga9i || echo NONE)
```

Or list what is installed and remove the ones you recognise:

```bash
rpm -q kernel-core
sudo dnf remove kernel-core-7.1.5-201.yoga9i_gen11_aura.fc44
```

Removing `kernel-core` takes the other four subpackages with it.

## 4. Put the ALSA config back

```bash
sudo mv /usr/share/alsa/ucm2/sof-soundwire/cs42l43-spk.conf.orig \
        /usr/share/alsa/ucm2/sof-soundwire/cs42l43-spk.conf
systemctl --user restart wireplumber
```

If that file isn't there, reinstall the package instead:

```bash
sudo dnf reinstall alsa-ucm
```

## 5. Put the colour mode back

Only if you want the stock behaviour back — this is a display setting, not
something that affects the rest of the system.

```bash
gdctl show                                   # read your current mode and scale
gdctl set -P -LM eDP-1 --primary --mode 2880x1800@120.000+vrr \
          --scale 1.6666666269302368 --color-mode default
```

Pass your own mode and scale, not these. Anything you leave out is filled in
from the monitor's *preferred* values rather than your current ones, and this
panel prefers 60 Hz.

Expect the screen to look oversaturated afterwards: `default` tells GNOME to
treat this wide-gamut panel as sRGB. That is the stock behaviour, not a fault.

Then the login screen, if the installer configured it:

```bash
sudo rm -f /var/lib/gdm/seat0/config/monitors.xml
```

That file also carried your resolution and scale over to GDM, so removing it
returns the login screen to whatever GNOME picks on its own.

## 6. Undo the HDR EDID override

Skip this if you never passed `--hdr-edid`.

Three things to remove: the kernel argument that selects the override, the
dracut rule that puts the file in the initramfs, and the file itself.

```bash
sudo grubby --update-kernel=ALL --remove-args="drm.edid_firmware"
sudo rm -f /etc/dracut.conf.d/edid-override.conf
sudo rm -f /lib/firmware/edid/yoga-9i-hdr.bin
```

Check that nothing is left behind, since a stale argument on one boot entry is
easy to miss:

```bash
sudo grubby --info=ALL | grep -c edid_firmware      # expect 0
```

Without the override the panel no longer advertises HDR, so the HDR switch in
Settings disappears. If your display was in HDR it drops back to `default`,
which treats this wide-gamut panel as sRGB and looks oversaturated. Setting it
to `sdr-native` gets accurate colours back — see
[color.md](color.md), or step 5 above if you are undoing everything anyway.

## 7. Remove the topology files and the firmware

```bash
sudo rm -f /lib/firmware/intel/sof-ipc4-tplg/sof-ptl-cs42l43-l0*.tplg
sudo rm -f /lib/firmware/intel/ish/ish_ptl_53c4ffad_a5d6ef13.bin
sudo dracut -f --regenerate-all
```

## 8. Reboot

You are back to a stock Fedora system, with no sound, no screen rotation and no
working brightness keys.
