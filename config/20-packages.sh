# 20-packages.sh

# archinstall

AddPackage amd-ucode      # Microcode update image for AMD CPUs
AddPackage base           # Minimal package set to define a basic Arch Linux installation
AddPackage efibootmgr     # Linux user-space application to modify the EFI Boot Manager
AddPackage grub           # GNU GRand Unified Bootloader (2)
AddPackage linux          # The Linux kernel and modules
AddPackage linux-firmware # Firmware files for Linux
AddPackage networkmanager # Network connection manager and user applications

# aconfmgr

AddPackage augeas         # A configuration editing tool that parses config files and transforms them into a tree, optional required by aconfmgr
AddPackage diffutils      # Utility programs used for creating patch files, required by aconfmgr
AddPackage expect         # A tool for automating interactive applications, required by aconfmgr
AddPackage gawk           # GNU version of awk, required by aconfmgr
AddPackage pacutils       # Helper tools for libalpm, required by aconfmgr

# extra

AddPackage less           # A terminal based program for viewing text files
AddPackage nano           # Pico editor clone with enhancements
AddPackage neofetch       # A CLI system information tool written in BASH that supports displaying images
AddPackage nfs-utils      # Support programs for Network File Systems
AddPackage unzip          # For extracting and viewing files in .zip archives
AddPackage vim            # Vi Improved, a highly configurable, improved version of the vi text editor
