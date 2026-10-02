<?php

declare(strict_types=1);

namespace FM;

use InvalidArgumentException;

final class B64
{
    public static function encode(string $bytes): string
    {
        return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
    }

    public static function decode(string $s): string
    {
        if ($s !== '' && preg_match('/[^A-Za-z0-9_-]/', $s)) {
            throw new InvalidArgumentException('base64url: unerlaubte Zeichen');
        }
        $rest = strlen($s) % 4;
        if ($rest === 1) {
            throw new InvalidArgumentException('base64url: unmoegliche Laenge');
        }
        $t = strtr($s, '-_', '+/') . str_repeat('=', ($rest === 0) ? 0 : 4 - $rest);
        $r = base64_decode($t, true);
        if ($r === false) {
            throw new InvalidArgumentException('base64url: nicht dekodierbar');
        }
        return $r;
    }
}
