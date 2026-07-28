# SnapAI

SnapAI generates square app artwork through OpenAI and Google Gemini. The repository currently provides three local entry points:

- `icon`: the stable scripting-friendly CLI.
- `ui`: a local browser UI for prompts, previews, generation, profiles, and history.
- `studio`: an interactive terminal workflow.

The UI and Studio are local-first MVP surfaces built on shared generation, configuration, profiles, and history services. A native macOS app is planned for a later phase.

## Requirements

- Node.js 18 or newer
- pnpm
- An OpenAI API key and/or Google Gemini API key

## Install and build from this checkout

```bash
pnpm install
pnpm run build
```

The commands below use `node bin/dev.js`, which loads the compiled `dist` directory. Rebuild after TypeScript changes.

## API keys

For a session, use environment variables so keys are not written to disk:

```bash
export OPENAI_API_KEY="sk-..."
export GEMINI_API_KEY="..."
```

SnapAI also accepts `SNAPAI_API_KEY` and `SNAPAI_GOOGLE_API_KEY`.

To persist keys locally in `~/.snapai/config.json`:

```bash
node bin/dev.js config --openai-api-key "sk-..."
node bin/dev.js config --google-api-key "..."
node bin/dev.js config --show
```

Do not commit `.env` files, API keys, or the `~/.snapai` runtime directory.

## Web UI

Start the local browser UI:

```bash
node bin/dev.js ui
```

It listens on `http://127.0.0.1:4173` and attempts to open the browser.

```bash
node bin/dev.js ui --no-open
node bin/dev.js ui --port 4190
```

The UI includes setup/health checks, prompt preview, generation, result metadata, history, and profile management. Generated files are written to the selected output directory; runtime data is stored under `~/.snapai`.

The current UI checkout supports `gpt-1.5`, `gpt-1`, and `banana`. The latest model aliases are currently available through the CLI below.

## Studio TUI

```bash
node bin/dev.js studio
node bin/dev.js studio --prompt "minimal weather artwork"
node bin/dev.js studio --model banana
node bin/dev.js studio --profile "my profile"
```

Studio supports profile-aware defaults, option overrides, confirmation before generation, reruns, prompt editing, and recent history.

## CLI

Generate an icon with the default OpenAI model:

```bash
node bin/dev.js icon --prompt "minimal weather app with sun and cloud"
```

Available model aliases:

| Alias | Provider/model |
| --- | --- |
| `gpt-1.5` | OpenAI `gpt-image-1.5` |
| `gpt-1` | OpenAI `gpt-image-1` |
| `gpt-image-2` | OpenAI GPT Image 2 |
| `banana` | Gemini Nano Banana |
| `banana-2` | Gemini Nano Banana 2 |

Examples:

```bash
# Save to a custom directory
node bin/dev.js icon --prompt "secure finance symbol" --output ./assets/icons

# Generate multiple OpenAI variations
node bin/dev.js icon --prompt "abstract music symbol" --model gpt-1.5 -n 3

# Use GPT Image 2
node bin/dev.js icon --prompt "soft 3D star" --model gpt-image-2

# Use Nano Banana 2
node bin/dev.js icon --prompt "friendly weather symbol" --model banana-2 --thinking max

# Preview the final prompt without making an API request
node bin/dev.js icon --prompt "calculator symbol" --style minimalism --prompt-only
```

## Prompt ideas and visual styles

The native Mac app includes a **Templates** button beside the prompt editor. It inserts starting points from the same examples and style vocabulary used by the shared prompt builder. You can edit the inserted text freely.

Useful starting prompts:

- `weather app with simple sun and cloud shapes` — `minimalism`
- `secure finance app with a bold shield and subtle checkmark` — `material`
- `music player app with abstract sound waves and simple shapes` — `gradient`
- `note-taking app with a pen and paper, minimal and friendly` — `clay`
- `camera app with a lens built from clean concentric circles` — `geometric`

Available style names include `minimalism`, `glassy`, `geometric`, `gradient`, `material`, `pixel`, `kawaii`, and `holographic`, along with the other presets in `src/utils/styleTemplates.ts`.

All generated CLI images are square `1024x1024` outputs. Use `node bin/dev.js icon --help` for the full flag reference.

## Development

Watch TypeScript while working:

```bash
pnpm run dev
```

In another terminal, run commands through the compiled output:

```bash
node bin/dev.js icon --prompt "test artwork" --prompt-only
```

Useful checks:

```bash
pnpm run build
pnpm run lint
```

The Studio command currently has lint errors for its intentional `while (true)` input loops; this does not prevent the project from building or running.

## Current packaging note

The repository build serves the full UI from `src/ui/static`. The current npm package configuration does not yet copy those static files into the published package, so use the source checkout for the complete UI until packaging is updated.
