# Display

**Symptom:** the brightness keys move the on-screen slider and the panel stays
at full brightness.

## Why

This is an OLED panel with no backlight to dim. Brightness is set by sending the
panel a number in nits over the video cable, and to do that the driver has to
know how bright the panel can actually go.

That figure is published in the panel's own description, but in a section the
kernel only reads for screen timings:

```
Native Maximum Luminance (Full Coverage): 500.000000 cd/m^2
Native Minimum Luminance: 4.000000 cd/m^2
```

The driver looks for it in a different section, doesn't find it, and falls back
to the old backlight method — which on this panel does nothing at all.

Two patches, and both are needed:

- `display/0001-drm-edid-…` reads the range from the section it is actually in
- `display/0002-drm-i915-…` stops the driver rejecting a range that came from
  there

Panels that publish the figure the usual way keep behaving exactly as before.
Afterwards the panel reports its real maximum of 500 nits and the keys work.

## HDR

The panel can do HDR and the desktop offers no switch for it.

This one has no patch. The panel announces its HDR abilities over the video
cable but not in the description the desktop reads, and the desktop parses that
description itself rather than asking the kernel — so fixing the driver would
change nothing. Making it work properly needs new kernel interfaces that don't
exist yet.

There is a local workaround: [`dist/edid/yoga-9i-hdr.bin`](../dist/edid/) is this
panel's own description with the missing HDR section added, which can be fed to
the kernel to override the real one.

**The installer does not touch it.** That file describes one specific panel, and
loading it on a different one is a bad idea. Nothing else in this project
depends on it — brightness works without it.
