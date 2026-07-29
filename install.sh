#!/usr/bin/env bash
#
# Lenovo Yoga 9i 2-in-1 Gen 11 Aura Edition (14IPH11) — Fedora 44
#
# Installs the patched kernel, the audio topology files, the ALSA speaker
# configuration and the sensor firmware, then rebuilds every initramfs.
#
# Safe to run again: it replaces whatever it finds, so re-run it after a new
# release, or after an alsa-ucm update takes the speaker configuration away.
#
#   curl -fsSL https://raw.githubusercontent.com/laspinacristian/linux-yoga9i-gen11-aura/main/install.sh | sudo bash

set -euo pipefail

REPO="laspinacristian/linux-yoga9i-gen11-aura"
RAW="https://raw.githubusercontent.com/${REPO}/main"
REL="https://github.com/${REPO}/releases/latest/download"

TPLG_DIR="/lib/firmware/intel/sof-ipc4-tplg"
ISH_DIR="/lib/firmware/intel/ish"
ISH_FILE="ish_ptl_53c4ffad_a5d6ef13.bin"
UCM_FILE="/usr/share/alsa/ucm2/sof-soundwire/cs42l43-spk.conf"
EDID_DIR="/lib/firmware/edid"
EDID_FILE="yoga-9i-hdr.bin"
EDID_CONNECTOR="eDP-1"
DRACUT_CONF="/etc/dracut.conf.d/edid-override.conf"

KERNEL_RPMS=(kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra)
TPLG_FILES=(sof-ptl-cs42l43-l0.tplg sof-ptl-cs42l43-l0-2ch.tplg sof-ptl-cs42l43-l0-4ch.tplg)

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\n\033[1;31mError:\033[0m %s\n\n' "$*" >&2; exit 1; }

fetch() { curl -fsSL --retry 3 --retry-delay 2 -o "$2" "$1" || die "could not download $1"; }

# ---------------------------------------------------------------- checks ----

[[ ${EUID} -eq 0 ]] || die "run this as root:
    curl -fsSL ${RAW}/install.sh | sudo bash"

[[ -r /etc/os-release ]] || die "cannot read /etc/os-release"
. /etc/os-release
if [[ ${ID:-} != fedora || ${VERSION_ID:-} != 44 ]]; then
    die "this installer is for Fedora 44, found ${PRETTY_NAME:-unknown}.
See ${RAW}/guides/other-distros.md"
fi

sb_var=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
if [[ -r ${sb_var} ]] && [[ $(od -An -t u1 "${sb_var}" | awk '{print $NF}') == 1 ]]; then
    die "Secure Boot is enabled. The kernel installed here is not signed and
will not boot. Turn Secure Boot off in the firmware setup, then run this again."
fi

for cmd in curl dnf rpm dracut grubby; do
    command -v "${cmd}" >/dev/null || die "missing required command: ${cmd}"
done

# -------------------------------------------------------------- download ----

TMP=$(mktemp -d /tmp/yoga9i-install.XXXXXX)

say "Downloading"

for rpm in "${KERNEL_RPMS[@]}"; do
    info "${rpm}.rpm"
    fetch "${REL}/${rpm}.rpm" "${TMP}/${rpm}.rpm"
done

for t in "${TPLG_FILES[@]}"; do
    info "${t}"
    fetch "${RAW}/dist/tplg/${t}" "${TMP}/${t}"
done

info "${ISH_FILE}"
fetch "${RAW}/dist/firmware/${ISH_FILE}" "${TMP}/${ISH_FILE}"

info "cs42l43-spk.conf"
fetch "${RAW}/dist/ucm/cs42l43-spk.conf" "${TMP}/cs42l43-spk.conf"

info "${EDID_FILE}"
fetch "${RAW}/dist/edid/${EDID_FILE}" "${TMP}/${EDID_FILE}"

KVER=$(rpm -qp --nosignature --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "${TMP}/kernel-core.rpm")
[[ -n ${KVER} ]] || die "could not read the kernel version out of kernel-core.rpm"

# --------------------------------------------------------------- install ----

say "Sensor firmware"
install -D -m 644 "${TMP}/${ISH_FILE}" "${ISH_DIR}/${ISH_FILE}"
info "${ISH_DIR}/${ISH_FILE}"

say "Audio topology"
for t in "${TPLG_FILES[@]}"; do
    install -D -m 644 "${TMP}/${t}" "${TPLG_DIR}/${t}"
    info "${TPLG_DIR}/${t}"
done

say "ALSA speaker configuration"
if [[ -f ${UCM_FILE} ]]; then
    # Keep a copy of whatever the alsa-ucm package last put here, but never
    # overwrite that copy with our own file on a second run.
    if ! grep -q "Speaker Digital Switch' 1" "${UCM_FILE}"; then
        cp -f "${UCM_FILE}" "${UCM_FILE}.orig"
        info "original saved as $(basename "${UCM_FILE}").orig"
    fi
    install -m 644 "${TMP}/cs42l43-spk.conf" "${UCM_FILE}"
    info "${UCM_FILE}"
else
    info "alsa-ucm is not installed, skipping"
fi

say "HDR EDID override"
# The panel announces its HDR abilities over the AUX channel and not in its
# EDID, which is the only place the desktop looks. This is that EDID with the
# two missing CTA blocks appended; the kernel is told to use it instead.
install -D -m 644 "${TMP}/${EDID_FILE}" "${EDID_DIR}/${EDID_FILE}"
info "${EDID_DIR}/${EDID_FILE}"
printf 'install_items+=" %s/%s "\n' "${EDID_DIR}" "${EDID_FILE}" > "${DRACUT_CONF}"
info "${DRACUT_CONF}"
# --args replaces an existing drm.edid_firmware= rather than appending a second
# one, and rewrites /etc/kernel/cmdline so later kernels inherit it too.
grubby --update-kernel=ALL \
       --args="drm.edid_firmware=${EDID_CONNECTOR}:edid/${EDID_FILE}"
info "drm.edid_firmware=${EDID_CONNECTOR}:edid/${EDID_FILE}"

say "Kernel ${KVER}"
dnf install -y --nogpgcheck "${TMP}"/kernel*.rpm

say "Boot configuration"
if [[ -f /etc/sysconfig/kernel ]]; then
    sed -i 's/^UPDATEDEFAULT=.*/UPDATEDEFAULT=no/' /etc/sysconfig/kernel
    info "Fedora will no longer make its own kernels the default"
fi
grubby --set-default="/boot/vmlinuz-${KVER}"
info "booting ${KVER} from now on"

say "Rebuilding initramfs"
dracut -f --regenerate-all
info "done — the sensor firmware has to be inside the initramfs to load"

# ------------------------------------------------------------------ done ----

printf '\n\033[1;32mDone.\033[0m Reboot to use it.\n\n'
