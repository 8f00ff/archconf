#!/bin/bash

readonly PACKAGES=(
  # base
  amd-ucode
  base
  efibootmgr
  grub
  linux
  linux-firmware
  networkmanager
  # aconfmgr
  augeas
  diffutils
  expect
  gawk
  pacutils
)

readonly SERVICES=(
  NetworkManager
)

readonly ROOT_LABEL='arch-root'
readonly ROOT_PARTLABEL='Linux\x20x86-64\x20root\x20\x28\x2f\x29'

readonly EFI_LABEL='arch-efi'
readonly EFI_PARTLABEL='EFI\x20system\x20partition'

readonly HOME_LABEL='arch-home'
readonly HOME_PARTLABEL='Linux\x20\x2fhome'

readonly SWAP_LABEL='arch-swap'
readonly SWAP_PARTLABEL='Linux\x20swap'

readonly INSTALL_PATH='/mnt/archinstall'
readonly EFI_PATH='/boot/efi'
readonly HOME_PATH='/home'

readonly TARGET_HOSTNAME="$(host $(ip route get '1.2.3.4' | cut -d ' ' -f 7) | tail -1 | awk '{print substr($NF, 0, length($NF)-1)}')"

readonly LOCAL_IP="$(ip route get 1 | tr -s ' ' | cut -d ' ' -f7)"
readonly TARGET_HOSTNAMES="$(dig +short -x "${LOCAL_IP}" | sed 's/.$//')"
readonly TARGET_FQDN="$(printf "${TARGET_HOSTNAMES}" | awk '{print length, $0}' | sort -nr | head -1 | cut -d ' ' -f 2)"

function setup_disks() {
  # root
  ROOT_DEV="$(realpath -e "/dev/disk/by-label/${ROOT_LABEL}" 2>/dev/null || realpath -e "/dev/disk/by-partlabel/${ROOT_PARTLABEL}" 2>/dev/null)"
  [ ! -b "${ROOT_DEV}" ] && echo 'error: could not detect root partition' && exit 1
  wipefs -af "${ROOT_DEV}"
  mkfs -t 'ext4' "${ROOT_DEV}"
  e2label "${ROOT_DEV}" "${ROOT_LABEL}"
  mkdir -p "${INSTALL_PATH}"
  mount "${ROOT_DEV}" "${INSTALL_PATH}"
  
  # efi
  EFI_DEV="$(realpath -e "/dev/disk/by-label/${EFI_LABEL}" 2>/dev/null || realpath -e "/dev/disk/by-partlabel/${EFI_PARTLABEL}" 2>/dev/null)"
  [ ! -b "${EFI_DEV}" ] && echo 'error: could not detect efi partition' && exit 1
  wipefs -af "${EFI_DEV}"
  mkfs -t 'vfat' -F 32 "${EFI_DEV}"
  fatlabel "${EFI_DEV}" "${EFI_LABEL}" 2> /dev/null
  mkdir -p "${INSTALL_PATH}${EFI_PATH}"
  mount "${EFI_DEV}" "${INSTALL_PATH}${EFI_PATH}"
  
  # home
  HOME_DEV="$(realpath -e "/dev/disk/by-label/${HOME_LABEL}" 2>/dev/null || realpath -e "/dev/disk/by-partlabel/${HOME_PARTLABEL}" 2>/dev/null)"
  [ ! -b "${HOME_DEV}" ] && echo 'error: could not detect home partition' && exit 1
  [ "$(lsblk -no FSTYPE ${HOME_DEV})" -ne 'ext4' ] && echo 'error: home partition filesystem is not ext4' && exit 1
  e2label "${HOME_DEV}" "${HOME_LABEL}"
  mkdir -p "${INSTALL_PATH}${HOME_PATH}"
  mount "${HOME_DEV}" "${INSTALL_PATH}${HOME_PATH}"
  
  # swap
  SWAP_DEV="$(realpath -e "/dev/disk/by-label/${SWAP_LABEL}" 2>/dev/null || realpath -e "/dev/disk/by-partlabel/${SWAP_PARTLABEL}" 2>/dev/null)"
  [ ! -b "${SWAP_DEV}" ] && echo 'error: could not detect swap partition' && exit 1
  wipefs -af "${SWAP_DEV}"
  mkswap "${SWAP_DEV}"
  swaplabel -L "${SWAP_LABEL}" "${SWAP_DEV}"
  swapon "${SWAP_DEV}"
}

function install_chroot() {
  # packages
  pacstrap -K "${INSTALL_PATH}" ${PACKAGES[@]}
  
  # fstab
  genfstab -U "${INSTALL_PATH}" >> "${INSTALL_PATH}/etc/fstab"
  
  #hostname
  echo "${TARGET_HOSTNAME}" > "${INSTALL_PATH}/etc/hostname"
  
  # systemd services
  arch-chroot "${INSTALL_PATH}" systemctl enable ${SERVICES[@]}
  
  # initramfs
  arch-chroot "${INSTALL_PATH}" mkinitcpio -P
  
  # grub
  arch-chroot "${INSTALL_PATH}" grub-install --target='x86_64-efi' --efi-directory='/boot/efi' --bootloader-id='Arch Linux'
  arch-chroot "${INSTALL_PATH}" grub-mkconfig -o '/boot/grub/grub.cfg'
}

function aconfmgr() {
  # install
  pacman -Sy --needed --noconfirm unzip
  cd "$(mktemp -d)"
  curl -fLO 'https://github.com/CyberShadow/aconfmgr/archive/refs/heads/master.zip'
  unzip 'master.zip'
  mv 'aconfmgr-master' '/opt/aconfmgr'
}

function main() {
  ln -s '/tmp/startup_script' '/usr/local/bin/archinstall'
  
  echo "$0: waiting for systemd"
  systemctl is-system-running --wait &>/dev/null
  
  setup_disks
  install_chroot
  aconfmgr
}

main "$@" && reboot || exit $?
