# Makefile — build convenience for Huawei Document Templates
# Usage:
#   make                 — compile all documents (samples + examples)
#   make samples         — compile PT and EN samples only
#   make examples        — compile setup-guide only
#   make pt              — compile Portuguese sample only
#   make en              — compile English sample only
#   make setup-guide     — compile setup guide only
#   make project DIR=examples/my-guide — compile a specific project (auto-detects .tex)
#   make clean           — remove all build artifacts
#   make clean-pt / clean-en / clean-setup-guide — clean specific targets
#   make clean-project DIR=examples/my-guide — clean a specific project

.PHONY: all samples examples pt en setup-guide project menu
.PHONY: docx docx-pt docx-en md md-pt md-en html html-pt html-en epub epub-pt epub-en all-formats
.PHONY: clean clean-samples clean-examples clean-pt clean-en clean-setup-guide clean-project clean-formats

PT_DIR   = examples/guide/pt
EN_DIR   = examples/guide/en
SG_DIR   = examples/setup-guide

all: samples examples all-formats

# ── Interactive build menu ──
menu:
	./build.sh

samples: pt en

examples: setup-guide

# ── Per-project targets ──
pt:
	cd $(PT_DIR) && latexmk main.tex

en:
	cd $(EN_DIR) && latexmk main.tex

setup-guide:
	cd $(SG_DIR) && latexmk setup-guide.tex
	cp $(SG_DIR)/setup-guide.pdf setup-guide.pdf

# ── Generic project target (auto-detects the .tex file) ──
# Usage: make project DIR=examples/my-guide
#        make project DIR=examples/my-guide FILE=custom.tex
project:
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

# ── Multi-format output (delegates to build.sh) ──
md-pt:     ; ./build.sh --md examples/guide/pt
md-en:     ; ./build.sh --md examples/guide/en
docx-pt:   ; ./build.sh --docx examples/guide/pt
docx-en:   ; ./build.sh --docx examples/guide/en
html-pt:   ; ./build.sh --html examples/guide/pt
html-en:   ; ./build.sh --html examples/guide/en
epub-pt:   ; ./build.sh --epub examples/guide/pt
epub-en:   ; ./build.sh --epub examples/guide/en

md:   md-pt md-en
docx: docx-pt docx-en
html: html-pt html-en
epub: epub-pt epub-en
all-formats: docx md html epub

# ── Clean targets ──
clean: clean-samples clean-examples clean-formats

clean-samples: clean-pt clean-en

clean-examples: clean-setup-guide

clean-pt:
	cd $(PT_DIR) && latexmk -C main.tex

clean-en:
	cd $(EN_DIR) && latexmk -C main.tex

clean-setup-guide:
	cd $(SG_DIR) && latexmk -C setup-guide.tex
	rm -f setup-guide.pdf

clean-project:
	@if [ -z "$(DIR)" ]; then echo "Usage: make clean-project DIR=<path> [FILE=<name>.tex]"; exit 1; fi
	@if [ -z "$(FILE)" ]; then \
		TEX=$$(ls $(DIR)/*.tex 2>/dev/null | head -1); \
		if [ -z "$$TEX" ]; then echo "No .tex file found in $(DIR)/"; exit 1; fi; \
		cd $(DIR) && latexmk -C $$(basename $$TEX); \
	else \
		cd $(DIR) && latexmk -C $(FILE); \
	fi

clean-formats:
	rm -f examples/guide/pt/main.docx examples/guide/pt/main.md examples/guide/pt/main.html examples/guide/pt/main.epub
	rm -f examples/guide/en/main.docx examples/guide/en/main.md examples/guide/en/main.html examples/guide/en/main.epub
