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

## 5. Remove the topology files and the firmware

```bash
sudo rm -f /lib/firmware/intel/sof-ipc4-tplg/sof-ptl-cs42l43-l0*.tplg
sudo rm -f /lib/firmware/intel/ish/ish_ptl_53c4ffad_a5d6ef13.bin
sudo dracut -f --regenerate-all
```

## 6. Reboot

You are back to a stock Fedora system, with no sound, no screen rotation and no
working brightness keys.
