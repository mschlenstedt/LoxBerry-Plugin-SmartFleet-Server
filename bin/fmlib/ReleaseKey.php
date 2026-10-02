<?php

declare(strict_types=1);

namespace FM;

final class ReleaseKey
{
    const PUB_B64 = 'pebaqCrwt0_QtXwmWCmC7YpjSHV2wshQabHmJeC0R2E';

    public static function pub(): ?string
    {
        if (self::PUB_B64 === '') {
            return null;
        }
        require_once __DIR__ . '/B64.php';
        try {
            $p = B64::decode(self::PUB_B64);
        } catch (\Throwable $e) {
            return null;
        }
        return strlen($p) === 32 ? $p : null;
    }
}
