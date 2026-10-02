#!/bin/bash
# SmartFleet Server (LoxBerry-Plugin)
# Copyright (c) 2026 Michael Schlenstedt. Alle Rechte vorbehalten.
# Nutzung, Weitergabe und Veraenderung nur nach den Lizenzbedingungen,
# die diesem Programm beiliegen (LICENSE).

ERSTER_PORT=9000

meld() {
    printf '<%s> %s\n' "$1" "$2"
    if [ -n "${LOGDATEI:-}" ]; then
        printf '%s <%s> %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$LOGDATEI"
    fi
}

stirb() {
    meld FAIL "$1"
    exit 2
}

mail_lesen() {
    MAIL_AN=""
    MAIL_VON=""
    local f="$LBHOMEDIR/config/system/mail.json" zeile
    [ -r "$f" ] || return 1
    zeile="$(perl -MJSON::PP -e '
        local $/; open my $h, "<", $ARGV[0] or exit 1;
        my $d = eval { JSON::PP->new->decode(<$h>) } or exit 1;
        my $s = $d->{SMTP} || {};
        my $an = defined $s->{EMAIL} ? $s->{EMAIL} : "";
        my $von = (defined $s->{EMAIL_FROM} && $s->{EMAIL_FROM} ne "") ? $s->{EMAIL_FROM} : $an;
        my $aktiv = ($s->{ACTIVATE_MAIL} && $s->{ACTIVATE_MAIL} ne "0" && $s->{ACTIVATE_MAIL} ne "false") ? 1 : 0;
        print join("\t", $aktiv, $an, $von);
    ' "$f")" || return 1
    local aktiv
    IFS="$(printf '\t')" read -r aktiv MAIL_AN MAIL_VON <<EOF
$zeile
EOF
    [ "$aktiv" = 1 ] && [ -n "$MAIL_AN" ]
}

freier_port() {
    local p="$1"
    while [ "$p" -lt 65535 ]; do
        if ! ss -ltnH "sport = :$p" | grep -q .; then
            echo "$p"
            return 0
        fi
        p=$((p + 1))
    done
    return 1
}

kennung_erzeugen() {
    local h
    h="$(printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9-' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40)"
    [ -n "$h" ] || h="loxberry"
    printf 'lb-%s-%s\n' "$h" "$(openssl rand -hex 3)"
}

konfig_lesen() {
    [ -r "$1" ] || return 0
    perl -MJSON::PP -e '
        local $/; open my $h, "<", $ARGV[0] or exit 0;
        my $d = eval { JSON::PP->new->decode(<$h>) } or exit 0;
        print $d->{$ARGV[1]} if defined $d->{$ARGV[1]};
    ' "$1" "$2"
}

konfig_schreiben() {
    perl -MJSON::PP -e '
        my ($f, $port, $k, $ip) = @ARGV;
        open my $h, ">", "$f.tmp" or die "$f.tmp: $!\n";
        print $h JSON::PP->new->canonical->pretty->encode({ port => $port + 0, kennung => $k, ip => $ip });
        close $h or die "$f.tmp: $!\n";
        rename "$f.tmp", $f or die "$f: $!\n";
    ' "$1" "$2" "$3" "$4"
}

vhost_text() {
    cat <<CONF
Listen $1

<VirtualHost *:$1>
    ServerSignature Off
    DocumentRoot $2

    SSLEngine on
    SSLCertificateFile $3/server.crt
    SSLCertificateKeyFile $3/server.key

    <Directory $2>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php
    </Directory>

    <Files "setup.php">
        Require all denied
    </Files>

    ErrorLog \${APACHE_LOG_DIR}/$4-error.log
    CustomLog \${APACHE_LOG_DIR}/$4-access.log combined
</VirtualHost>
CONF
}

if [ "${FM_LBSERVER_NUR_FUNKTIONEN:-}" = 1 ]; then
    return 0 2>/dev/null || exit 0
fi

set -u
PDIR="${1:-}"
[ -n "$PDIR" ] || { echo "Aufruf: einrichten.sh <pluginordner>" >&2; exit 2; }
[ "$(id -u)" = 0 ] || { echo "einrichten.sh muss als root laufen" >&2; exit 2; }

if [ -z "${LBHOMEDIR:-}" ] && [ -r /etc/environment ]; then
    set -a
    . /etc/environment
    set +a
fi
[ -n "${LBHOMEDIR:-}" ] || stirb "LBHOMEDIR ist nicht gesetzt - kein LoxBerry?"

PCFG="$LBPCONFIG/$PDIR"
PDATA="$LBPDATA/$PDIR"
SRV="$PDATA/server"
KONFIG="$PCFG/server.json"
SSL="$PCFG/ssl"
SITE_NAME="050-$PDIR"
SITE="$LBHOMEDIR/system/apache2/sites-available/$SITE_NAME.conf"
DB="$PDIR"
mkdir -p "$LBPLOG/$PDIR" && chown loxberry:loxberry "$LBPLOG/$PDIR"
LOGDATEI="$LBPLOG/$PDIR/einrichten.log"
: > "$LOGDATEI"
chown loxberry:loxberry "$LOGDATEI"

[ -f "$SRV/lib/setup-cli.php" ] || stirb "Serverdateien fehlen unter $SRV - die Installation des Pakets ist gescheitert, siehe Log oben."
EINGERICHTET=0
[ -f "$SRV/config.php" ] && EINGERICHTET=1

if [ "$EINGERICHTET" = 0 ]; then
    if ! mail_lesen; then
        stirb "Der Mailversand des LoxBerry ist nicht eingerichtet. SmartFleet legt den ersten Zugang erst nach einer Testmail an. Bitte unter LoxBerry > Mailserver den Mailversand einschalten und das Plugin danach erneut installieren."
    fi
    meld OK "Mailversand des LoxBerry: an $MAIL_AN"
fi

PHPVER="$(ls "$LBHOMEDIR/system/apache2/mods-enabled/" 2>/dev/null | sed -n 's/^php\([0-9][0-9.]*\)\.load$/\1/p' | head -n1)"
[ -n "$PHPVER" ] || stirb "Keine PHP-Version im Apache des LoxBerry gefunden."
PHPBIN="$(command -v "php$PHPVER" || command -v php)"
if ! "$PHPBIN" -m 2>/dev/null | grep -qi '^pdo_mysql$'; then
    meld INFO "Installiere php$PHPVER-mysql ..."
    DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none \
        apt-get install -y --no-install-recommends "php$PHPVER-mysql" >> "$LOGDATEI" 2>&1 \
        || stirb "php$PHPVER-mysql liess sich nicht installieren (Details: $LOGDATEI)."
fi
meld OK "PHP $PHPVER mit pdo_mysql"

command -v mariadb >/dev/null 2>&1 || stirb "MariaDB ist nicht installiert - die Paketinstallation des Plugins ist gescheitert, siehe Log oben."
systemctl is-active --quiet mariadb || systemctl start mariadb >> "$LOGDATEI" 2>&1
mariadb -e 'SELECT 1' >/dev/null 2>&1 || stirb "MariaDB antwortet nicht."
meld OK "MariaDB laeuft"

DBPASS=""
if [ "$EINGERICHTET" = 0 ]; then
    DBPASS="$(openssl rand -hex 24)"
    mariadb <<SQL >> "$LOGDATEI" 2>&1 || stirb "Datenbank $DB liess sich nicht anlegen (Details: $LOGDATEI)."
CREATE DATABASE IF NOT EXISTS \`$DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB'@'localhost' IDENTIFIED BY '$DBPASS';
ALTER USER '$DB'@'localhost' IDENTIFIED BY '$DBPASS';
GRANT ALL PRIVILEGES ON \`$DB\`.* TO '$DB'@'localhost';
FLUSH PRIVILEGES;
SQL
    meld OK "Datenbank $DB und Benutzer angelegt"
else
    meld INFO "Server ist schon eingerichtet - Datenbank bleibt unveraendert"
fi

mkdir -p "$PCFG" && chown loxberry:loxberry "$PCFG"
PORT="$(konfig_lesen "$KONFIG" port)"
KENNUNG="$(konfig_lesen "$KONFIG" kennung)"
if [ -z "$PORT" ]; then
    PORT="$(freier_port "$ERSTER_PORT")" || stirb "Kein freier Port ab $ERSTER_PORT."
fi
[ -n "$KENNUNG" ] || KENNUNG="$(kennung_erzeugen "$(hostname)")"
IP="$(perl -MLoxBerry::System -e 'print LoxBerry::System::get_localip()' 2>/dev/null)"
[ -n "$IP" ] || IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -n "$IP" ] || stirb "Die IP-Adresse des LoxBerry liess sich nicht ermitteln."
konfig_schreiben "$KONFIG" "$PORT" "$KENNUNG" "$IP" || stirb "$KONFIG nicht schreibbar."
chown loxberry:loxberry "$KONFIG"
URL="https://$IP:$PORT"
meld OK "Adresse: $URL"

if [ ! -s "$SSL/server.crt" ] || [ ! -s "$SSL/server.key" ]; then
    mkdir -p "$SSL"
    chmod 700 "$SSL"
    H="$(hostname)"
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -sha256 \
        -subj "/CN=$H/O=SmartFleet Test" \
        -addext "subjectAltName=IP:$IP,DNS:$H,DNS:$H.local" \
        -keyout "$SSL/server.key" -out "$SSL/server.crt" >> "$LOGDATEI" 2>&1 \
        || stirb "Zertifikat liess sich nicht erzeugen (Details: $LOGDATEI)."
    chmod 600 "$SSL/server.key"
    meld OK "Selbst signiertes Zertifikat erzeugt (10 Jahre)"
else
    meld INFO "Vorhandenes Zertifikat wird weiter benutzt"
fi
chown -R loxberry:loxberry "$SSL"

vhost_text "$PORT" "$SRV" "$SSL" "$PDIR" > "$SITE.tmp"
mv "$SITE.tmp" "$SITE"
a2ensite -q "$SITE_NAME" >> "$LOGDATEI" 2>&1
if ! apache2ctl configtest >> "$LOGDATEI" 2>&1; then
    a2dissite -q "$SITE_NAME" >> "$LOGDATEI" 2>&1
    rm -f "$SITE"
    stirb "Die Apache-Konfiguration ist fehlerhaft - VirtualHost wieder entfernt (Details: $LOGDATEI)."
fi
systemctl reload apache2 >> "$LOGDATEI" 2>&1 || stirb "Apache liess sich nicht neu laden (Details: $LOGDATEI)."
meld OK "VirtualHost $SITE_NAME auf Port $PORT aktiv"

if [ "$EINGERICHTET" = 0 ]; then
    EIN="$PCFG/setup-eingaben.json"
    ( umask 077
      perl -MJSON::PP -e '
        my ($f, $db, $pass, $url, $k, $an, $von) = @ARGV;
        open my $h, ">", $f or die "$f: $!\n";
        print $h JSON::PP->new->encode({
            db_host => "localhost", db_port => "", db_name => $db, db_user => $db, db_pass => $pass,
            table_prefix => "smartfleet_", admin_mail => $an, base_url => $url,
            lizenz_art => "frei", frei_kennung => $k, frei_name => "LoxBerry Test",
            mail => { from => $von, weg => "sendmail" },
        });
        close $h or die "$f: $!\n";
      ' "$EIN" "$DB" "$DBPASS" "$URL" "$KENNUNG" "$MAIL_AN" "$MAIL_VON" ) || stirb "Eingabedatei nicht schreibbar."
    chown loxberry:loxberry "$EIN"
    AUSGABE="$(su -s /bin/sh loxberry -c "'$PHPBIN' '$SRV/lib/setup-cli.php' '$EIN'" 2>&1)"
    RC=$?
    rm -f "$EIN"
    printf '%s\n' "$AUSGABE" >> "$LOGDATEI"
    case "$RC" in
        0) meld OK "SmartFleet-Server eingerichtet (Free-Lizenz, Kennung $KENNUNG)" ;;
        3) meld INFO "SmartFleet-Server war schon eingerichtet" ;;
        *)
            konfig_schreiben "$KONFIG" "$PORT" "" "$IP"
            stirb "Einrichtung des Servers gescheitert: $(printf '%s' "$AUSGABE" | tr '\n' ' ')" ;;
    esac
fi

for pfad in config.php lib/VERSION fmdata/; do
    code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "https://127.0.0.1:$PORT/$pfad")"
    if [ "$code" = 403 ] || [ "$code" = 404 ]; then
        meld OK "/$pfad ist gesperrt ($code)"
    else
        meld WARNING "/$pfad antwortet mit $code statt 403 - die .htaccess-Sperre greift nicht"
    fi
done

meld OK "SmartFleet-Server erreichbar unter $URL/"
exit 0

