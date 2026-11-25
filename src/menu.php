<?php

declare(strict_types=1);

use function Laravel\Prompts\confirm;
use function Laravel\Prompts\text;

$root = dirname(__DIR__);
$autoload = $root . '/vendor/autoload.php';

if (!is_file($autoload)) {
    fwrite(STDERR, "php-dev: Install the menu dependencies with composer install in $root.\n");
    exit(1);
}

require $autoload;
require __DIR__ . '/icons.php';
require __DIR__ . '/MenuPrompt.php';

$i = static fn (string $name): string => Icons::get($name);

/**
 * A spaced select with a short description under each option, like the main menu.
 *
 * @param  array<int|string, string>  $options
 * @param  array<int|string, string>  $descriptions
 */
function choose(string $label, array $options, array $descriptions = [], int|string|null $default = null): int|string
{
    return (new MenuPrompt($label, $options, $descriptions, $default))->prompt();
}

/** Run php-dev with the terminal attached and return its exit code. Sets \$interrupted on Ctrl+C. */
function run(string $root, array $arguments, bool &$interrupted = false): int
{
    $interrupted = false;
    // Ctrl+C should stop the command (logs -f, composer dev, serve), not the menu.
    // A handler, unlike SIG_IGN, is reset in the child when it starts.
    $trap = function_exists('pcntl_signal');

    if ($trap) {
        pcntl_async_signals(true);
        pcntl_signal(SIGINT, static function () use (&$interrupted): void {
            $interrupted = true;
        });
    }

    $process = proc_open([$root . '/bin/php-dev', ...$arguments], [STDIN, STDOUT, STDERR], $pipes);
    $code = is_resource($process) ? proc_close($process) : null;

    if ($trap) {
        pcntl_signal(SIGINT, SIG_DFL);
    }

    if ($code === null) {
        fwrite(STDERR, "php-dev: Could not start the selected command.\n");

        return 1;
    }

    return $code;
}

/** The stack health from php-dev status --json, or null when it can't be read. */
function stackStatus(string $root): ?array
{
    $process = proc_open(
        [$root . '/bin/php-dev', 'status', '--json'],
        [1 => ['pipe', 'w'], 2 => ['file', '/dev/null', 'w']],
        $pipes,
    );

    if (!is_resource($process)) {
        return null;
    }

    $output = stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    proc_close($process);

    $status = json_decode((string) $output, true);

    return is_array($status) ? $status : null;
}

/** The parked site the current directory belongs to, if any. */
function currentSite(): ?string
{
    $sites = realpath(getenv('DEVENV_SITES') ?: '/Volumes/Sites');
    $cwd = getcwd();

    if ($sites === false || $cwd === false || !str_starts_with($cwd . '/', $sites . '/') || $cwd === $sites) {
        return null;
    }

    return strtolower(explode('/', substr($cwd, strlen($sites) + 1))[0]);
}

/** @return list<string> Log names for the active stack */
function logNames(?string $stack): array
{
    $directory = match ($stack) {
        'flock' => getenv('HOME') . '/Library/Application Support/Flock/log',
        'herd' => getenv('HOME') . '/Library/Application Support/Herd/Log',
        default => null,
    };

    return $directory === null ? [] : array_map(
        static fn (string $file): string => basename($file, '.log'),
        glob($directory . '/*.log') ?: [],
    );
}

$back = static fn (): string => $i('back') . 'Back to the main menu';

while (true) {
    $status = stackStatus($root);
    $stack = $status['stack'] ?? null;
    $issues = count($status['issues'] ?? []);
    $dot = match (true) {
        $status === null || !$stack => $i('dot_off'),
        $issues > 0 => $i('dot_warn'),
        default => $i('dot_ok'),
    };

    $isLaravel = is_file('artisan');
    $composer = is_file('composer.json') ? json_decode((string) file_get_contents('composer.json'), true) : null;
    $hasDev = is_array($composer) && isset($composer['scripts']['dev']);
    $site = currentSite();
    $project = $isLaravel || $composer ? basename((string) getcwd()) : null;

    $title = $i('php') . 'php-dev · ' . $dot . ($stack ? ucfirst($stack) : 'no stack')
        . ($issues > 0 ? " · $issues " . ($issues === 1 ? 'issue' : 'issues') : '')
        . ($project ? ' · ' . $i($isLaravel ? 'laravel' : 'folder') . $project : '');

    $projectActions = array_filter([
        'open' => $site ? $i('open') . "Open $site.test in the browser" : null,
        'test' => $isLaravel ? $i('test') . 'Run the tests' : null,
        'tinker' => $isLaravel ? $i('tinker') . 'Open Tinker' : null,
        'dev' => $hasDev ? $i('dev') . 'Run composer dev' : null,
        'db' => $isLaravel ? $i('db') . 'Open a MySQL shell for this project' : null,
        // Parked sites are already served at .test; artisan serve is for a separate port.
        'serve' => $isLaravel ? $i('serve') . 'Serve on a separate port with Artisan' : null,
    ]);

    $stackActions = [
        'status' => $i('status') . 'Show stack status',
        'doctor' => $i('doctor') . 'Run the doctor' . ($issues > 0 ? " ($issues to fix)" : ''),
        'stack' => $i('switch') . 'Switch the PHP stack',
        'mysql' => $i('mysql') . 'Manage MySQL',
        'sites' => $i('sites') . 'List sites',
        'logs' => $i('logs') . 'View service logs',
    ];

    if (!$isLaravel) {
        $stackActions['db'] = $i('db') . 'Open a MySQL shell';
    }

    $options = $projectActions
        ? [...$projectActions, ...$stackActions]
        : [...$stackActions, ...$projectActions];
    // php-dev's own settings, kept apart from the PHP stack and project actions.
    $options['icons'] = $i('settings') . 'CLI settings: change the icon style';
    $options['exit'] = $i('exit') . 'Exit';

    $sitesDir = str_replace((string) getenv('HOME'), '~', getenv('DEVENV_SITES') ?: '/Volumes/Sites');
    $descriptions = [
        'open' => "Open this project's .test site in your default browser",
        'test' => 'Run php artisan test, with an optional filter',
        'tinker' => 'Start an interactive Laravel REPL for this project',
        'dev' => "Run this project's composer dev script (Ctrl+C stops it)",
        'db' => $isLaravel ? 'Connect with the database credentials from .env' : 'Connect to the MySQL server on port 3306',
        'serve' => 'Run php artisan serve on a port you choose',
        'status' => 'Check which stack owns the ports, DNS, PHP and Composer',
        'doctor' => 'Find problems with the apps, Zsh setup and stack, and offer fixes',
        'stack' => 'Swap between Laravel Herd and Flock (restarts local services)',
        'mysql' => 'Check or switch between DBngin MySQL and Flock MySQL',
        'sites' => "List the projects in $sitesDir with their .test URLs",
        'logs' => "Read or follow the active stack's service logs",
        'icons' => "Choose Nerd Font or emoji icons for php-dev's own output",
        'exit' => 'Close the menu and return to the shell',
    ];

    $action = (new MenuPrompt($title, $options, $descriptions, default: $issues > 0 ? 'doctor' : null))->prompt();

    $arguments = [$action];

    switch ($action) {
        case 'exit':
            exit(0);

        case 'stack':
            $target = choose('Switch to which PHP stack?', [
                'herd' => $i('herd') . 'Laravel Herd + DBngin MySQL' . ($stack === 'herd' ? ' (active)' : ''),
                'flock' => $i('flock') . 'Flock + Flock MySQL' . ($stack === 'flock' ? ' (active)' : ''),
                'back' => $back(),
            ], [
                'herd' => 'Herd serves the sites with nginx and dnsmasq; DBngin runs MySQL',
                'flock' => 'Flock serves the sites and runs MySQL, mail and dumps',
                'back' => 'Return without switching',
            ], default: $stack === 'herd' ? 'flock' : 'herd');

            if ($target === 'back' || !confirm('Switch stacks? This restarts local services.', default: false)) {
                continue 2;
            }

            $arguments = [$target];
            break;

        case 'mysql':
            $mysql = choose('MySQL action', [
                'status' => $i('status') . 'Show MySQL status',
                'dbngin' => $i('switch') . 'Switch to DBngin MySQL',
                'flock' => $i('switch') . 'Switch to Flock MySQL',
                'back' => $back(),
            ], [
                'status' => 'See which service owns port 3306',
                'dbngin' => 'Stop Flock MySQL and start the DBngin instance',
                'flock' => 'Stop DBngin and start Flock MySQL',
                'back' => 'Return without changing MySQL',
            ]);

            if ($mysql === 'back'
                || ($mysql !== 'status' && !confirm('Switch the local MySQL service?', default: false))) {
                continue 2;
            }

            $arguments[] = $mysql;
            break;

        case 'doctor':
            $code = run($root, ['doctor']);
            echo "\n";

            if ($code !== 0 && $issues > 0
                && confirm('Fix the stack now? This can restart local services.', default: true)) {
                $arguments = ['doctor', '--fix'];
                break;
            }

            $arguments = null;
            break;

        case 'icons':
            $preview = static fn (string $style): string => implode('', array_map(
                static fn (string $name): string => Icons::get($name, $style),
                ['php', 'laravel', 'mysql', 'db', 'test', 'serve', 'dot_ok', 'dot_warn'],
            ));
            $current = Icons::style();

            $style = choose('CLI settings: icon style', [
                'nerd' => 'Nerd Font ' . $preview('nerd') . ($current === 'nerd' ? ' (current)' : ' (default)'),
                'emoji' => 'Emoji     ' . $preview('emoji') . ($current === 'emoji' ? ' (current)' : ''),
                'back' => $back(),
            ], [
                'nerd' => 'Logos and symbols; they show as boxes without a Nerd Font',
                'emoji' => 'Works in any terminal',
                'back' => 'Keep the current style',
            ], default: $current);

            if ($style === 'back') {
                continue 2;
            }

            $arguments[] = $style;
            break;

        case 'logs':
            $names = logNames($stack);

            if ($names === []) {
                fwrite(STDERR, "php-dev: No logs found for the active stack.\n\n");
                continue 2;
            }

            $log = choose('Which log?', [...array_combine($names, $names), "\0back" => $back()]);

            if ($log === "\0back") {
                continue 2;
            }

            $arguments[] = $log;

            if (confirm('Follow new lines? Press Ctrl+C to stop and return here.', default: true)) {
                $arguments[] = '-f';
            }
            break;

        case 'serve':
            $port = text(
                'Server port',
                placeholder: '8000',
                validate: static function (string $value): ?string {
                    $options = ['options' => ['min_range' => 1, 'max_range' => 65535]];

                    return $value === '' || filter_var($value, FILTER_VALIDATE_INT, $options) !== false
                        ? null
                        : 'Enter a port from 1 to 65535.';
                },
                hint: 'Press Ctrl+C to stop the server and return here.',
            );

            if ($port !== '') {
                $arguments[] = "--port=$port";
            }
            break;

        case 'test':
            $filter = text('Test filter', hint: 'Leave blank to run all tests.');

            if ($filter !== '') {
                $arguments[] = "--filter=$filter";
            }
            break;
    }

    $interrupted = false;
    $code = $arguments === null ? 0 : run($root, $arguments, $interrupted);
    echo "\n";

    $next = choose(match (true) {
        $interrupted => 'Stopped. What next?',
        $code === 0 => 'Done. What next?',
        default => "The command exited with code $code. What next?",
    }, [
        'menu' => $back(),
        'exit' => $i('exit') . 'Exit',
    ], [
        'menu' => 'Pick another command',
        'exit' => 'Close the menu and return to the shell',
    ]);

    if ($next === 'exit') {
        exit($code);
    }

    echo "\n";
}
