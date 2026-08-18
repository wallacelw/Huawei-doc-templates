# latexmkrc — use XeLaTeX by default (the class loads fontspec, so pdflatex won't work)
# TEXINPUTS includes ../../../templates/guide/ so guide.cls and common-assets/ are found
$ENV{TEXINPUTS} = "../../../templates/_base/:../../../templates/guide/:" . ($ENV{TEXINPUTS} || "");
$ENV{TZ} = "America/Sao_Paulo";  # default TZ (GMT-3); projects can override
$pdf_mode = 5;    # 5 = xelatex
$xelatex = 'xelatex -interaction=nonstopmode %O %S';
