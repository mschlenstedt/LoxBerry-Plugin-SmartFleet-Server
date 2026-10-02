#!/bin/bash
# SmartFleet Server (LoxBerry-Plugin)
# Copyright (c) 2026 Michael Schlenstedt. Alle Rechte vorbehalten.
# Nutzung, Weitergabe und Veraenderung nur nach den Lizenzbedingungen,
# die diesem Programm beiliegen (LICENSE).

PDIR="$3"
STASH="$LBPDATA/.$PDIR.upgrade"

zurueck() {
    [ -d "$1" ] || return 0
    mkdir -p "$2"
    for e in "$1"/* "$1"/.[!.]*; do
        [ -e "$e" ] || continue
        rm -rf "$2/$(basename "$e")"
        mv "$e" "$2/" || { echo "<FAIL> $e liess sich nicht zurueckspielen. Die Sicherung bleibt in $STASH."; exit 2; }
    done
    rmdir "$1" 2>/dev/null
}

[ -d "$STASH" ] || { echo "<INFO> Keine Sicherung aus preupgrade.sh - nichts zurueckzuspielen."; exit 0; }
zurueck "$STASH/data" "$LBPDATA/$PDIR"
zurueck "$STASH/config" "$LBPCONFIG/$PDIR"
rm -f "$LBPDATA/$PDIR/server-paket.zip"
rmdir "$STASH" 2>/dev/null || echo "<WARNING> $STASH nicht leer - bitte von Hand pruefen."
echo "<OK> Server, Zertifikat und Einstellungen zurueckgespielt."
exit 0

