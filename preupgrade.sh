#!/bin/bash
# SmartFleet Server (LoxBerry-Plugin)
# Copyright (c) 2026 Michael Schlenstedt. Alle Rechte vorbehalten.
# Nutzung, Weitergabe und Veraenderung nur nach den Lizenzbedingungen,
# die diesem Programm beiliegen (LICENSE).

PDIR="$3"
STASH="$LBPDATA/.$PDIR.upgrade"

if [ -e "$STASH" ]; then
    if [ -f "$LBPDATA/$PDIR/server/config.php" ]; then
        echo "<FAIL> $STASH stammt aus einem abgebrochenen Upgrade, und daneben laeuft ein eingerichteter Server. Bitte $STASH pruefen und von Hand entfernen, dann erneut installieren."
        exit 2
    fi
    echo "<WARNING> $STASH existiert schon (abgebrochenes Upgrade?) - wird weiterbenutzt."
    exit 0
fi
mkdir -p "$STASH" || { echo "<FAIL> $STASH nicht anlegbar."; exit 2; }
if [ -f "$LBPDATA/$PDIR/server/config.php" ]; then
    mv "$LBPDATA/$PDIR" "$STASH/data" \
        || { echo "<FAIL> Server nicht nach $STASH verschiebbar - Upgrade abgebrochen."; exit 2; }
else
    echo "<INFO> Server war nicht eingerichtet - es wird neu geladen."
fi
if [ -d "$LBPCONFIG/$PDIR" ]; then
    mv "$LBPCONFIG/$PDIR" "$STASH/config" \
        || { echo "<FAIL> Einstellungen nicht nach $STASH verschiebbar - Upgrade abgebrochen."; exit 2; }
fi
echo "<OK> Server, Zertifikat und Einstellungen beiseitegelegt."
exit 0

