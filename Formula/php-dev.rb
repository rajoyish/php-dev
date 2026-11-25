class PhpDev < Formula
  desc "Switch local PHP stacks and run Laravel project commands"
  homepage "https://github.com/rajoyish/php-dev"
  url "https://github.com/rajoyish/php-dev.git", tag: "v0.1.1"
  version "0.1.1"

  depends_on "composer"
  depends_on :macos
  depends_on "php"

  def install
    ENV["COMPOSER_HOME"] = (buildpath/".composer").to_s
    system formula_opt_bin("composer")/"composer", "install", "--no-dev", "--prefer-dist", "--no-interaction",
           "--no-progress", "--no-plugins", "--no-scripts"

    libexec.install "bin", "shell", "src", "vendor"
    zsh_completion.install_symlink libexec/"shell/completions/_php-dev"
    (bin/"php-dev").write_env_script libexec/"bin/php-dev",
                                     PHP_DEV_BREW_PREFIX: opt_prefix,
                                     PHP_DEV_RUNTIME_PHP: formula_opt_bin("php")/"php"
    bin.install_symlink "php-dev" => "phpd"
  end

  def caveats
    <<~EOS
      To configure your current user's Zsh, run:
        "#{opt_bin}/php-dev" install
      Then open a new terminal.
    EOS
  end

  test do
    assert_match "Open the interactive menu", shell_output("#{bin}/php-dev --help")
    assert_match "Open the interactive menu", shell_output("#{bin}/phpd --help")
    php = formula_opt_bin("php")/"php"
    system php, "-r", %q(require $argv[1]; exit(class_exists(Laravel\Prompts\Prompt::class) ? 0 : 1);),
           libexec/"vendor/autoload.php"

    ENV["ZDOTDIR"] = testpath.to_s
    ENV["DEVENV_STATE"] = (testpath/"active").to_s
    (testpath/"active").write("flock\n")
    system bin/"php-dev", "install"
    assert_match "#{opt_libexec}/shell/init.zsh", (testpath/".zshrc").read
  end
end
