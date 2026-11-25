<?php

declare(strict_types=1);

use Laravel\Prompts\SelectPrompt;
use Laravel\Prompts\Themes\Default\SelectPromptRenderer;

/**
 * A select prompt that shows a short description under each option and a
 * blank line between options. Each option takes three lines on screen.
 */
final class MenuPrompt extends SelectPrompt
{
    public const LINES_PER_OPTION = 3;

    /**
     * @param  array<int|string, string>  $options
     * @param  array<int|string, string>  $descriptions  Keyed like $options
     */
    public function __construct(
        string $label,
        array $options,
        public array $descriptions = [],
        int|string|null $default = null,
    ) {
        parent::__construct($label, $options, $default, scroll: count($options));
    }

    protected function getRenderer(): callable
    {
        return new MenuPromptRenderer($this);
    }

    /** Fit whole options (three lines each, no blank after the last) into the terminal. */
    protected function reduceScrollingToFitTerminal(): void
    {
        $available = $this->terminal()->lines() - $this->getRenderer()->reservedLines();
        $fits = static fn (int $lines): int => intdiv($lines + 1, self::LINES_PER_OPTION);

        // When some options are hidden, the "↑ more" and "↓ more" lines and their blanks take 4 more.
        $this->scroll = $fits($available) >= $this->scroll
            ? $this->scroll
            : max(1, $fits($available - 4));
    }
}

final class MenuPromptRenderer extends SelectPromptRenderer
{
    /**
     * Description colours from the 256-colour palette. Terminals can't switch to a
     * light font weight, and some (Warp) don't render dim, so a darker grey keeps
     * descriptions quieter than the bold labels.
     */
    private const DESCRIPTION = 241;

    private const DESCRIPTION_SELECTED = 246;

    private function shade(string $text, int $color): string
    {
        return "\e[38;5;{$color}m{$text}\e[39m";
    }

    protected function renderOptions(SelectPrompt $prompt): string
    {
        assert($prompt instanceof MenuPrompt);

        $width = $prompt->terminal()->cols() - 12;
        $keys = array_keys($prompt->options);
        $visible = $prompt->visible();
        $lines = [];

        if ($prompt->firstVisible > 0) {
            $lines[] = $this->dim("  ↑ {$prompt->firstVisible} more");
        }

        foreach ($visible as $key => $label) {
            $selected = $prompt->highlighted === array_search($key, $keys, true);
            $label = $this->truncate($label, $width);
            $description = $this->truncate($prompt->descriptions[$key] ?? '', $width - 3);

            if ($lines !== []) {
                $lines[] = '';
            }

            if ($prompt->state === 'cancel') {
                $lines[] = $this->dim(($selected ? '› ● ' : '  ○ ') . $this->strikethrough($label));
            } else {
                // Bold labels stand out from their descriptions. Gray, not dim, for the
                // others: bold and dim together render differently from terminal to terminal.
                $lines[] = $selected
                    ? "{$this->cyan('›')} {$this->cyan('●')} {$this->bold($label)}"
                    : "  {$this->dim('○')} {$this->bold($this->gray($label))}";
            }

            // Line the description up with the label text, after its three-column icon.
            if ($description !== '') {
                $lines[] = '       ' . $this->shade($description, $selected ? self::DESCRIPTION_SELECTED : self::DESCRIPTION);
            }
        }

        $below = count($keys) - $prompt->firstVisible - count($visible);

        if ($below > 0) {
            $lines[] = '';
            $lines[] = $this->dim("  ↓ $below more");
        }

        return implode(PHP_EOL, $lines);
    }
}
