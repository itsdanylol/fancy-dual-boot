# Case study: a Jetson Orin Nano Super

This is the machine the tool was written on, and the layout that made a generic
"edit `GRUB_DEFAULT`" answer useless.

## The layout

```text
/dev/nvme0n1p10   64M    vfat    EFI      the ESP, not mounted in the running system
/dev/nvme0n1p1    930G   ext4    APP      the outer filesystem
  /opt/omarchy/omarchy.img  512G  ext4     the actual root, loop-mounted at /
  /opt/omarchy/boot/         Image, initramfs-linux.img, tegra.dtb
```

Ubuntu is installed in the vendor-supported way and is the recovery system.
NVIDIA's `L4tLauncher.efi` owns its boot path and reads `extlinux.conf` from the
boot partition, which is why Ubuntu's kernel arguments are not GRUB's business.

Omarchy boots from a filesystem image, so GRUB has to load a kernel out of the
outer filesystem and tell it how to find the image.

## The config, annotated

The real file lives at `/boot/efi/EFI/grub/grub.cfg`.

```text
set default=1
set timeout=5
set timeout_style=menu

set omarchy_uuid=11111111-2222-4333-8444-555555555555
```

`default=1` is Omarchy. `timeout=5` is short on purpose: this board is used as a
desktop, not as a lab, and a five second pause is enough to catch it with an
arrow key.

The UUID identifies the outer filesystem, so GRUB can read the kernel and
initramfs, and it also reaches the kernel inside `omarchy.loop=`. It is used for
nothing else. `blkid -s UUID -o value /dev/nvme0n1p1` must match.

```text
menuentry "Ubuntu" --class ubuntu {
    chainloader /EFI/BOOT/BOOTAA64.efi
}
```

Hand off to NVIDIA's launcher, add no arguments, change nothing about how Ubuntu
boots. The vendor owns that path and GRUB only needs a menu line for it.

```text
menuentry "Omarchy" --class arch {
    if search --no-floppy --fs-uuid --set=omarchy_root "$omarchy_uuid"; then
        linux ($omarchy_root)/opt/omarchy/boot/Image \
            omarchy.loop=UUID=$omarchy_uuid:/opt/omarchy/omarchy.img \
            rw rootwait rootfstype=ext4 mminit_loglevel=4 \
            console=ttyTCU0,115200 console=tty0 firmware_class.path=/etc/firmware \
            fbcon=map:0 video=efifb:off efi=runtime pci=pcie_bus_perf \
            nvme.use_threaded_interrupts=1 quiet loglevel=3
        initrd ($omarchy_root)/opt/omarchy/boot/initramfs-linux.img
        devicetree ($omarchy_root)/opt/omarchy/boot/tegra.dtb
    else
        echo "omarchy: cannot resolve UUID $omarchy_uuid"
    fi
}
```

Four things in there are doing real work:

1. **No `root=`.** The initramfs hook mounts the root itself. Passing `root=`
   makes the initramfs try to mount the same filesystem first, and potentially
   fsck a 930 GB ext4 that is currently in use. The hook resolves the outer
   filesystem, the image and the inner root on its own.
2. **A private variable** (`omarchy_root`) instead of `$root`, so a failed
   Omarchy boot cannot leave the Ubuntu entry pointing at the wrong filesystem.
3. **`devicetree`**, because the board needs the tegra DTB and it is not in the
   image's `/boot`.
4. **`video=efifb:off`** plus the console arguments, because the firmware
   framebuffer fights the tegra display driver.

An `if` around the whole body means the failure mode is a printed message, not a
kernel panic with a UUID in it.

```text
submenu "Advanced options" {
    menuentry "Omarchy (rescue shell)" --class arch {
        ... same linux line plus omarchy.break=1 ...
    }
}
```

The rescue entry boots the same kernel and stops in the initramfs busybox shell
before `switch_root`, which is enough to inspect or repair the image from inside
the machine. It sits in a submenu so the timeout cannot land on it by accident,
and it is addressed as `2>0` in the numbering.

```text
if loadfont $prefix/fonts/unicode.pf2; then
    set gfxmode=auto
    terminal_output gfxterm
    set theme=$prefix/theme/theme.txt
    export theme
fi
```

Theme last, and behind the font check. If the font is missing, GRUB keeps the
plain text menu and still boots. A theme is never allowed to be load-bearing.

## What this tool replaces

Before, switching the default was a script that mounted the ESP by scanning
partitions for a vfat filesystem, printed the entries with `awk`, rewrote
`set default=` with `sed`, and hoped. It worked. It also had no validation, no
restore, and no way to address the rescue entry.

Now:

```sh
sudo bootpick list
sudo bootpick set omarchy
sudo bootpick --dry-run set '2>0'
```

It is the same edit, with a backup, GRUB's own parser as a gate, and a rollback
that takes one command.

## The rest of the machine

The kernel on this board is NVIDIA's out-of-tree L4T build, the GPU userspace is
outside the package manager, and one afternoon a Debian package replaced the
dynamic loader and made every new process die with `SIGBUS`. All of it, including
the postmortem: https://github.com/itsdanylol/handbuilt-jetson
