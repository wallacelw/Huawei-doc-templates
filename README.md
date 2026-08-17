# Huawei Document Templates

A collection of LaTeX templates for Huawei Cloud documents. Each template
lives under `templates/<name>/` and is self-contained: class file, samples,
skill, assets, and build config. Documents compile to PDF via XeLaTeX.

## Quick start

**One-liner (clone + install):**

```bash
curl -fsSL https://raw.githubusercontent.com/wallacelw/huawei-doc-templates/main/install.sh | bash
```

**Or step by step:**

```bash
git clone https://github.com/wallacelw/huawei-doc-templates.git
cd huawei-doc-templates
./install.sh
```

Then open the project in [opencode](https://opencode.ai) and run:

```
/skill huawei-template-guide
```

to create a new guide document.

## Requirements

- **OS:** Ubuntu 22.04+ (WSL or native)
- That's it — `install.sh` handles everything else.

`install.sh` installs:

- XeLaTeX + latexmk + LaTeX packages (`texlive-xetex`, `texlive-latex-extra`,
  `texlive-lang-portuguese`)
- fvextra ≥ 1.5 (updated from CTAN if the system version is too old)
- HarmonyOS Sans font (body text — from GitHub releases, SHA-256 verified)
- Cascadia Code font (code — via `fonts-cascadia-code`)
- opencode skills (copies each `templates/*/SKILL.md` to `~/.config/opencode/skills/`)
- VS Code LaTeX Workshop extension + settings (local and remote)

> `pdflatex` won't work — the templates use `fontspec` (system fonts), which
> requires XeLaTeX. `install.sh` installs and configures XeLaTeX automatically.

## Compilation

### Using latexmk (recommended)

```bash
cd examples/guide/pt && latexmk main.tex   # Portuguese sample
cd examples/guide/en && latexmk main.tex   # English sample
cd examples/setup-guide && latexmk setup-guide.tex   # setup guide
```

### Using the Makefile

```bash
make pt              # compile Portuguese sample only
make en              # compile English sample only
make setup-guide     # compile setup guide only
make samples         # compile PT + EN samples
make examples        # compile setup-guide, copy PDF to repo root
make                 # all of the above
make project DIR=examples/my-guide   # compile a specific project (auto-detects .tex)
make clean           # remove all build artifacts
make clean-pt        # clean specific project
```

## Timezone

The cover page shows the compilation date and time. The template defaults to
`America/Sao_Paulo` (GMT-3). Override in your project's `.latexmkrc`:

```perl
$ENV{TZ} = "UTC";  # override the template default
```

Pass the `[notime]` class option to hide the time on the cover page.

## VS Code (optional)

The repo ships `.vscode/settings.json` pre-configured for **latexmk (XeLaTeX)**.
Install the [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop)
extension, open the repo root, and save any `.tex` file to auto-compile.

## Templates

| Template | Skill | Description |
|---|---|---|
| [`guide`](templates/guide/) | `/skill huawei-template-guide` | Huawei Cloud guide — branded cover, header, TOC, giant chapter numbers, objectives block, code blocks, tables, callout boxes, badges, changelog. English (default) and Portuguese. |

See [`templates/guide/SKILL.md`](templates/guide/SKILL.md) for the full command
and environment reference.

## Project layout

```
.
├── AGENTS.md               # project standards and locked decisions
├── install.sh               # one-command setup (clone + install + verify)
├── Makefile                 # build convenience (make samples/examples/clean)
├── opencode.json            # skill discovery: scans templates/ for SKILL.md
├── README.md                # this file
├── LICENSE                  # MIT
├── .vscode/
│   └── settings.json        # VS Code + LaTeX Workshop config (latexmk recipe)
├── templates/
│   └── guide/               # self-contained template + skill
│       ├── SKILL.md          # opencode skill + agent command reference
│       ├── README.md         # template-specific details (brief)
│       ├── guide.cls         # the class — all formatting lives here
│       ├── .latexmkrc        # latexmk config (XeLaTeX, TZ=America/Sao_Paulo)
│       └── common-assets/      # logos, sample images, example scripts
├── documents/               # user-created documents (one subfolder per doc)
│   └── my-guide/            # example: a new document project
│       ├── main.tex
│       ├── .latexmkrc        # TEXINPUTS → ../../templates/guide/
│       └── assets/           # project-specific images
└── examples/                 # all example documents and samples
    ├── guide/               # samples for the guide template
    │   ├── pt/               # Portuguese sample
    │   │   ├── .latexmkrc    # TEXINPUTS → templates/guide/
    │   │   ├── main.tex
    │   │   └── assets/       # project-specific images
    │   └── en/               # English sample
    │       ├── .latexmkrc
    │       ├── main.tex
    │       └── assets/       # project-specific images
    └── setup-guide/          # real-world ECS + SSH + MaaS gateway guide
        ├── setup-guide.tex
        ├── .latexmkrc
        └── assets/
```

## Adding a new template

1. Create `templates/<name>/` with:
   - `<name>.cls` — the LaTeX class file
   - `SKILL.md` — skill definition (YAML frontmatter: `name: huawei-template-<name>`,
     `description: ...`)
   - `README.md` — brief template-specific docs
   - `.latexmkrc` — latexmk config (XeLaTeX)
   - `common-assets/` — logos, sample images
2. Add samples in `examples/<name>/pt/` and `examples/<name>/en/`.
3. Add a row to the Templates table above.
4. `install.sh` will auto-discover and install the skill on next run.

See [`AGENTS.md`](AGENTS.md) for full project standards and locked decisions.

## License

MIT — see [LICENSE](LICENSE).
