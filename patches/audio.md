# Audio

**Symptom:** no sound at all. Speakers, headphone jack and microphones are
silent. Only HDMI works.

## Why

The laptop has three audio chips on one internal bus:

```
CS42L43   headphone jack, microphones, the two tweeters
CS35L57   left woofer
CS35L57   right woofer
```

Linux keeps a hand-written list of which audio chip sits on which bus, and this
laptop is not on it. Lenovo put all three on bus 0; the similar models that
Linux already knows about are Dells, which use buses 2 and 3. Without an entry,
the driver never sets any of it up.

Three separate things are missing. All three are needed before a single sound
comes out.

## 1. The kernel entry

`audio/0001-ASoC-…` adds this combination — codec on bus 0, the two amplifiers
as a pair — to the list of layouts the driver recognises.

## 2. The topology files

The audio processor inside the chipset needs to be told how to route sound.
That description lives in `.tplg` files, and there was none for this layout.

`audio/0002-sof-topology-…` adds three of them to SOF, which is the project that
builds those files. Linux picks between the three by name, depending on how many
microphones it finds.

The same patch also lowers a filter. SOF's generic default cuts everything below
100 Hz on the speaker path, as a blanket precaution for hardware it knows
nothing about. Here that protection already exists and is far better: the
CS35L57 amplifiers run Lenovo firmware that watches what the speaker cone is
actually doing and holds it back only when it needs to. The generic filter just
threw away bass the amplifiers were built to reproduce. It is now set to 30 Hz,
which leaves that job to the amplifiers.

## 3. The tweeters

The two tweeters are driven by the CS42L43 — the same chip as the headphone
jack — and sit behind a switch that nothing turns on. On the other laptops using
that chip it drives no speakers at all, so nobody ever needed to.

`audio/0003-alsa-ucm-…` turns it on together with the rest of the speaker path,
and off again with it.

Without this you still get sound, but only from the woofers: no treble.
