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

## What else is in the hub

Once it starts, the hub presents thirteen sensor collections and Linux binds a
driver to exactly one of them, the accelerometer. The rest are vendor-defined,
which the kernel creates devices for but cannot decode.

They are not undecodable by you, though: each one carries its own name in a
feature report, readable straight from `/dev/hidraw`.

| Reported as | Vendor | Also provided by |
|---|---|---|
| Physical Accelerometer ×2 | Bosch BMA422 | — the pair exists to derive the hinge angle |
| Calibrated Accelerometer | Bosch BMA422 | the `accel_3d` you already have |
| Simple Orientation | — | the accelerometer, via iio-sensor-proxy |
| Tablet Mode | Intel GPIO | `lenovo-ymc`, patched above |
| Lid Closed Detection | Intel GPIO | ACPI `PNP0C0D` |
| Lid Mode | Intel | ACPI `PNP0C0D` |
| Hinge | Intel | nothing — this is the only genuinely new reading |
| Device RF Manager | Lenovo P Sensor | nothing on Linux |
| Simple DMD | Intel | — |

**None of it is worth enabling.** Everything in that list is either a duplicate
of something already working or has no consumer. The hinge sensor would report
the angle in degrees and no Linux desktop reads it; the Lenovo P Sensor drives
antenna power for SAR limits, which is handled below the operating system.

The kernel even ships a driver for the hinge, `hid-sensor-custom-intel-hinge`,
which binds to `HID-SENSOR-INT-020b` and would match this machine's sensor
exactly. It never loads because renaming the device to that name is the job of
`CONFIG_HID_SENSOR_CUSTOM_SENSOR`, which Fedora does not enable. Turning it on
costs one line and buys a number nothing reads.

## No automatic brightness, and no way to get it

There is no ambient light sensor. Not one Linux fails to decode — the complete
list above is every sensor the hub carries, and none of them measures light.
`CONFIG_HID_SENSOR_ALS` is built and waiting for a device that does not exist.

Adaptive brightness is therefore impossible on this machine, and no driver,
firmware or patch will change that.
