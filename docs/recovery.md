# Recovery

The one thing a boot picker must never do is leave you with a machine that has no
menu. Here is what to do when the menu is wrong, and why each escape hatch works.

## The menu appears but the entry hangs

Press `Esc` while it is hanging, or power cycle and let the menu appear again.
Move to a different entry with the arrow keys. Nothing has been written at this
point; the machine simply booted the wrong thing.

If the menu has a timeout and you keep missing it, hold `Shift` or tap `Esc`
during firmware splash. On some machines it is any key.

## Nothing boots, but the menu appears

At the menu, press `e` on any entry to edit it for this boot only. Delete
whatever was added, or change a UUID back, then `Ctrl-X` or `F10` to boot.
The edit is not saved.

Press `c` for the GRUB console if you need to look around:

```text
grub> ls
grub> ls (hd0,gpt1)/
grub> cat (hd0,gpt1)/EFI/grub/grub.cfg
```

`bootpick` never changes the kernel command line, so this is for the case where
something else did.

## The menu itself is gone or broken

The config is on FAT32. Any operating system can edit it: Linux, macOS, Windows,
a live USB, or even the firmware's own shell if it has one. That is the whole
reason this layout is recoverable.

From any Linux with the ESP mounted:

```sh
sudo bootpick --cfg /boot/efi/EFI/grub/grub.cfg restore
```

That puts back the newest backup. If the tool is not on that machine, the backup
is a copy of the same file:

```sh
ls /boot/efi/EFI/grub/
cp /boot/efi/EFI/grub/grub.cfg.bak-20261108-214800 /boot/efi/EFI/grub/grub.cfg
```

From Windows, the ESP is `\\?\Volume{...}\` and needs `mountvol` to be assigned a
letter. It is possible, and it is why keeping the backup next to the original
matters.

## GRUB itself will not start

Then the problem is not the config, it is the firmware entry or the `.efi` file.
Look at boot order:

```sh
efibootmgr -v
sudo efibootmgr -o 0001,0002
```

Every machine has a firmware menu (usually `F2`, `F12`, `Del`, or `Esc` at
power-on) where the boot device and the `.efi` path can be chosen. If a live USB
boots, the ESP is reachable and nothing is lost.

## Testing a change without risking a boot

The trick worth using every time:

```sh
sudo bootpick set 'My New Entry'
sudo grub-reboot 'The Entry That Works'
sudo reboot
```

`grub-reboot` sets an entry for exactly one boot. When that boot ends, GRUB falls
back to whatever `set default=` says. So a change only has to survive one
successful boot to be adopted, and a failure returns you to the known-good entry
with nobody at the keyboard.

For a new kernel, the same idea applies one level up: install it as a new menu
entry next to the old one, make the new one a one-shot, and keep the old entry
untouched until the new one has booted twice.

## What not to do

- Do not `rm` files on the ESP to "clean up". There is no undo, and it is FAT32.
- Do not run `grub-install` hoping it fixes a config problem. It rewrites the
  bootloader, not the menu, and on a machine with a vendor boot path it can
  remove the entry you actually need.
- Do not edit the config with an editor that converts line endings. GRUB reads
  LF; a CRLF config from a Windows editor is a config that fails to parse.
