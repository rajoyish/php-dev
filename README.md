# php-dev

`php-dev` is a macOS CLI for switching between **Laravel Herd + DBngin MySQL** and **Flock + Flock MySQL**, and for running common Laravel project commands.

## Install

Keep the checkout at a stable path and run the following from its root. The interactive menu requires PHP 8.3+ with mbstring and Composer 2.2+.

```sh
./bin/php-dev composer install --no-interaction
./bin/php-dev install
```

Open a new Zsh session. The installer puts a managed block at the end of `.zshrc` (under `ZDOTDIR` if exported), after the Herd and Flock PATH settings. It replaces the old `~/.config/zsh/devenv.zsh` source line if present and preserves the saved stack in `~/.config/devenv/active`. Run the installer again if you move the checkout.

Both stacks use `/Volumes/Sites` as the default projects directory. Set `DEVENV_SITES` before the managed block to use another directory. Have the apps and databases you intend to switch between installed and configured. A stack switch may ask for `sudo` to update `.test` DNS.

## Usage

Run `php-dev` with no arguments in a terminal to open the Laravel Prompts menu. The menu shows the saved stack, asks for confirmation before switching services, and lets you enter a server port or test filter.

| Command | Action |
| --- | --- |
| `php-dev status` | Show the stack, service ports, DNS, PHP, and Composer. |
| `php-dev herd`, `php-dev flock`, and `php-dev toggle` | Switch the full stack. |
| `php-dev mysql [status\|dbngin\|flock\|toggle]` | Inspect or switch MySQL independently. |
| `php-dev php [args]` and `php-dev composer [args]` | Use PHP and Composer from the selected stack. |
| `php-dev artisan [args]` | Run Artisan from a Laravel project directory. |
| `php-dev serve`, `php-dev tinker`, and `php-dev test` | Run the corresponding Artisan command. |
| `php-dev dev [args]` | Run `composer run dev` in the current project. |

The Zsh shortcuts `use-herd`, `use-flock`, `devswitch`, `devstatus`, `use-dbngin`, and `use-flock-mysql` are also available.
