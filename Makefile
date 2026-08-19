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

.PHONY: all samples examples pt en setup-guide project
.PHONY: docx docx-pt docx-en md md-pt md-en html html-pt html-en all-formats
.PHONY: clean clean-samples clean-examples clean-pt clean-en clean-setup-guide clean-project clean-formats

PT_DIR   = examples/guide/pt
EN_DIR   = examples/guide/en
SG_DIR   = examples/setup-guide

PANDOC      = pandoc
LUA_FILTER  = templates/guide/guide-pandoc.lua
REF_DOCX    = templates/guide/guide-reference.docx
HTML_TMPL   = templates/guide/guide-template.html

all: samples examples all-formats

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

# ── Multi-format output ──────────────────────────────────────────────

docx-pt:
	cd examples/guide/pt && $(PANDOC) -f latex+raw_tex --lua-filter=../../../$(LUA_FILTER) --reference-doc=../../../$(REF_DOCX) -t docx main.tex -o main.docx

docx-en:
	cd examples/guide/en && $(PANDOC) -f latex+raw_tex --lua-filter=../../../$(LUA_FILTER) --reference-doc=../../../$(REF_DOCX) -t docx main.tex -o main.docx

md-pt:
	cd examples/guide/pt && $(PANDOC) -f latex+raw_tex --lua-filter=../../../$(LUA_FILTER) -t markdown --wrap=none main.tex -o main.md

md-en:
	cd examples/guide/en && $(PANDOC) -f latex+raw_tex --lua-filter=../../../$(LUA_FILTER) -t markdown --wrap=none main.tex -o main.md

html-pt:
	cd examples/guide/pt && $(PANDOC) -f latex+raw_tex --lua-filter=../../../$(LUA_FILTER) --template=../../../$(HTML_TMPL) -s -t html5 main.tex -o main.html

html-en:
	cd examples/guide/en && $(PANDOC) -f latex+raw_tex --lua-filter=../../../$(LUA_FILTER) --template=../../../$(HTML_TMPL) -s -t html5 main.tex -o main.html

docx: docx-pt docx-en
md: md-pt md-en
html: html-pt html-en

all-formats: docx md html

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
	rm -f examples/guide/pt/main.docx examples/guide/pt/main.md examples/guide/pt/main.html
	rm -f examples/guide/en/main.docx examples/guide/en/main.md examples/guide/en/main.html
	rm -f examples/setup-guide/setup-guide.docx examples/setup-guide/setup-guide.md examples/setup-guide/setup-guide.html
