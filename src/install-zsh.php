<?php

declare(strict_types=1);

function installZsh(): string
{
    $configDirectory = getenv('ZDOTDIR') ?: getenv('HOME');
    if (!$configDirectory || !is_dir($configDirectory)) {
        throw new RuntimeException('The Zsh configuration directory does not exist.');
    }

    $zshrc = $configDirectory . '/.zshrc';
    if (is_link($zshrc)) {
        $zshrc = realpath($zshrc) ?: throw new RuntimeException('The .zshrc symlink has no target.');
    }

    $exists = file_exists($zshrc);
    if ($exists && !is_file($zshrc)) {
        throw new RuntimeException("$zshrc is not a regular file.");
    }
    $original = $exists ? @file_get_contents($zshrc) : '';
    if ($original === false) {
        throw new RuntimeException("Could not read $zshrc.");
    }

    $start = '# >>> php-dev >>>';
    $end = '# <<< php-dev <<<';
    $legacy = [
        '# Apply the saved PHP stack after Herd and Flock have added their bin directories.',
        'source "$HOME/.config/zsh/devenv.zsh"',
    ];

    $lines = explode("\n", $original);
    $remaining = [];
    $inBlock = false;
    foreach ($lines as $line) {
        $marker = trim($line);
        if ($marker === $start || $marker === $end) {
            if ($inBlock === ($marker === $start)) {
                throw new RuntimeException("Unbalanced php-dev markers in $zshrc.");
            }
            $inBlock = $marker === $start;
        } elseif (!$inBlock && !in_array($marker, $legacy, true)) {
            $remaining[] = $line;
        }
    }
    if ($inBlock) {
        throw new RuntimeException("Unbalanced php-dev markers in $zshrc.");
    }

    $init = dirname(__DIR__) . '/shell/init.zsh';
    if (str_contains($init, "\n") || str_contains($init, "\r")) {
        throw new RuntimeException('The checkout path contains a line break.');
    }
    $quotedInit = "'" . str_replace("'", "'\\''", $init) . "'";
    $contents = rtrim(implode("\n", $remaining), "\r\n");
    $updated = ($contents === '' ? '' : "$contents\n\n")
        . "$start\n[[ -r $quotedInit ]] && source $quotedInit\n$end\n";

    if ($updated === $original) {
        return "Zsh is already configured in $zshrc.";
    }

    $directory = dirname($zshrc);
    if (!is_writable($directory) || ($exists && !is_writable($zshrc))) {
        throw new RuntimeException("No write access to $zshrc.");
    }

    $temporary = @tempnam($directory, '.php-dev-');
    if ($temporary === false || dirname((string) realpath($temporary)) !== realpath($directory)) {
        if ($temporary !== false) {
            unlink($temporary);
        }
        throw new RuntimeException("Could not create a temporary file beside $zshrc.");
    }

    try {
        $mode = $exists ? (fileperms($zshrc) & 0777) : 0600;
        if (@file_put_contents($temporary, $updated) !== strlen($updated)
            || !@chmod($temporary, $mode)) {
            throw new RuntimeException("Could not prepare the update to $zshrc.");
        }
        if (($exists && @file_get_contents($zshrc) !== $original) || (!$exists && file_exists($zshrc))) {
            throw new RuntimeException("$zshrc changed during installation. Run php-dev install again.");
        }
        if (!@rename($temporary, $zshrc)) {
            throw new RuntimeException("Could not update $zshrc.");
        }
    } finally {
        if (file_exists($temporary)) {
            unlink($temporary);
        }
    }

    return "Configured php-dev in $zshrc. Open a new Zsh session to use it.";
}

try {
    fwrite(STDOUT, installZsh() . "\n");
} catch (RuntimeException $exception) {
    fwrite(STDERR, 'php-dev: ' . $exception->getMessage() . "\n");
    exit(1);
}
