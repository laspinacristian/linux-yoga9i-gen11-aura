# The patches

Six patches, going to three different projects.

| Directory | Patch | Goes to |
|---|---|---|
| [`audio/`](audio/) | `0001-ASoC-…` | Linux kernel |
| | `0002-sof-topology-…` | [SOF](https://github.com/thesofproject/sof) |
| | `0003-alsa-ucm-…` | [alsa-ucm-conf](https://github.com/alsa-project/alsa-ucm-conf) |
| [`sensors/`](sensors/) | `0001-platform-x86-lenovo-ymc-…` | Linux kernel |
| [`display/`](display/) | `0001-drm-edid-…`, `0002-drm-i915-…` | Linux kernel |

None of them mention this laptop. They fix a chip, a driver or a config file, so
any machine with the same parts gets the same fix. That is also what makes them
sendable upstream — which is the point, so that one day none of this is needed.

Each patch carries its own explanation in its commit message. The three pages
below say the same thing in plainer words, so you can decide whether a patch
matters to you without reading the code.

- **[Audio](audio.md)** — no sound at all, from any speaker or jack
- **[Sensors](sensors.md)** — the screen never rotates when you fold the laptop
- **[Display](display.md)** — the brightness keys move the slider and nothing happens

## Applying them

You don't have to. [`install.sh`](../install.sh) installs everything already
built. These are here for people who want to compile it themselves, or who are
on another distribution — see [guides/](../guides/).
