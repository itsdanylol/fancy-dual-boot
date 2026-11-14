# fancy-dual-boot

A boot picker for GRUB that treats the menu as something you own.

One command lists the entries the way GRUB numbers them, one command changes
which one boots, and every write is backed up, validated with GRUB's own parser,
and reversible. If you run two systems on one machine, this is the part that
usually goes wrong at the worst possible moment.

```console
$ sudo bootpick list

  ID     ENTRY                                      KIND
  --     -----                                      ----
    0     Linux                                      entry
  ● 1     Windows                                    entry
    2     Advanced options                           submenu
    2>0   Linux (rescue shell)                       subentry

  ● = boots by default    timeout: 5s
```

## Why this exists

GRUB's default is a bare number in a text file:

```
set default=1
```

That number counts top-level `menuentry` and `submenu` stanzas in order. Add an
operating system, let os-prober find one, or reorder two lines, and the number
now points somewhere else. On a dual boot machine that means the machine quietly
starts booting the other OS, and the fix is "count the entries by hand in a
file on a FAT32 partition that is probably not even mounted".

Worse, the interesting entries are often the ones you need when everything else
is broken: the rescue shell, the snapshot, the old kernel. Those live inside a
submenu, and they are addressed as `1>0`, which nobody guesses.

`bootpick` reads the config, tells you the truth about the numbering, resolves
names as well as numbers, and refuses to leave the file in a state the GRUB
parser cannot read.

## Install

```sh
git clone https://github.com/itsdanylol/fancy-dual-boot
cd fancy-dual-boot
sudo ./install.sh
```

That copies `bootpick` to `/usr/local/bin`. Nothing else changes. No service, no
daemon, no config in your home directory.

Optional theme:

```sh
sudo ./install.sh --theme
```

## Use

```text
bootpick                     interactive picker
bootpick list                every entry, in GRUB's numbering
bootpick show                which entry is default, and the timeout
bootpick set 1               make entry 1 the default
bootpick set windows         same thing, by name (case-insensitive, substring ok)
bootpick set '2>0'           an entry inside a submenu
bootpick timeout 8           menu countdown
bootpick backups             what has been saved
bootpick restore             put the newest backup back
bootpick restore grub.cfg.bak-20261108-214800
```

Flags:

```text
--cfg PATH     use this grub.cfg instead of discovering one
--dry-run      print what would change, change nothing
--yes          skip the confirmation in the interactive picker
--backups N    how many backups to keep (default 5)
```

## What it actually touches

Exactly two lines, and only the ones you ask for:

```
set default=N
set timeout=N
```

Everything else in the file is left byte for byte, including your comments.
The file itself is written through a temp file in the same directory and moved
into place, so a full ESP or a pulled drive cannot leave a half-written boot
config.

## Safety, in order

1. **Discovery is read-only.** It mounts the ESP `ro` to look, unmounts, and only
   remounts `rw` when a write is actually happening.
2. **Backup before write.** Timestamped, next to the original, five kept.
3. **Validate before you get to reboot.** `grub-script-check` runs on the edited
   file. If it fails, or if the index you set does not resolve to a real entry,
   the backup is restored automatically and the command exits non-zero.
4. **Dry run is the default suggestion.** `--dry-run` is never needed for
   safety, but it is always available.
5. **Restore is one command.** `bootpick restore` puts the newest backup back
   and validates it too.

Nothing here runs `grub-mkconfig`, edits `/etc/default/grub`, touches EFI boot
order or rewrites your menu. If your distro regenerates the config on every
kernel update, the setting will be regenerated too, and that is a property of
`grub-mkconfig`, not of this tool. Read
[docs/how-grub-picks.md](docs/how-grub-picks.md) before you depend on it.

## The theme

`theme/theme.txt` is a text-only GRUB theme: dark backdrop, centered menu, a
countdown bar, one hint line. No images, no fonts to install, nothing
third-party. Distro icons are optional and yours to supply:

```text
theme/icons/arch.png
theme/icons/ubuntu.png
```

96x96 PNGs, named after the `--class` on each `menuentry`. GRUB falls back to
no icon for a class it cannot resolve, so a missing file is cosmetic.

## Where it came from

Written for one machine with two systems on it, one of which boots out of a
loop-mounted image file, and a hand-written config on the ESP that nobody wanted
to edit by hand at 2am again.

The tool ships no menu of its own. No default file, no entries, no theme forced
on you, no paths from someone else's disk: it reads whatever `grub.cfg` your
machine already has and edits two lines of it.

The machine's full story, including the config this was built against and the day
a Debian package deleted its dynamic loader:
https://github.com/itsdanylol/jetson-field-notes

## License

GNU General Public License v3.0 or later.
