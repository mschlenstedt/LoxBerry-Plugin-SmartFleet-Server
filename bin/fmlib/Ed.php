<?php

declare(strict_types=1);

namespace FM;

use InvalidArgumentException;
use Throwable;

final class Ed
{
    const PUB_LEN = 32;
    const SIG_LEN = 64;
    const SEED_LEN = 32;

    public static function keypair(): array
    {
        $kp = sodium_crypto_sign_keypair();
        return array(sodium_crypto_sign_publickey($kp), sodium_crypto_sign_secretkey($kp));
    }

    public static function seedKeypair(string $seed32): array
    {
        if (strlen($seed32) !== self::SEED_LEN) {
            throw new InvalidArgumentException('Ed25519: Seed muss 32 Byte haben');
        }
        $kp = sodium_crypto_sign_seed_keypair($seed32);
        return array(sodium_crypto_sign_publickey($kp), sodium_crypto_sign_secretkey($kp));
    }

    public static function sign(string $secret64, string $msg): string
    {
        if (strlen($secret64) !== SODIUM_CRYPTO_SIGN_SECRETKEYBYTES) {
            throw new InvalidArgumentException('Ed25519: falsche Laenge des privaten Schluessels');
        }
        return sodium_crypto_sign_detached($msg, $secret64);
    }

    public static function verify(string $pub32, string $msg, string $sig64): bool
    {
        if (strlen($pub32) !== self::PUB_LEN || strlen($sig64) !== self::SIG_LEN) {
            return false;
        }
        try {
            return sodium_crypto_sign_verify_detached($sig64, $msg, $pub32);
        } catch (Throwable $e) {
            return false;
        }
    }
}
