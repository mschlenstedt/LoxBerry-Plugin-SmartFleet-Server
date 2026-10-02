<?php

declare(strict_types=1);

namespace FM;

use InvalidArgumentException;

final class Version
{
    const DATEI = __DIR__ . '/VERSION';

    public static function aktuell(string $datei = self::DATEI): string
    {
        $v = @file_get_contents($datei);
        $v = ($v === false) ? '' : trim($v);
        return self::gueltig($v) ? $v : '0.0.0';
    }

    public static function gueltig(string $v): bool
    {
        return preg_match('/^(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})\.(0|[1-9]\d{0,4})$/', $v) === 1;
    }

    public static function vergleiche(string $a, string $b): int
    {
        if (!self::gueltig($a) || !self::gueltig($b)) {
            throw new InvalidArgumentException('ungueltige Version');
        }
        $x = array_map('intval', explode('.', $a));
        $y = array_map('intval', explode('.', $b));
        for ($i = 0; $i < 3; $i++) {
            if ($x[$i] !== $y[$i]) {
                return $x[$i] < $y[$i] ? -1 : 1;
            }
        }
        return 0;
    }
}
