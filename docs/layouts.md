# Dual boot layouts

Four arrangements that show up in practice, and what each one costs you.

## A. One ESP, two distros, one config owner

The common case. Two roots on one drive, one EFI partition, and one GRUB install
that lists both.

```text
/dev/nvme0n1p1   vfat   ESP     /boot/efi
/dev/nvme0n1p2   ext4   distroA /
/dev/nvme0n1p3   ext4   distroB /
```

Distro A's config owns the menu and adds distro B via os-prober or by hand.
Distro B's config either does not exist or is not reached, because firmware
boots the entry that points at A.

Cost: the default is a number in A's config, and os-prober can reorder it.

## B. Two configs, two firmware entries

Each distro keeps its own `grubaa64.efi` / `grubx64.efi` and its own config on
the ESP. Firmware boot order decides which one runs.

```text
/boot/efi/EFI/ubuntu/grub.cfg
/boot/efi/EFI/arch/grub.cfg
```

Cost: two menus, two defaults, and `efibootmgr` decides which menu you see.
Cleaner isolation, more places to be wrong. `bootpick` only edits one config,
which is honest rather than clever: pass `--cfg` and it edits the other.

## C. Chainloading the vendor launcher

Some vendors ship their own bootloader that owns the machine's supported boot
path. Windows has `bootmgfw.efi`; NVIDIA's Jetson has `L4tLauncher.efi`, which
reads `extlinux.conf` from the boot partition and owns the kernel command line.

In this layout GRUB is a menu that hands control over:

```text
menuentry "Windows" {
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
```

Cost: the chainloaded entry appears as one line, and everything it can do is
invisible to GRUB. You cannot change that system's kernel arguments from here.

## D. A root that is a file

Rare, and the reason this tool exists in the form it does. The running system is
not a partition, it is a filesystem image inside a partition:

```text
/dev/nvme0n1p1            ext4   930G   the outer filesystem
  /opt/omarchy/omarchy.img  ext4   512G   the actual root, loop-mounted
```

GRUB has to read the kernel and initramfs out of the outer filesystem and hand
the kernel enough information to find and loop-mount the image itself. That means
the kernel command line carries no `root=`, because the initramfs hook mounts the
root on its own, and a `root=` would race it and possibly fsck the outer
filesystem while it is in use.

Cost: one line of GRUB config is doing the work of a whole initramfs hook, and an
error there is a kernel panic with a UUID in it. The Jetson case study has the
real config: [jetson-case-study.md](jetson-case-study.md).

## Picking a layout on purpose

- Need the other OS to stay independently recoverable? Layout B, two configs.
- Want one menu and do not care whose? Layout A, and pin the default by name.
- Vendor owns the boot path? Chainload it and keep GRUB as the chooser, layout C.
- Root on an image? Layout D, and never pass `root=` on the command line.

In all four, the thing that saves you is the same: a second entry that you know
works, and a backup of the config that you can edit from any operating system,
because FAT32 is readable from all of them.
