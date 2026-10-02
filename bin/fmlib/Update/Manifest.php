<?php

declare(strict_types=1);

namespace FM\Update;

use FM\Umschlag;
use FM\Version;

final class Manifest
{
    const PFAD = 'lib/manifest.txt';
    const MAX_PAKET = 67108864;

    public static function manifest(string $text, ?string $pub32): ?array
    {
        if ($pub32 === null) {
            return null;
        }
        $m = Umschlag::oeffnen($text, $pub32);
        if ($m === null || !self::kopfOk($m)
            || !isset($m['stufen'], $m['dateien']) || !is_array($m['stufen']) || !is_array($m['dateien'])
            || count($m['dateien']) === 0) {
            return null;
        }
        foreach ($m['stufen'] as $s) {
            if (!is_string($s) || !Version::gueltig($s)) {
                return null;
            }
        }
        foreach ($m['dateien'] as $p => $h) {
            if (!self::pfadSicher((string)$p) || !is_string($h) || preg_match('/^[0-9a-f]{64}$/', $h) !== 1) {
                return null;
            }
        }
        return isset($m['dateien']['lib/VERSION']) ? $m : null;
    }

    public static function versionsliste(string $text, ?string $pub32): ?array
    {
        if ($pub32 === null) {
            return null;
        }
        $d = Umschlag::oeffnen($text, $pub32);
        if ($d === null || !isset($d['versionen']) || !is_array($d['versionen'])) {
            return null;
        }
        $out = array();
        foreach ($d['versionen'] as $e) {
            if (!is_array($e) || !self::kopfOk($e)
                || !isset($e['datei'], $e['groesse'], $e['sha256'])
                || $e['datei'] !== 'smartfleet-server-' . $e['v'] . '.zip'
                || !is_int($e['groesse']) || $e['groesse'] <= 0 || $e['groesse'] > self::MAX_PAKET
                || !is_string($e['sha256']) || preg_match('/^[0-9a-f]{64}$/', $e['sha256']) !== 1) {
                return null;
            }
            $h = (isset($e['hinweis']) && is_array($e['hinweis'])) ? $e['hinweis'] : array();
            $out[] = array(
                'v' => $e['v'], 'datum' => $e['datum'], 'datei' => $e['datei'], 'groesse' => $e['groesse'],
                'sha256' => $e['sha256'], 'php_min' => $e['php_min'], 'stufe' => $e['stufe'],
                'hinweis' => array(
                    'de' => (isset($h['de']) && is_string($h['de'])) ? $h['de'] : '',
                    'en' => (isset($h['en']) && is_string($h['en'])) ? $h['en'] : '',
                ),
            );
        }
        usort($out, function (array $a, array $b): int {
            return Version::vergleiche($a['v'], $b['v']);
        });
        return $out;
    }

    public static function pfadSicher(string $p): bool
    {
        if ($p === '' || strlen($p) > 255 || $p[0] === '/' || preg_match('#^[A-Za-z0-9._/@+-]+$#', $p) !== 1) {
            return false;
        }
        foreach (explode('/', $p) as $teil) {
            if ($teil === '' || $teil === '.' || $teil === '..') {
                return false;
            }
        }
        if ($p === 'config.php' || $p === self::PFAD || $p === 'lib/wartung.flag') {
            return false;
        }
        return strpos($p, 'fmdata/') !== 0;
    }

    private static function kopfOk(array $m): bool
    {
        return isset($m['v'], $m['datum'], $m['php_min'], $m['stufe'])
            && is_string($m['v']) && Version::gueltig($m['v'])
            && is_int($m['datum']) && $m['datum'] > 0
            && is_string($m['php_min']) && preg_match('/^\d+\.\d+(\.\d+)?$/', $m['php_min']) === 1
            && is_bool($m['stufe']);
    }
}
