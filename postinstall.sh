#!/bin/bash
# SmartFleet Server (LoxBerry-Plugin)
# Copyright (c) 2026 Michael Schlenstedt. Alle Rechte vorbehalten.
# Nutzung, Weitergabe und Veraenderung nur nach den Lizenzbedingungen,
# die diesem Programm beiliegen (LICENSE).

PDIR="$3"
PDATA="$LBPDATA/$PDIR"
STASH="$LBPDATA/.$PDIR.upgrade"
PHP="$(command -v php)"

if [ -d "$STASH/data/server" ]; then
    echo "<INFO> Upgrade: der eingerichtete Server wird in postupgrade.sh zurueckgespielt."
    exit 0
fi

ZIP="$PDATA/server-paket.zip"
if [ -s "$PDATA/server-paket-geprueft.zip" ]; then
    ZIP="$PDATA/server-paket-geprueft.zip"
    echo "<OK> Benutze das in preroot geprueft geladene Serverpaket."
elif [ -s "$ZIP" ]; then
    echo "<WARNING> Testbau: benutze das mitgelieferte, ungepruefte Serverpaket."
else
    ZIP="$PDATA/paket.zip"
    VERSION="$("$PHP" "$LBPBIN/$PDIR/paket.php" "$ZIP" 2>/tmp/"$PDIR"-paket.err)"
    if [ $? -ne 0 ]; then
        echo "<FAIL> Serverpaket nicht geladen: $(cat /tmp/"$PDIR"-paket.err)"
        rm -f /tmp/"$PDIR"-paket.err
        exit 2
    fi
    rm -f /tmp/"$PDIR"-paket.err
    echo "<OK> Serverpaket $VERSION geladen und geprueft."
fi

ENTPACKT="$PDATA/entpackt.$$"
rm -rf "$ENTPACKT"
if ! unzip -q "$ZIP" -d "$ENTPACKT"; then
    rm -rf "$ENTPACKT"
    echo "<FAIL> Serverpaket liess sich nicht entpacken."
    exit 2
fi
rm -f "$ZIP"
rm -rf "$PDATA/server"
mv "$ENTPACKT/smartfleet-server" "$PDATA/server"
rm -rf "$ENTPACKT"

if [ ! -f "$PDATA/server/lib/setup-cli.php" ]; then
    echo "<FAIL> Das Serverpaket ist zu alt fuer dieses Plugin (lib/setup-cli.php fehlt)."
    exit 2
fi
echo "<OK> Serverdateien unter $PDATA/server"
exit 0

