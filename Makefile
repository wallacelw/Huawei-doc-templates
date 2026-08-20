# Makefile — build convenience for Huawei Document Templates
# ============================================================================
# Self-documenting: run `make` (no arguments) to list all available targets.
# Engine: XeLaTeX (via latexmk, $pdf_mode=5). pdflatex will NOT work.
# ============================================================================

# Bare `make` shows help instead of building everything.
.DEFAULT_GOAL := help

PT_DIR = examples/guide/pt
EN_DIR = examples/guide/en
SG_DIR = examples/setup-guide

# ============================================================================
##@ Help
# ============================================================================

help: ## Show this help message
	@if [ -t 1 ]; then B=$$(printf '\033[1m'); C=$$(printf '\033[36m'); R=$$(printf '\033[0m'); \
	else B=""; C=""; R=""; fi; \
	printf "Huawei Document Templates — build convenience\n"; \
	printf "Engine: XeLaTeX (latexmk). Run 'make <target>' to build.\n\n"; \
	awk -v B="$$B" -v C="$$C" -v R="$$R" 'BEGIN {FS = ":.*##"} \
	    /^##@/ { printf "\n%s%s%s\n", B, substr($$0, 5), R } \
	    /^[a-zA-Z0-9_.-]+:.*##/ { printf "  %s%-22s%s %s\n", C, $$1, R, $$2 }' $(MAKEFILE_LIST)

# ============================================================================
##@ Build (PDF via XeLaTeX)
# ============================================================================

all: samples examples all-formats ## Compile everything (samples + setup-guide + all formats)

samples: pt en ## Compile both guide samples (PT + EN)

examples: setup-guide ## Compile the setup-guide and copy its PDF to repo root

pt: ## Compile the Portuguese sample
	cd $(PT_DIR) && latexmk main.tex

en: ## Compile the English sample
	cd $(EN_DIR) && latexmk main.tex

setup-guide: ## Compile the setup-guide and copy its PDF to repo root
	cd $(SG_DIR) && latexmk setup-guide.tex
	cp $(SG_DIR)/setup-guide.pdf setup-guide.pdf

project: ## Compile a specific project (make project DIR=<path> [FILE=<name>.tex])
	@if [ -z "$(DIR)" ]; then echo "Usage: make project DIR=<path> [FILE=<name>.tex]"; exit 1; fi
	@if [ -z "$(FILE)" ]; then \
		TEX=$$(ls $(DIR)/*.tex 2>/dev/null | head -1); \
		if [ -z "$$TEX" ]; then echo "No .tex file found in $(DIR)/"; exit 1; fi; \
		echo "Compiling $$TEX"; \
		cd $(DIR) && latexmk $$(basename $$TEX); \
	else \
		echo "Compiling $(DIR)/$(FILE)"; \
		cd $(DIR) && latexmk $(FILE); \
	fi

menu: ## Interactive format menu (delegates to build.sh)
	./build.sh

# ============================================================================
##@ Multi-format output (DOCX, Markdown, HTML, EPUB via Pandoc)
# ============================================================================

all-formats: docx md html epub ## Generate all formats (DOCX+MD+HTML+EPUB) for both samples

md:   md-pt md-en   ## Markdown for both samples
docx: docx-pt docx-en ## DOCX for both samples
html: html-pt html-en ## HTML for both samples
epub: epub-pt epub-en ## EPUB for both samples

# Per-sample format targets (advanced — not shown in help summary)
md-pt:     ; ./build.sh --md examples/guide/pt
md-en:     ; ./build.sh --md examples/guide/en
docx-pt:   ; ./build.sh --docx examples/guide/pt
docx-en:   ; ./build.sh --docx examples/guide/en
html-pt:   ; ./build.sh --html examples/guide/pt
html-en:   ; ./build.sh --html examples/guide/en
epub-pt:   ; ./build.sh --epub examples/guide/pt
epub-en:   ; ./build.sh --epub examples/guide/en

# ============================================================================
##@ Cleanup
# ============================================================================

clean: clean-samples clean-examples clean-formats ## Remove all build artifacts

clean-samples: clean-pt clean-en ## Clean both guide samples

clean-examples: clean-setup-guide ## Clean the setup-guide

clean-pt: ## Clean the Portuguese sample
	cd $(PT_DIR) && latexmk -C main.tex

clean-en: ## Clean the English sample
	cd $(EN_DIR) && latexmk -C main.tex

clean-setup-guide: ## Clean the setup-guide and the repo-root PDF copy
	cd $(SG_DIR) && latexmk -C setup-guide.tex
	rm -f setup-guide.pdf

clean-formats: ## Remove generated multi-format files (DOCX/MD/HTML/EPUB)
	rm -f examples/guide/pt/main.docx examples/guide/pt/main.md examples/guide/pt/main.html examples/guide/pt/main.epub
	rm -f examples/guide/en/main.docx examples/guide/en/main.md examples/guide/en/main.html examples/guide/en/main.epub

clean-project: ## Clean a specific project (make clean-project DIR=<path> [FILE=<name>.tex])
	@if [ -z "$(DIR)" ]; then echo "Usage: make clean-project DIR=<path> [FILE=<name>.tex]"; exit 1; fi
	@if [ -z "$(FILE)" ]; then \
		TEX=$$(ls $(DIR)/*.tex 2>/dev/null | head -1); \
		if [ -z "$$TEX" ]; then echo "No .tex file found in $(DIR)/"; exit 1; fi; \
		cd $(DIR) && latexmk -C $$(basename $$TEX); \
	else \
		cd $(DIR) && latexmk -C $(FILE); \
	fi

# ============================================================================
# Phony declarations
# ============================================================================

.PHONY: help all samples examples pt en setup-guide project menu
.PHONY: docx docx-pt docx-en md md-pt md-en html html-pt html-en epub epub-pt epub-en all-formats
.PHONY: clean clean-samples clean-examples clean-pt clean-en clean-setup-guide clean-project clean-formats
