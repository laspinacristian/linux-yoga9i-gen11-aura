# Other distributions

`install.sh` and the prebuilt RPMs are Fedora 44 only. The fixes themselves are
not — they are patches to the Linux kernel, to SOF and to alsa-ucm-conf, and
work anywhere those do. There is just no packaging to hand you.

Four things to do, in any order except that the kernel comes first.

## 1. Kernel

Apply these four patches to your distribution's kernel source and build it the
way your distribution documents:

```
patches/display/0001-drm-edid-*.patch
patches/display/0002-drm-i915-*.patch
patches/audio/0001-ASoC-*.patch
patches/sensors/0001-platform-x86-lenovo-ymc-*.patch
```

They apply cleanly to 6.17 and later. If one is rejected it has probably been
merged upstream already — check before forcing it.

Secure Boot has to be off unless you sign the result yourself.

## 2. Audio topology

Copy the prebuilt files:

```bash
sudo cp dist/tplg/*.tplg /lib/firmware/intel/sof-ipc4-tplg/
```

These are plain data files, not compiled code, so they are not tied to a
distribution. [topology.md](topology.md) if you would rather build them.

## 3. ALSA speaker config

`dist/ucm/cs42l43-spk.conf` replaces the file of the same name in your
alsa-ucm-conf installation. Find it first — the path differs between
distributions:

```bash
find / -name cs42l43-spk.conf -path '*sof-soundwire*' 2>/dev/null
```

Keep a copy of the original. Package updates will overwrite it again.

## 4. Sensor firmware

```bash
sudo cp dist/firmware/ish_ptl_53c4ffad_a5d6ef13.bin /lib/firmware/intel/ish/
```

Then rebuild every initramfs — the file has to be inside it, because the sensor
hub asks for it before the root filesystem is mounted. On Debian and derivatives
that is `sudo update-initramfs -u -k all`; on Arch, `sudo mkinitcpio -P`;
elsewhere, whatever your distribution uses.

Reboot.
