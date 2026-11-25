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

Run `php-dev`, or its short alias `phpd`, to open the interactive menu. Every command works with either name, for example `phpd status`. Use the arrow keys and Enter to choose an action. The title shows the active stack and its health: 🟢 healthy, 🟡 issues found (the doctor is then preselected), ⚪ unknown. Inside a project, its actions come first: open the site, run tests, Tinker, `composer dev`, a MySQL shell, or `artisan serve`. Stack and MySQL switches ask for confirmation. After a command finishes, choose **Back to the main menu** or **Exit**. Every submenu also has a Back option, and Ctrl+C stops a running command such as `logs -f` or `composer dev` and returns you to the menu.

| Command | Action |
| --- | --- |
| `php-dev status [--json]` | Show the saved stack, service ports, DNS, PHP, Composer, and how to fix any mismatch. `--json` is for scripts and prompt segments. |
| `php-dev doctor [--fix]` | Check the apps, Zsh setup, and stack. `--fix` repairs the stack by reapplying it. |
| `php-dev herd`, `php-dev flock`, and `php-dev toggle` | Switch the full stack. |
| `php-dev mysql` | Show which MySQL service owns port 3306. Append `dbngin`, `flock`, or `toggle` to switch. |
| `php-dev logs [name] [-f] [-n lines]` | List the active stack’s service logs, or show one. |
| `php-dev sites` | List the sites in your projects directory with their `.test` URLs. |
| `php-dev open [site]` | Open a site in the browser. Defaults to the site you’re in. |
| `php-dev db [database]` | Open a MySQL shell on port 3306. In a Laravel project, it uses the `.env` credentials. |
| `php-dev php [args]` and `php-dev composer [args]` | Run PHP or Composer using the selected stack’s PATH. |
| `php-dev artisan [args]` | Run Artisan in the current Laravel project. |
| `php-dev serve`, `php-dev tinker`, and `php-dev test` | Run the corresponding Artisan command. |
| `php-dev dev [args]` | Run `composer run dev` in the current project. |
| `php-dev icons [nerd\|emoji]` | CLI setting: show or save php-dev’s icon style. Nerd Font is the default. |

Status icons: 🟢 owned by the active stack, 🟡 held by something else, ⚪ free, 🔴 missing. Set `NO_COLOR` to turn off colour.

### Icon styles

php-dev uses [Nerd Font](https://www.nerdfonts.com/) icons by default: a PHP elephant, the Laravel and MySQL logos, and Font Awesome symbols. If your terminal doesn’t use a Nerd Font, the icons show as empty boxes, so switch to emoji, which work anywhere:

```sh
php-dev icons emoji   # save the emoji style
php-dev icons         # preview both styles
php-dev icons nerd    # switch back to the default
```

The icon style is a setting for the CLI itself, so the menu lists it separately at the bottom as **CLI settings: change the icon style**. You can also set `PHP_DEV_ICONS=nerd` or `emoji` to override the saved choice.

For a font, install JetBrains Mono Nerd Font with `brew install --cask font-jetbrains-mono-nerd-font` and select **JetBrainsMono Nerd Font** in your terminal’s settings. Avoid the *Nerd Font Mono* variant: it squeezes each icon into one narrow cell, so icons look small. A terminal app can’t set its own font size, so the font you choose decides how large the icons look.

After Zsh setup, Tab completes commands, sites, log names, and Artisan commands. You can also use `use-herd`, `use-flock`, `devswitch`, `devstatus`, `use-dbngin`, and `use-flock-mysql`.

## Development

Run the tests with `zsh tests/run.zsh`. They fake ports and apps, so they don’t touch your running stack. CI runs them on macOS along with `brew style` for the formula.

## Release through Homebrew

This repo doubles as the tap. The formula installs the published `v0.1.0` Git tag and uses `composer.lock` to install Laravel Prompts. Publish the repository at `rajoyish/php-dev` and push the tag for the commit containing the formula. For future releases, update the formula’s source tag and version together. Verify the published package with `brew test rajoyish/php-dev/php-dev`.

[Homebrew tap documentation](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
