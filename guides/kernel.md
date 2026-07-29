# Building the kernel

Only needed if you don't want the prebuilt RPMs from
[Releases](https://github.com/laspinacristian/linux-yoga9i-gen11-aura/releases),
or once those fall behind your Fedora release. Following [Fedora's
guide](https://docs.fedoraproject.org/en-US/quick-docs/kernel-build-custom/).
About an hour and 20 GB of disk.

Four of the six patches go into the kernel. The other two are for SOF and
alsa-ucm-conf and are not used here.

```bash
cd ~/linux-yoga9i-gen11-aura
sudo dnf install fedpkg
fedpkg clone -a kernel
cd kernel
git switch f44                    # match your Fedora release
sudo dnf builddep kernel.spec
```

Fedora's spec applies `linux-kernel-test.patch` automatically when it isn't
empty:

```bash
cat ../patches/display/0001-drm-edid-*.patch \
    ../patches/display/0002-drm-i915-*.patch \
    ../patches/audio/0001-ASoC-*.patch \
    ../patches/sensors/0001-platform-x86-lenovo-ymc-*.patch \
    > linux-kernel-test.patch

fedpkg local --with baseonly --without debuginfo \
             --define 'buildid .yoga9i_gen11_aura'
```

`baseonly` skips the debug kernel, `--without debuginfo` the debug symbols;
together they halve the build. `--define` sets the buildid without editing
`kernel.spec`, which keeps `git pull` conflict-free later.

## Installing it

Five of the subpackages produced:

```bash
V=7.1.5-200.yoga9i_gen11_aura.fc44
sudo dnf install --nogpgcheck \
  ./x86_64/kernel-$V.x86_64.rpm \
  ./x86_64/kernel-core-$V.x86_64.rpm \
  ./x86_64/kernel-modules-$V.x86_64.rpm \
  ./x86_64/kernel-modules-core-$V.x86_64.rpm \
  ./x86_64/kernel-modules-extra-$V.x86_64.rpm
```

`kernel-modules-core` is required by the other four at this exact version and
can't come from Fedora's repository. Add `kernel-devel-$V` if anything builds
out-of-tree modules.

Secure Boot has to be off: these RPMs are not signed.

Then make it the one that boots — see [updates.md](updates.md).

## Rebuilding for a newer kernel

```bash
cd ~/linux-yoga9i-gen11-aura/kernel
fedpkg pull
fedpkg local --with baseonly --without debuginfo --define 'buildid .yoga9i_gen11_aura'
```

`fedpkg local` fetches the new tarball itself. A `patch` error in `%prep` means
one of the four no longer applies — probably merged upstream, so drop it.

## Publishing a release

`install.sh` downloads from `releases/latest/download/<name>.rpm`, so upload the
five RPMs under names with no version in them:

```
kernel.rpm  kernel-core.rpm  kernel-modules.rpm
kernel-modules-core.rpm  kernel-modules-extra.rpm
```

The real version lives inside the RPM and the installer reads it from there.
Stable names keep the download URLs from changing at every release.

## After installing

The kernel alone is not enough. The topology files, the ALSA change and the
sensor firmware are all still needed — [`install.sh`](../install.sh) does those,
or see [topology.md](topology.md) and [firmware.md](firmware.md).
