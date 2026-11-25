# php-dev

A macOS CLI and interactive menu for local PHP and Laravel development. It switches between two stacks (Laravel Herd with DBngin MySQL, and Flock with Flock MySQL), checks their health, and runs everyday project commands. `phpd` is a short alias for `php-dev`.

## Contents

- [Install with Homebrew](#install-with-homebrew)
- [Install from a checkout](#install-from-a-checkout)
- [Set your projects directory](#set-your-projects-directory)
- [The interactive menu](#the-interactive-menu)
- [Commands](#commands)
- [Status and doctor](#status-and-doctor)
- [Icon styles](#icon-styles)
- [Shell integration](#shell-integration)
- [Configuration](#configuration)
- [Development](#development)
- [Release through Homebrew](#release-through-homebrew)

## Install with Homebrew

Once the repository and its first release are published, run:

```sh
brew tap rajoyish/php-dev https://github.com/rajoyish/php-dev.git
brew install rajoyish/php-dev/php-dev
"$(brew --prefix php-dev)/bin/php-dev" install
```

Open a new terminal and run `php-dev` or `phpd`. Homebrew installs both commands, PHP, Composer, and Zsh completion. Install and open [Herd](https://herd.laravel.com/) or Flock separately to manage its local services. For the Herd stack’s MySQL, install [DBngin](https://dbngin.com/) and create a MySQL instance first.

The last command adds one managed block to your Zsh startup file, after the Herd and Flock PATH settings. It also migrates an existing checkout-based setup to the Homebrew installation and keeps your saved stack. The block follows Homebrew upgrades. To uninstall, run `brew uninstall php-dev` and remove the lines between `# >>> php-dev >>>` and `# <<< php-dev <<<` in your Zsh startup file.

## Install from a checkout

Keep the checkout at a stable path. You need PHP 8.3 or later with mbstring, and Composer 2.2 or later.

```sh
./bin/php-dev composer install --no-interaction
./bin/php-dev install
```

Open a new Zsh session. `bin/` is added to your PATH, so both `php-dev` and `phpd` work. If you move the checkout, rerun the installer. If `ZDOTDIR` is exported, the installer uses its `.zshrc`.

## Set your projects directory

The default directory parked in Herd or Flock is `/Volumes/Sites`. To use another existing directory, export it before the managed block in your Zsh startup file:

```zsh
export DEVENV_SITES="$HOME/Sites"
```

A stack switch can prompt for `sudo` to update the `.test` DNS resolver.

## The interactive menu

Run `php-dev` (or `phpd`) with no arguments in a terminal to open the menu. Use the arrow keys, or `j` and `k`, and press Enter.

```
┌ php-dev · Flock · my-app ─────────────────────────────────────┐
│ › ●  Open my-app.test in the browser                          │
│        Open this project's .test site in your default browser │
│                                                               │
│   ○  Show stack status                                        │
│        Check which stack owns the ports, DNS, PHP and Composer│
│                                                               │
│   ○  Run the doctor                                           │
│        Find problems with the apps, Zsh setup and stack, …    │
│   …                                                           │
└───────────────────────────────────────────────────────────────┘
```

- **Title:** the active stack and its health (healthy, issues found, or unknown), plus the project in the current directory. When there are issues, **Run the doctor** is preselected and shows how many there are.
- **Descriptions:** every command has a bold label and a short gray description, with a blank line between commands. Submenus use the same layout. In a short terminal, the list scrolls and shows `↑ more` and `↓ more`.
- **Project commands first:** inside a project you get open the site, run the tests, Tinker, `composer dev`, a MySQL shell, and `artisan serve` above the stack commands. Laravel-only commands appear only in Laravel projects.
- **Back to the main menu:** after a command finishes, choose **Back to the main menu** or **Exit**. Every submenu also has a Back option. Ctrl+C stops a running command, such as `logs -f`, `composer dev` or `artisan serve`, and returns you to the menu. In the menu itself, Ctrl+C exits.
- **Confirmation:** stack and MySQL switches ask before restarting services. After the doctor finds stack issues, the menu offers to fix them.
- **CLI settings:** **CLI settings: change the icon style** sits apart from the stack commands, just above Exit, because it configures php-dev itself.

The menu uses [Laravel Prompts](https://laravel.com/docs/prompts), extended in `src/MenuPrompt.php` for descriptions and spacing.

## Commands

Every command works as `php-dev <command>` or `phpd <command>`. Run `php-dev --help` for a summary.

### Stack

| Command | Action |
| --- | --- |
| `status [--json]` | Show the saved stack, service ports, DNS, PHP and Composer, and how to fix any mismatch. `--json` is for scripts and prompt segments. |
| `doctor [--fix]` | Check the apps, Zsh setup and stack. `--fix` repairs the stack by reapplying it. |
| `herd`, `flock`, `toggle` | Switch the full stack: web, DNS and MySQL. Herd and DBngin start in parallel, and a spinner shows while ports open. |
| `mysql [status\|dbngin\|flock\|toggle]` | Show which MySQL service owns port 3306, or switch MySQL on its own. |
| `logs [name] [-f] [-n lines]` | List the active stack’s service logs, or show one. `-f` follows new lines. |

### Sites

| Command | Action |
| --- | --- |
| `sites` | List the sites in your projects directory with their `.test` URLs and type: Laravel, PHP, Node or other. |
| `open [site]` | Open a site in the browser, over HTTPS when it responds. Defaults to the site you’re in. |
| `db [database]` | Open a MySQL shell on port 3306. In a Laravel project, it uses the `.env` credentials. |

### Project

| Command | Action |
| --- | --- |
| `php [args]`, `composer [args]` | Run PHP or Composer from the selected stack. |
| `artisan [args]` | Run Artisan in the current Laravel project. |
| `serve`, `tinker`, `test [args]` | Run the corresponding Artisan command. |
| `dev [args]` | Run `composer run dev` in the current project. |

### Setup and CLI settings

| Command | Action |
| --- | --- |
| `menu` | Open the interactive menu. |
| `install` | Add or update the managed block in your Zsh startup file. |
| `icons [nerd\|emoji]` | Show or save php-dev’s icon style. Nerd Font is the default. |

## Status and doctor

`php-dev status` prints one row per check, with a blank line between rows: web (:80), mail (:2525), MySQL (:3306), `.test` DNS, PHP, Composer and the sites directory. Each row has a state:

| State | Meaning |
| --- | --- |
| ok | Owned by the active stack |
| warning | Held by something else |
| off | Free or not installed |
| problem | Missing |

Any mismatch is listed below the rows with the command that fixes it, for example `→ php-dev herd`. `php-dev doctor` runs the same checks in three spaced sections (Apps, Setup and Stack), and `--fix` applies the fixes. Set `NO_COLOR` to turn off colour. The icons still differ in shape, so states stay readable without colour.

## Icon styles

php-dev uses [Nerd Font](https://www.nerdfonts.com/) icons by default: an elephant for PHP (`md-elephant`), the Laravel and MySQL logos, and Font Awesome symbols. Without a Nerd Font in your terminal, the icons show as empty boxes, so switch to emoji, which work anywhere:

```sh
php-dev icons emoji   # save the emoji style
php-dev icons         # preview both styles
php-dev icons nerd    # switch back to the default
```

You can also pick the style from the menu under **CLI settings**, or set `PHP_DEV_ICONS=nerd` or `emoji` to override the saved choice. Open terminals pick up a change at their next prompt.

**Font:** install JetBrains Mono Nerd Font and select **JetBrainsMono Nerd Font** in your terminal’s font settings:

```sh
brew install --cask font-jetbrains-mono-nerd-font
```

Avoid the *Nerd Font Mono* variant. It squeezes each icon into one narrow cell, so icons look small. A terminal program can’t set its own font size or weight, so the font you choose decides how large the icons look. Ghostty’s built-in font already includes the Nerd Font icons.

## Shell integration

The managed block in your Zsh startup file:

- Puts php-dev’s `bin/` first on your PATH, so `php-dev` and `phpd` are available.
- Puts the selected stack’s PHP and Composer on your PATH, and updates it at each prompt after a switch.
- Registers Tab completion for both commands: commands, MySQL actions, icon styles, site names, log names and Artisan commands.
- Keeps the older shortcuts: `use-herd`, `use-flock`, `devswitch`, `devstatus`, `use-dbngin` and `use-flock-mysql`.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `DEVENV_SITES` | `/Volumes/Sites` | Projects directory parked in Herd and Flock. |
| `DEVENV_STATE` | `~/.config/devenv/active` | File holding the saved stack. The saved icon style is kept next to it, in `icons`. |
| `PHP_DEV_ICONS` | saved choice, else `nerd` | Icon style: `nerd` or `emoji`. |
| `NO_COLOR` | unset | Turns off colour. |

## Development

```
bin/php-dev            Entry point; bin/phpd is a symlink to it
shell/devenv.zsh       Stack switching, status and row helpers
shell/tools.zsh        doctor, sites, open, logs and db
shell/icons.zsh        Nerd Font and emoji icon sets for shell output
shell/completions/     Zsh completion for php-dev and phpd
src/menu.php           Interactive menu
src/MenuPrompt.php     Laravel Prompts select with descriptions and spacing
src/icons.php          Icon sets for the menu
src/install-zsh.php    Zsh installer
tests/run.zsh          Test suite
Formula/php-dev.rb     Homebrew formula
```

Run the tests with `zsh tests/run.zsh`. They fake ports and apps, so they don’t touch your running stack. CI runs them on macOS with GitHub Actions, along with `brew style` for the formula.

## Release through Homebrew

This repository is also the tap. The formula installs the `v0.1.0` Git tag, uses `composer.lock` to install Laravel Prompts, and links `phpd` next to `php-dev`. To release, push the tag for the commit that contains the formula. For later releases, update the formula’s tag and version together. Check the published package with `brew test rajoyish/php-dev/php-dev`.

[Homebrew tap documentation](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
