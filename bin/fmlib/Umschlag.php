<?php

declare(strict_types=1);

namespace FM;

use Throwable;

if (!class_exists(B64::class)) {
    require_once __DIR__ . '/B64.php';
}
if (!class_exists(Ed::class)) {
    require_once __DIR__ . '/Ed.php';
}

final class Umschlag
{

    public static function oeffnen(string $text, string $pub32): ?array
    {
        if (strlen($pub32) !== 32) {
            return null;
        }
        $teile = explode('.', trim($text), 2);
        if (count($teile) !== 2 || $teile[0] === '') {
            return null;
        }
        try {
            $json = B64::decode($teile[0]);
            $sig  = B64::decode($teile[1]);
            if (strlen($sig) !== 64 || !Ed::verify($pub32, $teile[0], $sig)) {
                return null;
            }
        } catch (Throwable $e) {
            return null;
        }
        $doc = json_decode($json, true);
        return is_array($doc) ? $doc : null;
    }

    public static function schliessen(array $doc, string $secret64): string
    {
        $b64 = B64::encode((string)json_encode($doc, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
        return $b64 . '.' . B64::encode(Ed::sign($secret64, $b64));
    }
}
