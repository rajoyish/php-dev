<?php

declare(strict_types=1);

use function Laravel\Prompts\confirm;
use function Laravel\Prompts\select;
use function Laravel\Prompts\text;

$root = dirname(__DIR__);
$autoload = $root . '/vendor/autoload.php';

if (!is_file($autoload)) {
    fwrite(STDERR, "php-dev: Install the menu dependencies with composer install in $root.\n");
    exit(1);
}

require $autoload;

$savedStack = getenv('DEVENV_STATE');
$activeStack = $savedStack && is_readable($savedStack)
    ? trim((string) file_get_contents($savedStack))
    : '';

$label = match ($activeStack) {
    'herd' => 'Herd',
    'flock' => 'Flock',
    default => 'unknown',
};

$action = select("php-dev · Active stack: $label", [
    'status' => 'Show stack status',
    'stack' => 'Switch the PHP stack',
    'mysql' => 'Manage MySQL',
    'serve' => 'Serve the current Laravel project',
    'tinker' => 'Open Laravel Tinker',
    'test' => 'Run Laravel tests',
    'dev' => 'Run composer dev',
    'exit' => 'Exit',
]);

$arguments = [$action];

switch ($action) {
    case 'exit':
        exit(0);

    case 'stack':
        $stack = select('Switch to which PHP stack?', [
            'herd' => 'Laravel Herd + DBngin MySQL',
            'flock' => 'Flock + Flock MySQL',
        ]);

        if (!confirm('Switch stacks? This restarts local services.', default: false)) {
            exit(0);
        }

        $arguments = [$stack];
        break;

    case 'mysql':
        $mysql = select('MySQL action', [
            'status' => 'Show MySQL status',
            'dbngin' => 'Switch to DBngin MySQL',
            'flock' => 'Switch to Flock MySQL',
        ]);

        if ($mysql !== 'status' && !confirm('Switch the local MySQL service?', default: false)) {
            exit(0);
        }

        $arguments[] = $mysql;
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

$process = proc_open(
    [$root . '/bin/php-dev', ...$arguments],
    [STDIN, STDOUT, STDERR],
    $pipes,
);

if (!is_resource($process)) {
    fwrite(STDERR, "php-dev: Could not start the selected command.\n");
    exit(1);
}

exit(proc_close($process));
