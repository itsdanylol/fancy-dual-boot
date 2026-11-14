#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# install.sh — put bootpick on the PATH, and optionally the theme on the ESP.

set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-/usr/local}
BINDIR="$PREFIX/bin"
WITH_THEME=0
CFG_OVERRIDE=""

for arg in "$@"; do
	case "$arg" in
		--theme) WITH_THEME=1 ;;
		--prefix=*) PREFIX=${arg#*=}; BINDIR="$PREFIX/bin" ;;
		--cfg=*) CFG_OVERRIDE=${arg#*=} ;;
		--help|-h)
			printf 'install.sh — put bootpick on the PATH, and optionally the theme on the ESP.\n'
			printf '\n  --theme          also install theme/theme.txt (and icons if present)\n'
			printf '  --cfg=PATH       which grub.cfg the theme should sit next to\n'
			exit 0
			;;
		*) printf 'unknown option: %s\n' "$arg" >&2; exit 2 ;;
	esac
done

[ "$(id -u)" -eq 0 ] || { printf 'needs root: sudo %s\n' "$0" >&2; exit 1; }

printf 'installing bootpick to %s\n' "$BINDIR"
install -d -m 755 "$BINDIR"
install -m 755 "$HERE/bootpick" "$BINDIR/bootpick"
printf '  ok\n'

if [ "$WITH_THEME" = "1" ]; then
	printf 'installing the theme\n'

	cfg=$CFG_OVERRIDE
	if [ -z "$cfg" ]; then
		for f in /boot/efi/EFI/*/grub.cfg /efi/EFI/*/grub.cfg /boot/grub/grub.cfg; do
			[ -f "$f" ] && cfg=$f && break
		done
	fi

	if [ -z "$cfg" ] || [ ! -f "$cfg" ]; then
		printf '  could not find a grub.cfg. Re-run with --cfg=PATH, or mount the ESP first.\n' >&2
		exit 1
	fi

	dir=$(dirname "$cfg")
	install -d -m 755 "$dir/theme"
	install -m 644 "$HERE/theme/theme.txt" "$dir/theme/theme.txt"
	printf '  theme.txt -> %s/theme/\n' "$dir"

	if [ -d "$HERE/theme/icons" ] && [ -n "$(ls -A "$HERE/theme/icons" 2>/dev/null)" ]; then
		install -d -m 755 "$dir/theme/icons"
		install -m 644 "$HERE"/theme/icons/* "$dir/theme/icons/"
		printf '  icons    -> %s/theme/icons/\n' "$dir"
	else
		printf '  no icons supplied; drop 96x96 PNGs in %s/theme/icons/ as <class>.png\n' "$dir"
	fi

	printf '\nadd this to your grub.cfg, inside the section that loads the font:\n\n'
	printf '    if loadfont $prefix/fonts/unicode.pf2; then\n'
	printf '        set gfxmode=auto\n'
	printf '        terminal_output gfxterm\n'
	printf '        set theme=$prefix/theme/theme.txt\n'
	printf '        export theme\n'
	printf '    fi\n\n'
	printf 'a missing font means no theme, a plain text menu, and a machine that still boots.\n'
fi

printf '\ntry:  bootpick list\n'
