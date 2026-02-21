# BFS Build Dependencies

## Required packages for building BFS ISO
```bash
# Core build tools
sudo apt install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    qemu-system-x86 \
    isolinux \
    syslinux-common

# GRUB tools
sudo apt install -y \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin

# ISO creation tools
sudo apt install -y \
    mtools \
    genisoimage
```

## Why each package is needed

- `debootstrap`: Creates Debian base system
- `squashfs-tools`: Compresses filesystem
- `xorriso`: Creates ISO files
- `qemu-system-x86`: Virtual machine testing
- `grub-*`: Bootloader components
- `mtools`: MS-DOS filesystem tools (for ISO boot sectors)
- `genisoimage`: Additional ISO utilities
