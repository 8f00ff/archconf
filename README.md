# aconfmgr config

## archinstall

### Requirements

The archinstall script required the disks to be partitioned and labeled manually beforehand to be able to correctly detect them.

The layout is as follows:

- efi partition:
  - filesystem: `fat32`
  - label: `arch-efi`
  - partition type: `EFI system partition`
  - mountpoint: `/`
- root partition:
  - filesystem: `ext4`
  - label: `arch-root`
  - partition type: `Linux x86-64 root (/)`
  - mountpoint: `/`
- swap partition:
  - filesystem: `swap`
  - label: `arch-swap`
  - partition type: `Linux swap`
  - mountpoint: **n/a**
- home partition:
  - filesystem: `ext4`
  - label: `arch-home`
  - partition type: `Linux /home`
  - mountpoint: `/home`

The script will automatically format (except home) and mount the partitions.

### Usage

To automate Arch Linux installation, make the script available over http and add it to archiso kernel parameters in grub.

For example:

```
  linuxefi [...] script=http://192.168.0.1:8080/archinstall.sh
```
