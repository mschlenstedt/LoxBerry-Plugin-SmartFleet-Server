<?php

declare(strict_types=1);

const INDEX_URL = 'https://smartfleetmanager.de/downloads/server/index.txt';

$lib = is_dir(__DIR__ . '/fmlib') ? __DIR__ . '/fmlib' : __DIR__ . '/../../server/lib';
foreach (array('B64', 'Ed', 'Umschlag', 'Version', 'ReleaseKey', 'Update/Manifest') as $k) {
    require_once $lib . '/' . $k . '.php';
}

function stirb(string $grund): void
{
    fwrite(STDERR, $grund . "\n");
    exit(1);
}

function holen(string $url, bool $dateiErlaubt, int $max): ?string
{
    if (preg_match('#^https://[^/]+/#i', $url) !== 1
        && !($dateiErlaubt && strpos($url, 'file://') === 0)) {
        return null;
    }
    if (strpos($url, 'file://') === 0) {
        $d = @file_get_contents(substr($url, 7), false, null, 0, $max + 1);
        return ($d === false || strlen($d) > $max) ? null : $d;
    }
    if (function_exists('curl_init')) {
        $c = curl_init($url);
        curl_setopt_array($c, array(
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT        => 120,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_PROTOCOLS      => CURLPROTO_HTTPS,
            CURLOPT_USERAGENT      => 'SmartFleet-LoxBerry-Server-Plugin',
        ));
        $d = curl_exec($c);
        $status = (int)curl_getinfo($c, CURLINFO_RESPONSE_CODE);
        curl_close($c);
        return (is_string($d) && $status === 200 && strlen($d) <= $max) ? $d : null;
    }
    $ctx = stream_context_create(array(
        'http' => array('timeout' => 120, 'follow_location' => 0, 'user_agent' => 'SmartFleet-LoxBerry-Server-Plugin'),
        'ssl'  => array('verify_peer' => true, 'verify_peer_name' => true),
    ));
    $d = @file_get_contents($url, false, $ctx, 0, $max + 1);
    return ($d === false || strlen($d) > $max) ? null : $d;
}

if (!isset($argv[1]) || $argv[1] === '') {
    fwrite(STDERR, "Aufruf: php paket.php <ziel.zip> [index-url]\n");
    exit(2);
}
$ziel = $argv[1];
$indexUrl = isset($argv[2]) && $argv[2] !== '' ? $argv[2] : INDEX_URL;

$testPub = getenv('FM_PAKET_PUB');
$test = $testPub !== false && $testPub !== '';
$pub = $test ? FM\B64::decode($testPub) : FM\ReleaseKey::pub();
if ($pub === null || strlen($pub) !== 32) {
    stirb('Kein Release-Schluessel - das Paket laesst sich nicht pruefen.');
}

$index = holen($indexUrl, $test, 2097152);
if ($index === null) {
    stirb("Versionsliste nicht abrufbar: $indexUrl");
}
$liste = FM\Update\Manifest::versionsliste($index, $pub);
if ($liste === null) {
    stirb('Versionsliste ungueltig: Signatur oder Aufbau stimmt nicht.');
}

$wahl = null;
for ($i = count($liste) - 1; $i >= 0; $i--) {
    if (version_compare(PHP_VERSION, $liste[$i]['php_min'], '>=')) {
        $wahl = $liste[$i];
        break;
    }
}
if ($wahl === null) {
    stirb('Keine Serverversion passt zu PHP ' . PHP_VERSION . '.');
}

$basis = substr($indexUrl, 0, (int)strrpos($indexUrl, '/') + 1);
$paket = holen($basis . $wahl['datei'], $test, FM\Update\Manifest::MAX_PAKET);
if ($paket === null) {
    stirb('Paket nicht abrufbar: ' . $basis . $wahl['datei']);
}
if (strlen($paket) !== $wahl['groesse'] || !hash_equals($wahl['sha256'], hash('sha256', $paket))) {
    stirb('Paket ' . $wahl['datei'] . ' passt nicht zur Versionsliste (Groesse oder SHA-256).');
}

$tmp = $ziel . '.tmp';
if (@file_put_contents($tmp, $paket) !== strlen($paket) || !@rename($tmp, $ziel)) {
    @unlink($tmp);
    stirb("Paket nicht speicherbar: $ziel");
}
echo $wahl['v'] . "\n";
exit(0);
