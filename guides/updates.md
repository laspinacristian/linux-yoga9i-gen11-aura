# Surviving system updates

Two things here get undone by ordinary Fedora updates. `install.sh` handles both
when you run it; this is what it does and why.

## Fedora replacing your kernel

Fedora's own kernels install alongside yours and then take the boot default
(`UPDATEDEFAULT=yes`) — and once you are no longer running your build,
`installonly_limit=3` eventually deletes it.

`install.sh` sets:

```bash
sudo sed -i 's/^UPDATEDEFAULT=.*/UPDATEDEFAULT=no/' /etc/sysconfig/kernel
sudo grubby --set-default=/boot/vmlinuz-<version>.x86_64
```

Stock kernels still install and stay in the boot menu as a fallback, but never
become the default. Yours stays the running kernel, which is what
`protect_running_kernel` protects.

`UPDATEDEFAULT=no` applies to your own builds too, so after installing any
kernel by hand:

```bash
sudo grubby --info=ALL                                   # list the entries
sudo grubby --set-default=/boot/vmlinuz-<version>.x86_64
```

Picking an entry from the GRUB menu, or `sudo grub2-reboot <index>`, boots it
once only — Fedora does not set `GRUB_SAVEDEFAULT`.

## alsa-ucm replacing the speaker config

The tweeters need one line in a file owned by the `alsa-ucm` package, and Fedora
does update that package within a release. When it does, the file goes back to
its original contents and the treble disappears.

Run `install.sh` again. It puts the file back and leaves the original beside it
as `cs42l43-spk.conf.orig`.

If you only want to fix that one thing:

```bash
sudo curl -fsSL -o /usr/share/alsa/ucm2/sof-soundwire/cs42l43-spk.conf \
  https://raw.githubusercontent.com/laspinacristian/linux-yoga9i-gen11-aura/main/dist/ucm/cs42l43-spk.conf
systemctl --user restart wireplumber
```

## Everything else

The topology files and the sensor firmware live in `/lib/firmware`, which no
package overwrites. They stay put.
