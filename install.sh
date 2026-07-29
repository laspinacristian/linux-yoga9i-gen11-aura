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

WITH_HDR_EDID=0

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\n\033[1;33mWarning:\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31mError:\033[0m %s\n\n' "$*" >&2; exit 1; }

fetch() { curl -fsSL --retry 3 --retry-delay 2 -o "$2" "$1" || die "could not download $1"; }

usage() {
    cat <<EOF
usage: install.sh [--hdr-edid]

Installs the patched kernel, the audio topology files, the ALSA speaker
configuration and the sensor firmware, then rebuilds every initramfs.

  --hdr-edid   Also install the HDR EDID override. The panel does not
               advertise its HDR abilities in a form the desktop reads, and
               this replaces its EDID with one that does. It describes one
               specific panel: vendor EDO, product EE00QBA63.E. Leave it off
               unless you have that panel. Nothing else here depends on it.
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --hdr-edid) WITH_HDR_EDID=1 ;;
        -h|--help)  usage; exit 0 ;;
        *)          usage >&2; die "unknown option: $1" ;;
    esac
    shift
done

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

if [[ ${WITH_HDR_EDID} -eq 1 ]]; then
    info "${EDID_FILE}"
    fetch "${RAW}/dist/edid/${EDID_FILE}" "${TMP}/${EDID_FILE}"
fi

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

if [[ ${WITH_HDR_EDID} -eq 1 ]]; then
    say "HDR EDID override"
    # The panel announces its HDR abilities over the AUX channel and not in its
    # EDID, which is the only place the desktop looks. This is that EDID with
    # the two missing CTA blocks appended; the kernel is told to use it instead.
    install -D -m 644 "${TMP}/${EDID_FILE}" "${EDID_DIR}/${EDID_FILE}"
    info "${EDID_DIR}/${EDID_FILE}"
    printf 'install_items+=" %s/%s "\n' "${EDID_DIR}" "${EDID_FILE}" > "${DRACUT_CONF}"
    info "${DRACUT_CONF}"
    # --args replaces an existing drm.edid_firmware= rather than appending a
    # second one, and rewrites /etc/kernel/cmdline so later kernels inherit it.
    grubby --update-kernel=ALL \
           --args="drm.edid_firmware=${EDID_CONNECTOR}:edid/${EDID_FILE}"
    info "drm.edid_firmware=${EDID_CONNECTOR}:edid/${EDID_FILE}"
fi

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

say "Colour mode"
# This panel is much wider than sRGB. GNOME's default colour mode declares the
# output to be sRGB, so untagged content passes through untouched and comes out
# oversaturated. sdr-native describes the output with the panel's real
# primaries instead. Settings has no control for it; gdctl is the only way.
#
# gdctl talks to the compositor of a running session over the session bus, so
# this only works when run from inside the desktop, and it has to run as that
# user rather than as root.
set_colour_mode() {
    local sess type state user uid seat conns conn mode scale before

    command -v gdctl >/dev/null || { info "gdctl not found, skipping"; return; }

    for sess in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
        type=$(loginctl show-session "${sess}" -p Type --value 2>/dev/null || true)
        state=$(loginctl show-session "${sess}" -p State --value 2>/dev/null || true)
        if [[ ${type} == wayland || ${type} == x11 ]] && [[ ${state} == active ]]; then
            user=$(loginctl show-session "${sess}" -p Name --value)
            uid=$(loginctl show-session "${sess}" -p User --value)
            seat=$(loginctl show-session "${sess}" -p Seat --value)
            break
        fi
    done
    [[ -n ${user:-} ]] || { info "no active desktop session, skipping"; return; }

    run() { sudo -u "${user}" env XDG_RUNTIME_DIR="/run/user/${uid}" "$@"; }

    run gdctl show >/dev/null 2>&1 || { info "no GNOME session for ${user}, skipping"; return; }

    # Only touch a single-monitor setup. Rebuilding a multi-monitor layout from
    # parsed output is not something an installer should be doing unattended.
    mapfile -t conns < <(run gdctl show 2>/dev/null |
                         grep -oE '──Monitor [A-Za-z0-9_-]+' | sed 's/.*──Monitor //')
    if [[ ${#conns[@]} -ne 1 ]]; then
        info "${#conns[@]} monitors connected, skipping — see guides/color.md"
        return
    fi
    conn=${conns[0]}

    run gdctl show -p 2>/dev/null | grep -q 'supported-color-modes.*sdr-native' || {
        info "${conn} does not offer sdr-native, skipping"; return; }

    if run gdctl show -p 2>/dev/null | grep -v supported | grep -q 'color-mode.*sdr-native'; then
        info "${conn} is already on sdr-native"
        sync_gdm_config "${user}" "${seat}"
        return
    fi

    # gdctl rebuilds the whole configuration and fills anything omitted from the
    # monitor's preferred values, not the current ones. Leaving --mode out would
    # silently drop this panel from 120 Hz to its preferred 60 Hz, so read both
    # back and pass them in.
    mode=$(run gdctl show 2>/dev/null | grep -A1 'Current mode' | tail -1 |
           grep -oE '[0-9]+x[0-9]+@[0-9.]+(\+vrr)?' || true)
    scale=$(run gdctl show 2>/dev/null | grep -oE 'Scale: [0-9.]+' | head -1 |
            awk '{print $2}' || true)
    if [[ -z ${mode} || -z ${scale} ]]; then
        info "could not read the current mode and scale, skipping"
        return
    fi

    # -V verifies without applying. A layout with no primary is rejected, hence
    # --primary; check before touching anything rather than after.
    if ! run gdctl set -V -LM "${conn}" --primary --mode "${mode}" \
                       --scale "${scale}" --color-mode sdr-native >/dev/null 2>&1; then
        warn "the colour mode command did not verify, leaving the display alone
    See ${RAW}/guides/color.md to set it by hand."
        return
    fi

    before=$(stat -c %Y "$(getent passwd "${user}" | cut -d: -f6)/.config/monitors.xml" 2>/dev/null || echo 0)

    if run gdctl set -P -LM "${conn}" --primary --mode "${mode}" \
                     --scale "${scale}" --color-mode sdr-native >/dev/null 2>&1; then
        info "${conn} set to sdr-native at ${mode}, scale ${scale}"
        sync_gdm_config "${user}" "${seat}" "${before}"
    else
        warn "could not set the colour mode; see ${RAW}/guides/color.md"
    fi
}

# The login screen runs its own compositor with its own configuration, so it
# does not inherit any of the above and comes up with the oversaturated
# default. Give it the same file.
sync_gdm_config() {
    local user=$1 seat=$2 before=${3:-} home src dst dir

    [[ -n ${seat} ]] || return 0
    dir="/var/lib/gdm/${seat}/config"
    # Created by GDM itself; if it is not there, GDM has never run here.
    [[ -d ${dir} ]] || { info "no GDM config directory, skipping login screen"; return 0; }

    home=$(getent passwd "${user}" | cut -d: -f6)
    src="${home}/.config/monitors.xml"
    dst="${dir}/monitors.xml"

    # mutter writes the file about two seconds after the change, not on the
    # way out of gdctl, so copying straight away would take the old contents.
    if [[ -n ${before} ]]; then
        for _ in $(seq 1 20); do
            [[ -f ${src} ]] && [[ $(stat -c %Y "${src}") != "${before}" ]] && break
            sleep 0.5
        done
    fi
    [[ -f ${src} ]] || { info "no monitors.xml to copy, skipping login screen"; return 0; }

    install -m 644 "${src}" "${dst}"
    # GDM runs as a systemd dynamic user, so its uid is not fixed and naming it
    # would be wrong; take whatever owns the directory. Without the SELinux
    # label GDM cannot read the file and ignores it without saying so.
    chown --reference="${dir}" "${dst}"
    command -v restorecon >/dev/null && restorecon "${dst}" 2>/dev/null || true
    info "login screen configured from ${src}"
}
set_colour_mode

# ------------------------------------------------------------------ done ----

printf '\n\033[1;32mDone.\033[0m Reboot to use it.\n'
if [[ ${WITH_HDR_EDID} -eq 0 ]]; then
    printf 'HDR was not installed. Pass --hdr-edid if you want it.\n'
fi
printf '\n'
