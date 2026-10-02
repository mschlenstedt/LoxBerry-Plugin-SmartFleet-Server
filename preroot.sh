#!/bin/bash
# SmartFleet Server (LoxBerry-Plugin)
# Copyright (c) 2026 Michael Schlenstedt. Alle Rechte vorbehalten.
# Nutzung, Weitergabe und Veraenderung nur nach den Lizenzbedingungen,
# die diesem Programm beiliegen (LICENSE).

FREI_URL="${FM_LBSERVER_FREI_URL:-https://www.smartfleetmanager.de/free_licence/index.php}"

PDIR="$3"
TEMP="$6"

abbrechen() {
    echo "<FAIL> $1"
    exit 2
}

if [ -f "$LBPDATA/$PDIR/server/config.php" ]; then
    echo "<INFO> SmartFleet-Server ist schon eingerichtet - keine Voraussetzungen zu pruefen."
    exit 0
fi

FM_LBSERVER_NUR_FUNKTIONEN=1 . "$TEMP/bin/einrichten.sh"

if ! mail_lesen; then
    abbrechen "Der Mailversand des LoxBerry ist nicht eingerichtet. SmartFleet legt den ersten Zugang erst nach einer Testmail an. Bitte unter LoxBerry > Mailserver den Mailversand einschalten und das Plugin danach installieren."
fi
echo "<OK> Mailversand des LoxBerry: an $MAIL_AN"

ls "$LBHOMEDIR/system/apache2/mods-enabled/" 2>/dev/null | grep -q '^php[0-9.]*\.load$' \
    || abbrechen "Im Apache des LoxBerry ist kein PHP-Modul aktiv."
[ -f "$LBHOMEDIR/system/apache2/mods-available/ssl.load" ] \
    || abbrechen "Dem Apache des LoxBerry fehlt mod_ssl - ohne HTTPS laesst sich der Server nicht betreiben."
echo "<OK> Apache mit PHP und mod_ssl"

mkdir -p "$TEMP/data"
if [ -s "$TEMP/data/server-paket.zip" ]; then
    ZIP="$TEMP/data/server-paket.zip"
    echo "<WARNING> Testbau: das mitgelieferte Serverpaket wird nicht geprueft."
else
    ZIP="$TEMP/data/server-paket-geprueft.zip"
    FEHLER="$(php "$TEMP/bin/paket.php" "$ZIP" 2>&1 >/dev/null)"
    [ -s "$ZIP" ] || abbrechen "Serverpaket nicht geladen: $FEHLER"
    echo "<OK> Serverpaket geladen, Signatur und SHA-256 geprueft."
fi
unzip -l "$ZIP" 2>/dev/null | grep -q 'smartfleet-server/lib/setup-cli\.php$' \
    || abbrechen "Das Serverpaket ist zu alt fuer dieses Plugin (lib/setup-cli.php fehlt)."
chown -R loxberry:loxberry "$TEMP/data" 2>/dev/null

curl -s -o /dev/null --max-time 15 "$FREI_URL" \
    || abbrechen "Der Lizenzdienst fuer die Free-Lizenz ist nicht erreichbar ($FREI_URL). Bitte die Internetverbindung des LoxBerry pruefen."
echo "<OK> Lizenzdienst erreichbar"

exit 0

