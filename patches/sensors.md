# Sensors

**Symptom:** fold the screen back and nothing happens. The picture does not
rotate, and the desktop never switches to tablet mode.

Two separate things are broken, and both have to be fixed.

## The accelerometer never appears

Screen rotation needs an accelerometer, and this one sits behind the Intel
Sensor Hub — a small processor that needs firmware before it will start. The
`linux-firmware` package has no build for this model, and the generic one is
refused:

```
intel_ish_ipc 0000:00:12.0: ISH loader: cmd 2 failed 10
intel_ish_ipc 0000:00:12.0: ISH: hw start failed.
```

The driver builds the filename it looks for out of the machine's own identity
strings, which here gives `ish_ptl_53c4ffad_a5d6ef13.bin`. No package ships that
file. [`dist/firmware/`](../dist/firmware/) has it, taken from Lenovo's Windows
driver package — see [guides/firmware.md](../guides/firmware.md) if you want to
extract it yourself.

This one is not a patch. Nothing in Linux is wrong; the file simply isn't
distributable by Fedora.

## The hinge is reported in a form Linux doesn't recognise

The driver that watches the hinge, `lenovo-ymc`, receives every fold and
understands none of them:

```
lenovo-ymc: Unknown key 327681 pressed      laptop
lenovo-ymc: Unknown key 327683 pressed      drawing board
lenovo-ymc: Unknown key 327684 pressed      tent
```

It expects a small plain number, 1 to 4. This laptop's firmware puts that number
in the lowest part of the value and packs other data above it, so nothing ever
matches and the desktop is never told the machine was folded.

`sensors/0001-platform-x86-lenovo-ymc-…` looks the value up as it arrives first,
so machines that send a plain number are unaffected, then retries with just the
low part.

## What is still missing

Once the sensor hub starts, the accelerometer is the only standard sensor that
shows up. Whatever else the hub carries is described in a private format Linux
does not decode. In particular there is no ambient light sensor, so there is no
automatic brightness.
