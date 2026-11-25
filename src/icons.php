<?php

declare(strict_types=1);

/**
 * Menu icons, matching shell/icons.zsh. The style comes from PHP_DEV_ICONS,
 * else the choice saved by `php-dev icons`, else nerd. Every icon is padded to
 * three columns (emoji + 1 space, Nerd Font glyph + 2 spaces) so labels align.
 */
final class Icons
{
    private const EMOJI = [
        'php' => '🐘', 'laravel' => '🐘', 'folder' => '📁', 'sites' => '📂',
        'dot_ok' => '🟢', 'dot_warn' => '🟡', 'dot_off' => '⚪',
        'open' => '🌍', 'test' => '🧪', 'tinker' => '🐚', 'dev' => '⚡', 'db' => '💾', 'serve' => '🚀',
        'status' => '📊', 'doctor' => '🩺', 'switch' => '🔀', 'mysql' => '🐬', 'logs' => '📜',
        'palette' => '🎨', 'settings' => '🔧', 'back' => '🔙', 'exit' => '👋', 'herd' => '🦬', 'flock' => '🐦',
    ];

    /** Font Awesome, Devicons and Material Design glyphs from Nerd Fonts v3 */
    private const NERD = [
        'php' => "\u{f07c6}",     // md-elephant
        'laravel' => "\u{e73f}",  // dev-laravel
        'folder' => "\u{f07b}",   // fa-folder
        'sites' => "\u{f07c}",    // fa-folder_open
        'dot_ok' => "\u{f058}",   // fa-check_circle
        'dot_warn' => "\u{f06a}", // fa-exclamation_circle
        'dot_off' => "\u{f10c}",  // fa-circle_o
        'open' => "\u{f08e}",     // fa-external_link
        'test' => "\u{f0c3}",     // fa-flask
        'tinker' => "\u{f120}",   // fa-terminal
        'dev' => "\u{f0e7}",      // fa-bolt
        'db' => "\u{f1c0}",       // fa-database
        'serve' => "\u{f135}",    // fa-rocket
        'status' => "\u{f0e4}",   // fa-tachometer
        'doctor' => "\u{f0f1}",   // fa-stethoscope
        'switch' => "\u{f0ec}",   // fa-exchange
        'mysql' => "\u{e704}",    // dev-mysql
        'logs' => "\u{f15c}",     // fa-file_text
        'palette' => "\u{f1fc}",  // fa-paint_brush
        'settings' => "\u{f013}", // fa-cog
        'back' => "\u{f060}",     // fa-arrow_left
        'exit' => "\u{f08b}",     // fa-sign_out
        'herd' => "\u{e73f}",     // dev-laravel
        'flock' => "\u{f233}",    // fa-server
    ];

    public static function style(): string
    {
        $style = getenv('PHP_DEV_ICONS') ?: null;

        if ($style === null && ($state = getenv('DEVENV_STATE'))) {
            $file = dirname($state) . '/icons';
            $style = is_readable($file) ? trim((string) file_get_contents($file)) : null;
        }

        return $style === 'emoji' ? 'emoji' : 'nerd';
    }

    /** The icon for $name, padded and ready to put before a label. */
    public static function get(string $name, ?string $style = null): string
    {
        return ($style ?? self::style()) === 'nerd'
            ? self::NERD[$name] . '  '
            : self::EMOJI[$name] . ' ';
    }
}
