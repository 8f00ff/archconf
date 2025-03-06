#!/bin/bash

function smb() {
  local HOST="${1}"
  local USERNAME="${2}"
  local SOURCE="${3:-$USERNAME}"
  local TARGET="${4:-/mnt/${HOST}/${SOURCE}}"
  
  if [[ -z "${HOST}" || -z "${USERNAME}" ]]; then
    echo "usage: smb <host> <username> [source] [target]"
    exit 1
  fi
  
  mkdir -p "${TARGET}" && exit $?
  mount -t cifs "//${HOST}/${SOURCE}" "${TARGET}" -o "username=${USERNAME}" || exit $?
  
  return 0
}

function parse_txt() {
  local SOURCE_PATH="${1}"
  local CATEGORY="${2}"
  local CONTENT
  
  if [[ -z "${SOURCE_PATH}" ]]; then
    echo "usage: parse_txt <file> [category]"
    exit 1
  fi
  
  if [[ ! -f "${SOURCE_PATH}" ]]; then
    echo "error: file not found at path: ${SOURCE_PATH}" 1>&2
    exit 1
  fi
  
  if [[ -n "${CATEGORY}" ]]; then
    CONTENT="$(awk '/^[[:space:]]*#[[:space:]]*'"${CATEGORY}"'/ {flag=1; next} /^[[:space:]]*#/ {flag=0} flag' "${SOURCE_PATH}")"
  else
    CONTENT="$(cat "${SOURCE_PATH}")"
  fi
  
  echo "${CONTENT}" | sed -E -e 's/[[:space:]]*#.*$//g' -e '/^[[:space:]]*$/d' -e 's/ +/=/g' || exit $?
  
  return 0
}

function pkg_list_strip_ver() {
  sed -E -e 's/=.*//g'
}

function load_config() {
  CONFIG_PATH="${1:-config.json}"
  
  if ! command -v jq 2>&1 >/dev/null; then
    pacman -Sy --noconfirm jq 2>&1 >/dev/null || exit $?
  fi
  
  if [[ ! -f  "${CONFIG_PATH}" ]]; then
    echo "error: config file not found at path: ${CONFIG_PATH}" 1>&2
    exit 1
  fi
  
  HOSTNAME="$(jq -r '.hostname' "${CONFIG_PATH}")"
  TIMEZONE="$(jq -r '.timezone' ${CONFIG_PATH})"
  
  FRESH_HOMEDIRS="$(jq -r '.installation.fresh_homedirs' ${CONFIG_PATH})"
  WIPE_HOME="$(jq -r '.installation.wipe_home' ${CONFIG_PATH})"
  REBOOT_AFTER_INSTALL="$(jq -r '.installation.reboot_after_install' ${CONFIG_PATH})"
  
  ROOT_LABEL="$(jq -r '.installation.disks.root.label' ${CONFIG_PATH})"
  ROOT_PARTLABEL="$(jq -r '.installation.disks.root.partlabel' ${CONFIG_PATH})"
  EFI_LABEL="$(jq -r '.installation.disks.efi.label' ${CONFIG_PATH})"
  EFI_PARTLABEL="$(jq -r '.installation.disks.efi.partlabel' ${CONFIG_PATH})"
  HOME_LABEL="$(jq -r '.installation.disks.home.label' ${CONFIG_PATH})"
  HOME_PARTLABEL="$(jq -r '.installation.disks.home.partlabel' ${CONFIG_PATH})"
  SWAP_LABEL="$(jq -r '.installation.disks.swap.label' ${CONFIG_PATH})"
  SWAP_PARTLABEL="$(jq -r '.installation.disks.swap.partlabel' ${CONFIG_PATH})"
  
  INSTALL_PATH="$(jq -r '.installation.paths.install' ${CONFIG_PATH})"
  EFI_PATH="$(jq -r '.installation.paths.home' ${CONFIG_PATH})"
  HOME_PATH="$(jq -r '.installation.paths.efi' ${CONFIG_PATH})"
  
  for i in \
    HOSTNAME \
    TIMEZONE \
    FRESH_HOMEDIRS \
    WIPE_HOME \
    REBOOT_AFTER_INSTALL \
    ROOT_LABEL \
    ROOT_PARTLABEL \
    EFI_LABEL \
    EFI_PARTLABEL \
    HOME_LABEL \
    HOME_PARTLABEL \
    SWAP_LABEL \
    SWAP_PARTLABEL \
    INSTALL_PATH \
    HOME_PATH \
    EFI_PATH \
    ; do
    if [[ "${!i}" == "null" ]]; then
      unset "${i}"
    fi
  done
  
  for i in FRESH_HOMEDIRS WIPE_HOME REBOOT_AFTER_INSTALL; do
    if [[ "${!i,,}" != 'true' && "${!i}" != '1' ]]; then
      unset "${i}"
    fi
  done
  
  unset PACSTRAP PACKAGES SERVICES FLATPAKS
  
  if [[ "$(jq '.installation.packages' "${CONFIG_PATH}")" != 'null' ]]; then
    PACSTRAP="$(jq -r '.installation.packages[]' ${CONFIG_PATH})"
  fi
  if [[ "$(jq '.packages' "${CONFIG_PATH}")" != 'null' ]]; then
    PACKAGES="$(jq -r '.packages[]' ${CONFIG_PATH})"
  fi
  if [[ "$(jq '.services' "${CONFIG_PATH}")" != 'null' ]]; then
    SERVICES="$(jq -r '.services[]' ${CONFIG_PATH})"
  fi
  if [[ "$(jq '.flatpaks' "${CONFIG_PATH}")" != 'null' ]]; then
    FLATPAKS="$(jq -r '.flatpaks[]' ${CONFIG_PATH})"
  fi
  
  if [[ -z "${INSTALL_PATH}" ]]; then
    echo 'error: INSTALL_PATH not defined' 1>&2
    exit 1
  fi
  
  if [[ -z "${EFI_PATH}" ]]; then
    echo 'error: EFI_PATH not defined' 1>&2
    exit 1
  fi
  
  if [[ -z "${ROOT_LABEL}" && -z "${ROOT_PARTLABEL}" ]]; then
    echo 'error: ROOT_LABEL and ROOT_PARTLABEL not defined' 1>&2
    exit 1
  fi
  
  if [[ -z "${EFI_LABEL}" && -z "${EFI_PARTLABEL}" ]]; then
    echo 'error: EFI_LABEL and EFI_PARTLABEL not defined' 1>&2
    exit 1
  fi
  
  if [[ -z "${HOME_PATH}" && (-n "${HOME_LABEL}" || -n "${HOME_PARTLABEL}") ]]; then
    echo 'error: HOME_PATH not defined but HOME_LABEL and HOME_PARTLABEL defined' 1>&2
    exit 1
  fi
  
  if [[ -n "${HOME_PATH}" && (-z "${HOME_LABEL}" && -z "${HOME_PARTLABEL}") ]]; then
    echo 'error: HOME_LABEL and HOME_PARTLABEL not defined but HOME_PATH defined' 1>&2
    exit 1
  fi
  
  if [[ -n "${HOME_PATH}" ]]; then
    HOME_PATH="$(realpath -m ${INSTALL_PATH}/${HOME_PATH})"
  fi
  
  EFI_PATH="$(realpath -m ${INSTALL_PATH}/${EFI_PATH})"
}

function detect_disk() {
  PREFIX="${1}"
  
  if [[ -z "${PREFIX}" ]]; then
    echo "error: prefix not defined" 1>&2
    exit 1
  fi
  
  local LABEL="${PREFIX}_LABEL"
  local PARTLABEL="${PREFIX}_PARTLABEL"
  
  if [[ -z "${!LABEL}" && -z "${!PARTLABEL}" ]]; then
    return 0
  fi
  
  local RESULT="$(realpath -e "/dev/disk/by-label/${!LABEL}" 2>/dev/null || realpath -e "/dev/disk/by-partlabel/${!PARTLABEL}" 2>/dev/null)"
  
  if [[ ! -b "${RESULT}" ]]; then
    echo "error: could not detect disk for ${PREFIX}." 1>&2
    exit 1
  fi
  
  declare -g "${PREFIX}_DEV=${RESULT}"
  
  return 0
}

function umount_disk() {
  SOURCE="${1}"
  
  if [[ -z "${SOURCE}" ]]; then
    echo "usage: umount_disk <source>"
    exit 1
  fi
  
  if [[ -b "${i}" ]]; then
    echo "error: source device not found: ${SOURCE}" 1>&2
    exit 1
  fi
  
  if grep -q "${SOURCE}" /proc/mounts; then
    umount "${SOURCE}" || exit $?
  fi
  
  if grep -q "${SOURCE}" /proc/swaps; then
    swapoff "${SOURCE}" || exit $?
  fi
  
  return 0
}

function format_disk() {
  DISK="${@: -1}"
  
  umount_disk "${DISK}" || exit $?
  
  wipefs -af "${DISK}" || exit $?
  if [[ "${1}" == '-t' && "${2}" == 'swap' ]]; then
    mkswap "${DISK}" || exit $?
  else
    mkfs $@ || exit $?
  fi
}

function mount_disk() {
  SOURCE="${1}"
  TARGET="${2}"
  
  if [[ -z "${SOURCE}" ]]; then
    echo "usage: mount_disk <source> [target]"
    exit 1
  fi
  
  if [[ ! -b "${SOURCE}" ]]; then
    echo "error: source device not found: ${SOURCE}" 1>&2
    exit 1
  fi
  
  if [[ "${TARGET}" == 'swap' || "$(lsblk -no FSTYPE ${SOURCE})" == 'swap' ]]; then
    if grep -q "${SOURCE}" /proc/swaps; then
      return 0
    fi
    
    swapon "${SOURCE}" || exit $?
  else
    if [[ -z "${TARGET}" ]]; then
      echo "error: target required for non-swap devices" 1>&2
      exit 1
    fi
    
    if grep -q "${TARGET}" /proc/mounts; then
      return 0
    fi
    
    if [[ ! -d "${TARGET}" ]]; then
      mkdir -p "${TARGET}" || exit $?
    fi
    
    if [[ "$(ls -1 "${TARGET}" | wc -l)" != 0 ]]; then
      echo "error: target directory not empty: ${TARGET}" 1>&2
      exit 1
    fi
    
    mount "${SOURCE}" "${TARGET}" || exit $?
    
    return 0
  fi
  
  return 0
}

function setup_disks() {
  for i in EFI HOME ROOT SWAP;
    do detect_disk "${i}" || exit $?
  done
  
  format_disk -t vfat -F 32 "${EFI_DEV}" || exit $?
  if [[ -n "${HOME_DEV}" ]]; then
    if [[ -n "${WIPE_HOME}" ]]; then
      format_disk -t ext4 "${HOME_DEV}" || exit $?
    else
      umount_disk "${HOME_DEV}" || exit $?
    fi
  fi
  format_disk -t ext4 "${ROOT_DEV}" || exit $?
  if [[ -n "${SWAP_DEV}" ]]; then
    format_disk -t swap "${SWAP_DEV}" || exit $?
  fi
  
  sleep 1
  
  mount_disk "${ROOT_DEV}" "${INSTALL_PATH}" || exit $?
  mount_disk "${EFI_DEV}" "${EFI_PATH}" || exit $?
  mount_disk "${HOME_DEV}" "${HOME_PATH}" || exit $?
  if [[ -n "${SWAP_DEV}" ]]; then
    mount_disk "${SWAP_DEV}" || exit $?
  fi
}

function generate_fstab() {
  local TARGET_PATH="${1:-${INSTALL_PATH}/etc/fstab}"
  local TARGET_DIR="$(dirname "${TARGET_PATH}")"
  
  if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "error: destination does not exist or is not a directory at path: ${TARGET_DIR}" 1>&2
    exit 1
  fi
  
  printf '# Static information about the filesystems.\n# See fstab(5) for details.\n' > "${TARGET_PATH}" || exit $?
  genfstab -U "${INSTALL_PATH}" >> "${TARGET_PATH}" || exit $?
  
  return 0
}

function locale_gen() {
  TARGET_PATH="${1:-${INSTALL_PATH}/etc/locale.gen}"
  
  if [[ ! -f "${TARGET_PATH}" ]]; then
    echo "error: target file not found at path: ${TARGET_PATH}" 1>&2
    exit 1
  fi
  
  jq -r '.locales[]' "${CONFIG_PATH}" | while IFS= read -r i; do
    if grep -qe "^${i}" "${TARGET_PATH}"; then
      sed -i -E -e "s/^[[:space:]#]*(${i})[[:space:]#]*/\1/g" "${TARGET_PATH}" || exit $?
    else
      echo "${i}" >> "${TARGET_PATH}" || exit $?
    fi
  done
  
  return 0
}

function chaotic_aur() {
  arch-chroot "${INSTALL_PATH}" pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  arch-chroot "${INSTALL_PATH}" pacman-key --lsign-key 3056513887B78AEB
  arch-chroot "${INSTALL_PATH}" pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
  arch-chroot "${INSTALL_PATH}" pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
  if ! grep -Pz '\[chaotic-aur\]\nInclude = /etc/pacman.d/chaotic-mirrorlist' "${INSTALL_PATH}/etc/pacman.conf" 2>&1 >/dev/null; then
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' >> "${INSTALL_PATH}/etc/pacman.conf"
  fi
  arch-chroot "${INSTALL_PATH}" pacman -Sy --noconfirm
}

function configure_users() {
  for i in $(jq -r '.users | keys[]' "${CONFIG_PATH}"); do
    name="${i}"
    uid="$(jq -r ".users[\"${i}\"].uid" "${CONFIG_PATH}")"
    gid="$(jq -r ".users[\"${i}\"].gid" "${CONFIG_PATH}")"
    gecos="$(jq -r ".users[\"${i}\"].gecos" "${CONFIG_PATH}")"
    home="$(jq -r ".users[\"${i}\"].home" "${CONFIG_PATH}")"
    shell="$(jq -r ".users[\"${i}\"].shell" "${CONFIG_PATH}")"
    
    for j in name uid gid gecos home shell; do
      if [[ "${!j}" == "null" ]]; then
        unset "${j}"
      fi
    done
    
    cmd="useradd"
    if arch-chroot "${INSTALL_PATH}" getent passwd "${name}" >/dev/null 2>&1; then
      cmd="usermod"
    else
      new_user=1
    fi
    
    if [[ -n "${home}" ]]; then
      home_args="-m --home ${home}"
      
      HOME_PATH="$(realpath -m "${INSTALL_PATH}/${home}")"
      if [[ -n "${FRESH_HOMEDIRS}" && -d "${HOME_PATH}" ]]; then
        NEW_HOME_PATH="${HOME_PATH}-$(date +%Y%m%dT%H%M%S)"
        echo "backing up home directory of user ${name} as $(basename "${NEW_HOME_PATH}")"
        mv "${HOME_PATH}" "${NEW_HOME_PATH}"
      fi
    else
      directory_args="-M"
    fi
    
    arch-chroot "${INSTALL_PATH}" $cmd \
      ${uid:+${new_user:+-N} --uid "${uid}"} \
      ${gid:+--gid "${gid}"} \
      ${gecos:+--comment "${gecos}"} \
      ${home_args} \
      ${shell:+--shell "${shell}"} \
      "${name}" || exit $?
    
    if [[ -n "${DEFAULT_PASSWORD}" ]]; then
      echo "${name}:${DEFAULT_PASSWORD}" | arch-chroot "${INSTALL_PATH}" chpasswd
    fi
  done
  
  return 0
}

function configure_groups() {
  for i in $(jq -r '.groups | keys[]' "${CONFIG_PATH}"); do
    group_name="${i}"
    gid="$(jq -r ".groups[\"${i}\"].gid" "${CONFIG_PATH}")"
    if [[ "$(jq ".groups[\"${i}\"].users" "${CONFIG_PATH}")" != 'null' ]]; then
      users="$(jq -r ".groups[\"${i}\"].users[]" "${CONFIG_PATH}")"
    fi
    
    for j in group_name gid members; do
      if [[ "${!j}" == "null" ]]; then
        unset "${j}"
      fi
    done
    
    cmd="groupadd"
    if arch-chroot "${INSTALL_PATH}" getent group "${group_name}" >/dev/null 2>&1; then
      cmd="groupmod"
    fi
    
    arch-chroot "${INSTALL_PATH}" $cmd \
      ${gid:+--gid "${gid}"} \
      ${users:+--users "${users}"} \
      "${group_name}" || exit $?
  done
  
  exit 0
  
  while IFS= read -r line; do
    group_name="$(echo "${line}" | cut -d: -f1)"
    gid="$(echo "${line}" | cut -d: -f3)"
    user_list="$(echo "${line}" | cut -d: -f4)"
    
    cmd="groupadd"
    if arch-chroot "${INSTALL_PATH}" getent group "${group_name}" >/dev/null 2>&1; then
      cmd="groupmod"
    fi
    
    arch-chroot "${INSTALL_PATH}" $cmd \
      ${gid:+--gid "${gid}"} \
      ${user_list:+--users "${user_list}"} \
      "${group_name}" || exit $?
  done < 'group'
  
  return 0
}

function install_chroot() {
  # pacstrap packages
  pacstrap -K "${INSTALL_PATH}" ${PACSTRAP[@]} || exit $?
  
  # fstab
  generate_fstab "${INSTALL_PATH}" || exit $?
  
  #hostname
  echo "${HOSTNAME}" > "${INSTALL_PATH}/etc/hostname"
  
  # time
  if [[ -n "${TIMEZONE}" && -f "/usr/share/zoneinfo/${TIMEZONE}" ]]; then
    arch-chroot "${INSTALL_PATH}" ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
  fi
  arch-chroot "${INSTALL_PATH}" hwclock --systohc
  
  # localization
  if [[ -f locale.gen ]]; then
    locale_gen "${INSTALL_PATH}" locale.gen
  fi
  
  # systemd services
  if [[ -n "${SERVICES}" ]]; then
    arch-chroot "${INSTALL_PATH}" systemctl enable ${SERVICES[@]} || exit $?
  fi
  
  # initramfs
  arch-chroot "${INSTALL_PATH}" mkinitcpio -P || exit $?
  
  # chaotic-aur
  chaotic_aur || exit $?
  
  # all packages
  arch-chroot "${INSTALL_PATH}" pacman -S --needed --noconfirm ${PACKAGES[@]} || exit $?
  
  # users
  configure_users || exit $?
  
  # default root password
  if [[ -n "${DEFAULT_PASSWORD}" ]]; then
    echo "root:${DEFAULT_PASSWORD}" | arch-chroot "${INSTALL_PATH}" chpasswd
  fi
  
  # groups
  configure_groups || exit $?
  
  # flatpaks
  if [[ -n "${FLATPAKS}" ]]; then
    arch-chroot "${INSTALL_PATH}" flatpak install --noninteractive -y ${FLATPAKS[@]} || exit $?
  fi
  
  # systemd-boot
  arch-chroot "${INSTALL_PATH}" bootctl install || exit $? # TODO add entries
}

function main() {
  if [[ -n "${1}" ]]; then
    smb "${@:2}"
    exit $?
  fi
  
  if [[ -f '/tmp/startup_script' ]]; then
    ln -s '/tmp/startup_script' '/usr/local/bin/archinstall'
  fi
  
  load_config || exit $?
  
  setup_disks || exit $?
  install_chroot || exit $?
  
  if [[ "${REBOOT_AFTER_INSTALL}" == 'true' || "${REBOOT_AFTER_INSTALL}" == 1 ]]; then
    reboot
  fi
  
  return $?
}

main "$@"
exit $?
