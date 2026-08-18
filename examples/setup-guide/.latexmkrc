# latexmkrc — project folder, template at ../../templates/guide/
$ENV{TEXINPUTS} = "../../templates/_base/:../../templates/guide/:" . ($ENV{TEXINPUTS} || "");
$ENV{TZ} = "America/Sao_Paulo";  # GMT-3 — so \today matches local date
$pdf_mode = 5;    # 5 = xelatex
$xelatex = 'xelatex -interaction=nonstopmode %O %S';
