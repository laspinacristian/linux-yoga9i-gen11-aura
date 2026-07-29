# Extracting the sensor firmware

[`dist/firmware/ish_ptl_53c4ffad_a5d6ef13.bin`](../dist/firmware/) is already
extracted. This is where it comes from.

Download *Intel Integrated Sensor Hub Driver* from Lenovo's support site for
machine type 83SE. It is an Inno Setup installer:

```bash
sudo dnf install innoextract
innoextract -s -e <package>.exe
```

That yields three firmware files, and the one that works is not the obvious one:

| File | Size | Result |
|---|---|---|
| `IshHeci/x64/FWImage/0003/ishS_SI_5.8.0.7729.bin` | 1051136 | wrong generation |
| `IshHeci/x64/FWImage/0004/ishS_SI_5.8.1.7779.bin` | 920064 | refused |
| `IshHeciExtensionTemplate/x64/FwImage/0004/ishS_MEU_aligned.bin` | 481792 | **works** |

Install it under the name the driver looks for:

```bash
sudo cp ishS_MEU_aligned.bin \
        /lib/firmware/intel/ish/ish_ptl_53c4ffad_a5d6ef13.bin
sudo dracut -f --regenerate-all
```

`--regenerate-all` matters. The sensor hub asks for this file about a second
into boot, when the only thing available is the initramfs — so it has to be
inside it. A plain `dracut -f` only rebuilds the initramfs of the kernel you are
running right now, which after installing a new kernel is the wrong one.

Reboot before trying a different file: after a failed start the hub reports
unrelated errors.

## Checking it worked

```
$ sudo dmesg | grep ISH
ISH loader: load firmware: intel/ish/ish_ptl_53c4ffad_a5d6ef13.bin
ISH loader: firmware loaded. size:481792
```

If it says `ish_ptl.bin` instead, the file is not in the initramfs and the
driver fell back to the generic one, which this machine refuses.
