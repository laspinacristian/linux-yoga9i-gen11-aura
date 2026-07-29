# Building the audio topology files

The three `.tplg` files in [`dist/tplg/`](../dist/tplg/) are already built. This
is how to produce them yourself.

```bash
sudo dnf install git cmake ninja-build alsa-topology-utils

cd ~
git clone --filter=blob:none https://github.com/thesofproject/sof.git
mkdir -p tools/bin && ln -sf "$(command -v alsatplg)" tools/bin/alsatplg

cd sof
git apply ~/linux-yoga9i-gen11-aura/patches/audio/0002-sof-topology-*.patch
./scripts/build-tools.sh -Y
```

The symlink is not optional, and it has to sit next to the clone, not inside it.
`tools/topology/CMakeLists.txt` hardcodes the path to `alsatplg` as a sibling of
the source tree and never looks at `$PATH`. Without it CMake only warns that
topologies will be skipped, the build reports success, and no `.tplg` is
produced at all.

Then install them:

```bash
sudo cp ~/sof/tools/build_tools/topology/topology2/production/sof-ptl-cs42l43-l0*.tplg \
        /lib/firmware/intel/sof-ipc4-tplg/
```

Reboot. The topology is read once, when the audio driver starts.

Three files are built because Linux picks between them by name, depending on how
many microphones it finds. Install all three.
