# php-dev

A macOS CLI for running Laravel commands and switching between Laravel Herd with DBngin MySQL and Flock with Flock MySQL.

## Install with Homebrew

Once the repository and its first release are published, run:

```sh
brew tap rajoyish/php-dev https://github.com/rajoyish/php-dev.git
brew install rajoyish/php-dev/php-dev
"$(brew --prefix php-dev)/bin/php-dev" install
```

Open a new terminal and run `php-dev`. Homebrew installs the CLI, PHP, and Composer. Install and open [Herd](https://herd.laravel.com/) or Flock separately to manage its local services. For the Herd stack’s MySQL option, install [DBngin](https://dbngin.com/) and configure a MySQL instance first.

The last command adds one managed block to your Zsh startup file, after the Herd and Flock PATH settings. It also migrates an existing checkout-based setup to the Homebrew installation and preserves your saved stack. The block follows Homebrew upgrades. To uninstall, run `brew uninstall php-dev` and remove the lines between `# >>> php-dev >>>` and `# <<< php-dev <<<` in your Zsh startup file.

## Install from a checkout

Keep the checkout at a stable path. You’ll need PHP 8.3 or later, mbstring, and Composer 2.2 or later.

```sh
./bin/php-dev composer install --no-interaction
./bin/php-dev install
```

Open a new Zsh session. If you move the checkout, rerun the installer. If `ZDOTDIR` is exported, the installer uses its `.zshrc`.

## Set your projects directory

The default directory to park with Herd or Flock is `/Volumes/Sites`. To use a different directory, add an export before the managed block in your Zsh startup file. Choose an existing directory.

```zsh
export DEVENV_SITES="$HOME/Sites"
```

A stack switch can prompt for `sudo` to update the `.test` DNS resolver.

## Usage

Run `php-dev` to open the interactive menu. Use the arrow keys and Enter to choose an action. Stack and MySQL switches ask for confirmation. Start a server or run tests from a Laravel project directory. The menu lets you enter a port or a test filter.

| Command | Action |
| --- | --- |
| `php-dev status` | Show the saved stack, service ports, DNS, PHP, and Composer. |
| `php-dev herd`, `php-dev flock`, and `php-dev toggle` | Switch the full stack. |
| `php-dev mysql` | Show which MySQL service owns port 3306. Append `dbngin`, `flock`, or `toggle` to switch. |
| `php-dev php [args]` and `php-dev composer [args]` | Run PHP or Composer using the selected stack’s PATH. |
| `php-dev artisan [args]` | Run Artisan in the current Laravel project. |
| `php-dev serve`, `php-dev tinker`, and `php-dev test` | Run the corresponding Artisan command. |
| `php-dev dev [args]` | Run `composer run dev` in the current project. |

After Zsh setup, you can also use `use-herd`, `use-flock`, `devswitch`, `devstatus`, `use-dbngin`, and `use-flock-mysql`.

## Release through Homebrew

This repo doubles as the tap. The formula installs the published `v0.1.0` Git tag and uses `composer.lock` to install Laravel Prompts. Publish the repository at `rajoyish/php-dev` and push the tag for the commit containing the formula. For future releases, update the formula’s source tag and version together. Verify the published package with `brew test rajoyish/php-dev/php-dev`.

[Homebrew tap documentation](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
