%% guide.cls
%% =====================================================================
%%  LaTeX class for Huawei Cloud guides
%%  Requires XeLaTeX or LuaLaTeX (due to fontspec).
%%
%%  Fonts:
%%    - Body : HarmonyOS Sans (fallback: Liberation Sans)
%%    - Code : Cascadia Code (fallback: DejaVu Sans Mono)
%%
%%  Class options:
%%    portuguese  -> uses Portuguese for predefined labels and babel.
%%                   (default: English)
%%    indentbody  -> indents all running text by \contentindent.
%%                   (default: off)
%%    notime      -> hides the compilation time on the cover.
%%                   (default: show time)
%%    nochangelog -> suppresses the changelog section entirely
%%                   and hides version/date/time on the cover page.
%%                   (default: show changelog)
%%    <any>       -> passed to the article class.
%% =====================================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{guide}[2026/08/17 Huawei Guide template]

% ---- Options --------------------------------------------------------
\newif\if@indentbody \@indentbodyfalse
\DeclareOption{indentbody}{\@indentbodytrue}
\newif\if@portuguese \@portuguesefalse
\DeclareOption{portuguese}{\@portuguesetrue}
\newif\if@showtime \@showtimetrue
\DeclareOption{notime}{\@showtimefalse}
\newif\if@changelog \@changelogtrue
\DeclareOption{nochangelog}{\@changelogfalse}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass[a4paper,10pt]{article}

% ---- Packages -------------------------------------------------------
\RequirePackage[a4paper,top=3cm,bottom=3cm,left=2cm,right=2cm,%
                headheight=1.4cm,headsep=0.7cm]{geometry}
\RequirePackage{fontspec}
\PassOptionsToPackage{table}{xcolor}
\RequirePackage{xcolor}
\RequirePackage{graphicx}
\RequirePackage{fancyhdr}
\RequirePackage{titlesec}
\RequirePackage[titles]{tocloft}
\RequirePackage{enumitem}
\RequirePackage{fancyvrb}
\RequirePackage{fvextra}
\RequirePackage[most]{tcolorbox}
\RequirePackage{booktabs}
\RequirePackage{array}
\RequirePackage{babel}
\if@portuguese
  \babelprovide[import,main]{brazilian}
\else
  \babelprovide[import,main]{english}
\fi
\RequirePackage{hyperref}
\RequirePackage{caption}
\captionsetup[figure]{font={small}, labelfont=bf, labelsep=colon}
\captionsetup[table]{font={small}, labelfont=bf, labelsep=colon}

% Float placement: force [H] (here, exactly) as the default for figure and
% table floats so they appear in source order and never drift to a later page.
% Requires the float package, which defines the H specifier.  Users can still
% override a single float with an explicit [h], [t], [b], or [p].
\RequirePackage{float}
\renewcommand{\fps@figure}{H}
\renewcommand{\fps@table}{H}

% =====================================================================
%  COLORS
% =====================================================================
\definecolor{codebg}{HTML}{F6F8FA}   % code block background
\definecolor{codetext}{HTML}{1F2328} % code text color
\definecolor{linkblue}{HTML}{0000FF} % hyperlinks (no underline)
\definecolor{huaweired}{HTML}{C7000B}% brand red (accents)
\definecolor{ruleblack}{HTML}{000000} % horizontal rule color (black)
\definecolor{warningbg}{HTML}{FFF8E1} % warning box background (light amber)
\definecolor{warningfg}{HTML}{F57C00} % warning box border (amber)
\definecolor{tipbg}{HTML}{E8F5E9}     % tip box background (light green)
\definecolor{tipfg}{HTML}{2E7D32}     % tip box border (green)
\definecolor{infobg}{HTML}{E3F2FD}    % info box background (light blue)
\definecolor{infofg}{HTML}{1565C0}    % info box border (blue)

% Table rules in Huawei red
\arrayrulecolor{huaweired}
% Table header cell: white bold text (for use with \rowcolor{huaweired})
\newcommand{\thd}[1]{\textcolor{white}{\textbf{#1}}}
% Table body: start alternating row colors (white / light gray).
% Used inside hutable, right after the header row's \\.
\newcommand{\tbody}{\rowcolors{2}{white}{codebg}}

% =====================================================================
%  TABLES — hutable environment
%  Full-grid tables: red rules on all four sides and between every row,
%  Huawei-red header bar (white bold text), and alternating white / light-gray
%  body rows.
%
%  Usage:
%    \begin{table}[H]
%      \begin{hutable}{|l|l|l|}
%        \rowcolor{huaweired} \thd{Col A} & \thd{Col B} & \thd{Col C} \\
%        \tbody
%        row 1 & value & value \\
%        row 2 & value & value \\
%      \end{hutable}
%      \caption{Caption text.}
%    \end{table}
%
%  - \centering\small is applied automatically (do not add it yourself).
%  - Do not add \hline, \midrule, or \bottomrule — the environment draws the
%    full grid (red rules on all four sides and between every row) for you.
%  - Header row: \rowcolor{huaweired} + \thd{...} per cell (white bold on red),
%    ended by \\.
%  - After the header \\, add \tbody to start alternating body row colors
%    (white / light gray).
%  - Body rows: plain cells, black text on alternating white / codebg rows.
%  - Every row MUST end with \\ (including the last) so the bottom border draws.
%
%  Implementation: a scoped redefinition of \@arraycr inserts an \hline after
%  each row break to form the horizontal grid.  \hline (not booktabs \midrule)
%  is required so colortbl \rowcolor fills the row background cleanly up to the
%  rule — \midrule's \aboverulesep/\belowrulesep padding leaves uncolored gaps.
%  The redefinition is local to the environment (begingroup/endgroup), so it
%  does not affect other tabulars.  \par is emitted inside the centered group so
%  the tabular is horizontally centered.
\newenvironment{hutable}[1]{%
  \par\medskip
  \begingroup
    \centering\small
    \let\lg@arraycr\@arraycr
    \def\@arraycr{\lg@arraycr\hline}%
    \begin{tabular}{#1}\hline
}{%
    \end{tabular}\par
  \endgroup
  \medskip
}

% =====================================================================
%  FONTS  (with automatic fallback if brand fonts are missing)
% =====================================================================
\newcommand{\lg@warnfont}[2]{%
  \ClassWarning{guide}{Font "#1" not found; using fallback "#2".
    Install the font for full fidelity.}}

% Main font: HarmonyOS Sans (required) -> Liberation Sans (sole fallback)
% AutoFakeSlant: HarmonyOS Sans has no italic; synthesize one from upright.
\IfFontExistsTF{HarmonyOS Sans}
  {\setmainfont{HarmonyOS Sans}[AutoFakeSlant=0.2]}
   {\lg@warnfont{HarmonyOS Sans}{Liberation Sans}%
    \setmainfont{Liberation Sans}}

% Code font: Cascadia Code (required) -> DejaVu Sans Mono (sole fallback)
% AutoFakeSlant: Cascadia Code has no italic; synthesize one from upright.
% Contextuals=NoAlternate: disable calt (programming ligatures like //, =>, ==)
%   which break PDF copy-paste (ligated glyphs get wrong ToUnicode mappings).
\IfFontExistsTF{Cascadia Code}
  {\newfontfamily\consolasfont{Cascadia Code}[Ligatures=NoCommon, Contextuals=NoAlternate, AutoFakeSlant=0.2]}
  {\lg@warnfont{Cascadia Code}{DejaVu Sans Mono}%
   \newfontfamily\consolasfont{DejaVu Sans Mono}[Ligatures=NoCommon]}
\newcommand{\codefont}{\consolasfont}

% Base body size: 10.5pt with ~14pt leading
\renewcommand\normalsize{\@setfontsize\normalsize{10.5}{14}}
\normalsize
\setlength{\parindent}{0pt}
\setlength{\parskip}{4pt}      % space between paragraphs
\frenchspacing                % no extra space after period

% Optional body indent ([indentbody] option)
\newlength{\contentindent}\setlength{\contentindent}{0.6cm}
\if@indentbody
  \AtBeginDocument{\setlength{\leftskip}{\contentindent}}
\fi

% =====================================================================
%  LANGUAGE  (predefined labels per [portuguese] option)
% =====================================================================
\if@portuguese
  \newcommand{\lg@toc}{Sumário}
  \newcommand{\lg@generalobjectivelabel}{Objetivo Geral:}
  \newcommand{\lg@objectivelabel}{Objetivo:}
  \newcommand{\lg@prerequisiteslabel}{Pré-requisitos:}
  \newcommand{\lg@stepbysteplabel}{Passo a passo:}
  \newcommand{\lg@pagelabel}{Página}
  \newcommand{\lg@guidetitle}{Guia}
  \newcommand{\lg@warninglabel}{Importante}
  \newcommand{\lg@tiplabel}{Dica}
  \newcommand{\lg@infolabel}{Informação}
  \newcommand{\lg@changelogtitle}{Histórico de versões}
\else
  \newcommand{\lg@toc}{Contents}
  \newcommand{\lg@generalobjectivelabel}{General Objective:}
  \newcommand{\lg@objectivelabel}{Objective:}
  \newcommand{\lg@prerequisiteslabel}{Prerequisites:}
  \newcommand{\lg@stepbysteplabel}{Step by step:}
  \newcommand{\lg@pagelabel}{Page}
  \newcommand{\lg@guidetitle}{Guide}
  \newcommand{\lg@warninglabel}{Important}
  \newcommand{\lg@tiplabel}{Tip}
  \newcommand{\lg@infolabel}{Info}
  \newcommand{\lg@changelogtitle}{Changelog}
\fi

% =====================================================================
%  HYPERREF  (blue links, no underline)
% =====================================================================
\hypersetup{
  colorlinks=true,
  linkcolor=black,      % internal links (TOC) in black
  urlcolor=linkblue,
  citecolor=linkblue,
  linktoc=all,
  bookmarksnumbered=true,
}

% =====================================================================
%  HEADER AND FOOTER
% =====================================================================
% Configurable header title: \setheadertitle{...}
\newcommand{\lg@headertitle}{Huawei Cloud}
\newcommand{\setheadertitle}[1]{\renewcommand{\lg@headertitle}{#1}}
\newcommand{\lg@headerlogo}{common-assets/huawei-logo-header.png}
\newcommand{\setheaderlogo}[1]{\renewcommand{\lg@headerlogo}{#1}}

\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}
% Header: logo (left) + title (center)
% Footer: "Page N" (center)
\fancyhead[L]{\raisebox{-0.35cm}[0pt][0pt]{%
    \includegraphics[height=1.05cm]{\lg@headerlogo}}}
\fancyhead[C]{\normalfont\fontsize{10}{12}\selectfont \lg@headertitle}
\fancyfoot[C]{\normalfont\fontsize{10}{12}\selectfont \lg@pagelabel~\thepage}

% Plain style: no header, page number in footer (for TOC, changelog)
\fancypagestyle{plain}{
  \fancyhf{}
  \renewcommand{\headrulewidth}{0pt}
  \renewcommand{\footrulewidth}{0pt}
  \fancyfoot[C]{\normalfont\fontsize{10}{12}\selectfont \lg@pagelabel~\thepage}
}

% =====================================================================
%  TITLES (headings)
% =====================================================================
\setcounter{secnumdepth}{4}

% --- H1: big number (56pt) left-aligned + 20pt bold right-aligned title + rule
\titleformat{\section}[block]
  {\normalfont\bfseries\fontsize{20}{25}\selectfont}
  {\fontsize{56}{56}\selectfont\thesection}
  {0pt}
  {\hfill}
  [\vspace{2pt}{\color{huaweired}\titlerule[1.5pt]}\vspace{14pt}]
\titlespacing*{\section}{0pt}{0pt}{30pt} % before 0 / after 30pt
% Each \section (chapter) starts on a new page
\let\lg@origsection\section
\renewcommand{\section}{\clearpage\lg@origsection}

% --- H2/H3/H4: regular, decreasing sizes, left-aligned
\titleformat{\subsection}
  {\normalfont\fontsize{18}{22}\selectfont}{\thesubsection}{0.4em}{}
\titlespacing*{\subsection}{0pt}{30pt}{6pt}

\titleformat{\subsubsection}
  {\normalfont\fontsize{16}{20}\selectfont}{\thesubsubsection}{0.4em}{}
\titlespacing*{\subsubsection}{0pt}{10pt}{4pt}

\titleformat{\paragraph}[hang]
  {\normalfont\fontsize{14}{18}\selectfont}{\theparagraph}{0.4em}{}
\titlespacing*{\paragraph}{0pt}{8pt}{4pt}

% Numbering: 1  /  1.1  /  1.1.1  /  1.1.1.1
\renewcommand{\thesection}{\arabic{section}}
\renewcommand{\thesubsection}{\thesection.\arabic{subsection}}
\renewcommand{\thesubsubsection}{\thesubsection.\arabic{subsubsection}}
\renewcommand{\theparagraph}{\thesubsubsection.\arabic{paragraph}}

% =====================================================================
%  TABLE OF CONTENTS — right-aligned title + rule; dotted leaders
% =====================================================================
\renewcommand{\contentsname}{\lg@toc}
\renewcommand{\cfttoctitlefont}{\hfill\normalfont\bfseries\fontsize{22}{26}\selectfont}
\renewcommand{\cftaftertoctitle}{\par\vspace{2pt}%
  {\color{ruleblack}\hrule height 0.5pt}\vspace{6pt}}
% Level 1: bold 12pt
\renewcommand{\cftsecfont}{\bfseries\fontsize{12}{15}\selectfont}
\renewcommand{\cftsecpagefont}{\bfseries\fontsize{12}{15}\selectfont}
\renewcommand{\cftsecleader}{\bfseries\cftdotfill{\cftdotsep}}
% Levels 2 and 3: normal 10pt
\renewcommand{\cftsubsecfont}{\fontsize{10}{13}\selectfont}
\renewcommand{\cftsubsecpagefont}{\fontsize{10}{13}\selectfont}
\renewcommand{\cftsubsubsecfont}{\fontsize{10}{13}\selectfont}
\renewcommand{\cftsubsubsecpagefont}{\fontsize{10}{13}\selectfont}
% TOC indents starting at the margin (ind left=0)
\setlength{\cftsecindent}{0pt}
\setlength{\cftsubsecindent}{1.2em}
\setlength{\cftsubsubsecindent}{2.4em}
\setlength{\cftbeforesecskip}{4pt}
\renewcommand{\cftdotsep}{1.2}
% show dotted leaders also at level 1
\setcounter{tocdepth}{3}

% Convenience command for TOC (resets leftskip)
\newcommand{\maketoc}{{\leftskip=0pt\relax\pagestyle{plain}\thispagestyle{plain}\tableofcontents}\clearpage}

% =====================================================================
%  COVER
% =====================================================================
% \setguidetitle{...}  -> large cover title (and default header)
\newcommand{\setguidetitle}[1]{\renewcommand{\lg@guidetitle}{#1}}
\newcommand{\lg@covertext}{Huawei Technologies CO., LTD}
\newcommand{\setcovertext}[1]{\renewcommand{\lg@covertext}{#1}}
\newcommand{\lg@coverlogo}{common-assets/huawei-logo-cover.png}
\newcommand{\setcoverlogo}[1]{\renewcommand{\lg@coverlogo}{#1}}
\newcommand{\lg@docversion}{}
\newcommand{\setdocversion}[1]{\renewcommand{\lg@docversion}{#1}}
\newcommand{\lg@docdate}{\today}
\newcommand{\setdocdate}[1]{\renewcommand{\lg@docdate}{#1}}
% Compilation time from \time primitive (minutes since midnight, respects TZ)
\providecommand{\two@digits}[1]{\ifnum#1<10 0\fi\number#1}
\newcount\lg@hour
\newcount\lg@min
\newcount\lg@tmp
\lg@hour=\time
\divide\lg@hour by 60
\lg@tmp=\lg@hour
\multiply\lg@tmp by 60
\lg@min=\time
\advance\lg@min by -\lg@tmp
\newcommand{\lg@covermeta}{%
  \ifx\lg@docversion\@empty\else\textbf{v\lg@docversion}\fi
  \ifx\lg@docversion\@empty\else\ifx\lg@docdate\@empty\else\ — \fi\fi
  \ifx\lg@docdate\@empty\else\lg@docdate\fi
  \if@showtime\ \two@digits{\lg@hour}:\two@digits{\lg@min}\fi%
}

\newcommand{\makecover}{%
  \begingroup
  \leftskip=0pt\relax
  \thispagestyle{empty}%
  \vspace*{2.2cm}%
  {\centering
   \fontsize{36}{42}\selectfont\bfseries \lg@guidetitle\par}%
  \vspace{4.5cm}%
  {\centering
   \includegraphics[width=3.6cm]{\lg@coverlogo}\par}%
  \vspace{0.9cm}%
   {\centering
    \fontsize{16}{20}\selectfont \lg@covertext\par}%
   \vspace{0.5cm}%
   {\centering
    \fontsize{12}{14}\selectfont \if@changelog\lg@covermeta\fi\par}%
   \endgroup
  \clearpage}

% =====================================================================
%  BODY — resets page numbering
% =====================================================================
\newcommand{\startbody}{\clearpage\pagestyle{fancy}\thispagestyle{fancy}\setcounter{page}{1}}

% =====================================================================
%  OBJECTIVES / PREREQUISITES BLOCK  (closed by 1.5pt rule)
% =====================================================================
% Usage:
%   \begin{objectives}
%     \generalobjective{...}
%     \prerequisites
%       \item ...
%   \end{objectives}
\newcommand{\lg@label}[1]{\textbf{#1}}
\newcommand{\generalobjective}[1]{\par\lg@label{\lg@generalobjectivelabel} #1\par}
\newcommand{\objective}[1]{\par\lg@label{\lg@objectivelabel} #1\par}
\newcommand{\stepbystep}{\par\lg@label{\lg@stepbysteplabel}\par}
\newcommand{\prerequisites}{\par\lg@label{\lg@prerequisiteslabel}\par}

\newenvironment{objectives}
  {\par\medskip}
  {\par\vspace{4pt}%
   {\leftskip=0pt\relax\noindent{\color{ruleblack}\rule{\linewidth}{1.5pt}}}%
   \par\vspace{10pt}}

% =====================================================================
%  LISTS  (bullets and numbered, in document style)
% =====================================================================
\setlist[itemize]{leftmargin=1.6em,topsep=2pt,itemsep=2pt,parsep=0pt}
\setlist[enumerate]{leftmargin=1.8em,topsep=2pt,itemsep=2pt,parsep=0pt}

% =====================================================================
%  CODE  (fancyvrb + fvextra — clean PDF copy-paste)
% =====================================================================
% No-op keys for language hints ([bash], [python], etc.) — ignored,
% kept for backward compatibility with existing documents.
\newcommand{\lg@deflangkey}[1]{\define@key{FV}{#1}[unused]{}}
\forcsvlist{\lg@deflangkey}{bash,sh,shell,python,Python,json,yaml,xml,html,javascript,js,sql,text,ini,conf}

% Code block: #F6F8FA background, no border, left indented
% Uses fancyvrb (not listings) for clean copy-paste in PDF.
% listings processes character by character -> xdvipdfmx writes each
% one as a separate text operation -> PDF readers insert spaces.
% fancyvrb typesets line by line -> contiguous text in PDF -> clean copy.
\DefineVerbatimEnvironment{code}{Verbatim}
{fontsize=\fontsize{10}{13}\selectfont, formatcom=\codefont\color{codetext},
 frame=none,
 backgroundcolor=codebg,
 xleftmargin=0.7cm, xrightmargin=0.5cm,
 breaklines=true, breakanywhere=true,
 breaksymbolleft={}, breaksymbolright={},
 breakanywheresymbolpre={}, breakanywheresymbolpost={},
}

% Code block from external file
\newcommand{\codefile}[2][]{%
  \IfFileExists{#2}{%
    \VerbatimInput[fontsize=\fontsize{10}{13}\selectfont,
     formatcom=\codefont\color{codetext},
     frame=none,
     backgroundcolor=codebg,
     xleftmargin=0.7cm, xrightmargin=0.5cm,
     breaklines=true, breakanywhere=true,
     breaksymbolleft={}, breaksymbolright={},
     breakanywheresymbolpre={}, breakanywheresymbolpost={}]{#2}%
  }{\ClassWarning{guide}{Code file "#2" not found.
    Check the path (relative to TEXINPUTS) and that the file exists.}}%
}

% Inline code: \inlinecode{...}
\newcommand{\inlinecode}[1]{{\codefont\fontsize{10}{12}\selectfont\color{codetext}#1}}
% File/parameter name in text (italic)
\newcommand{\param}[1]{\textit{#1}}

% =====================================================================
%  IMAGES  — always horizontally centered, with key-value sizing options
% =====================================================================
% Key-value options for image sizing:
%   width  — horizontal size (default 0.9\linewidth)
%   height — vertical size   (default 0.5\textheight)
% Both are upper bounds; keepaspectratio preserves the image's aspect ratio.
\define@key{guideimg}{width}{\def\guide@img@width{#1}}
\define@key{guideimg}{height}{\def\guide@img@height{#1}}

% \image[options]{file}   (no caption)
% Example: \image[width=0.8\linewidth]{assets/screenshot.png}
%          \image[height=0.3\textheight]{assets/tall-chart.png}
%          \image[width=0.9\linewidth, height=0.5\textheight]{assets/big.png}
\newcommand{\image}[2][]{%
  \def\guide@img@width{0.9\linewidth}%
  \def\guide@img@height{0.5\textheight}%
  \setkeys{guideimg}{#1}%
  \IfFileExists{#2}{}{\ClassWarning{guide}{Image "#2" not found.
    Check the path (relative to TEXINPUTS) and that the file exists.}}%
  \par\medskip
  {\leftskip=0pt\rightskip=0pt\parindent=0pt\centering
   \includegraphics[width=\guide@img@width,height=\guide@img@height,keepaspectratio]{#2}\par}%
  \medskip}

% \imagecap[options]{file}{caption}  (with numbered caption — Figure N)
% Same options as \image.  Do not include "Figure N" in the caption —
% the class adds it automatically.
\newcommand{\imagecap}[3][]{%
  \def\guide@img@width{0.9\linewidth}%
  \def\guide@img@height{0.5\textheight}%
  \setkeys{guideimg}{#1}%
  \IfFileExists{#2}{}{\ClassWarning{guide}{Image "#2" not found.
    Check the path (relative to TEXINPUTS) and that the file exists.}}%
  \par\medskip
  {\leftskip=0pt\rightskip=0pt\parindent=0pt\centering
   \includegraphics[width=\guide@img@width,height=\guide@img@height,keepaspectratio]{#2}\par
   \vspace{2pt}\captionof{figure}{#3}\par}%
  \medskip}

% \imageplaceholder{path}{description}
% Shows a placeholder box indicating where the user should place the image.
% The user adds the file manually at the indicated path.
\newcommand{\imageplaceholder}[2]{%
  \par\medskip
  \begin{tcolorbox}[
    colback=codebg, colframe=warningfg,
    boxrule=1pt, arc=4pt, outer arc=4pt,
    left=12pt, right=12pt, top=10pt, bottom=10pt,
    before skip=8pt, after skip=8pt,
    breakable, enhanced jigsaw]
    \centering
    {\codefont\color{codetext}\fontsize{11}{13}\selectfont
     [ Image placeholder ]}\\[6pt]
    {\footnotesize\color{codetext}
     \textbf{File:} \inlinecode{#1}}\\[4pt]
    {\footnotesize\color{codetext}
     \textbf{Description:} #2}\\[6pt]
    {\footnotesize\itshape\color{warningfg}
     Place the image file at the path above, then replace this command with
     \inlinecode{\textbackslash image\{#1\}} or
     \inlinecode{\textbackslash imagecap\{#1\}\{caption\}}.}
  \end{tcolorbox}
  \par\medskip}

% =====================================================================
%  NOTE  (italic text)
% =====================================================================
\newcommand{\note}[1]{\par\medskip\textit{#1}\par\medskip}

% Blue text link (no underline), preserving clickable destination
\newcommand{\weblink}[2]{\href{#1}{\textcolor{linkblue}{#2}}}

% Menu path: \menu{VPC, Security Groups} -> **VPC** -> **Security Groups**
% Uses etoolbox's \forcsvlist (loaded by tcolorbox[most])
\newtoks\lg@menutoks
\newif\iflg@menufirst
\newcommand{\menu}[1]{%
  \lg@menufirsttrue
  \lg@menutoks={}%
  \forcsvlist{\lg@menuitem}{#1}%
  \the\lg@menutoks}
\newcommand{\lg@menuitem}[1]{%
  \iflg@menufirst\else
    \lg@menutoks=\expandafter{\the\lg@menutoks\ $\rightarrow$\ }%
  \fi
  \lg@menufirstfalse
  \lg@menutoks=\expandafter{\the\lg@menutoks\textbf{#1}}}

% =====================================================================
%  CALLOUT BOXES  (warning, tip, infobox)
% =====================================================================
% Usage:
%   \begin{warning} ... \end{warning}   — caution / warning (amber)
%   \begin{tip}     ... \end{tip}       — suggestion / tip (green)
%   \begin{infobox} ... \end{infobox}   — additional info (blue)
\newcommand{\lg@callout}[5]{%
  \newtcolorbox{#1}{colback=#2, colframe=#3,
    before upper={\textbf{\color{#4}#5}\par\smallskip},
    boxrule=0pt, leftrule=3pt, arc=0pt, outer arc=0pt,
    left=8pt, right=8pt, top=6pt, bottom=6pt,
    before skip=6pt, after skip=6pt, breakable, enhanced jigsaw}}
\lg@callout{warning}{warningbg}{warningfg}{huaweired}{\lg@warninglabel}
\lg@callout{tip}{tipbg}{tipfg}{tipfg}{\lg@tiplabel}
\lg@callout{infobox}{infobg}{infofg}{infofg}{\lg@infolabel}

% =====================================================================
%  BADGE  (inline colored label)
% =====================================================================
% Usage: \badge{New}  -> red label with white text
\newcommand{\badge}[1]{%
  \colorbox{huaweired}{\textcolor{white}{\footnotesize\bfseries\strut~#1~}}}

% =====================================================================
%  CHANGELOG / VERSIONING
% =====================================================================
% Usage:
%   \setdocversion{1.0.0}       % shows "v1.0.0" on cover
%   \setdocdate{2026-08-05}     % optional; default = \today
%
%   \begin{changelog}
%     \changelogentry{1.0.0}{2026-08-05}{
%       \item Initial version
%       \item Added ECS provisioning
%     }
%     \changelogentry{0.9.0}{2025-07-15}{
%       \item Draft
%     }
%   \end{changelog}
%
%  The environment emits the section heading (language-aware: "Changelog" /
%  "Histórico de versões") automatically -- do not add a \section before it.
%  [nochangelog] suppresses the heading and all entries in one switch.
\newenvironment{changelog}{%
  \section{\lg@changelogtitle}%
  \par\medskip
  \thispagestyle{plain}\pagestyle{plain}%
  \noindent{\color{ruleblack}\rule{\linewidth}{0.5pt}}\par
  \vspace{6pt}
}{%
  \par\medskip
  \noindent{\color{ruleblack}\rule{\linewidth}{0.5pt}}\par
  \medskip
  \pagestyle{fancy}%
}
\newcommand{\changelogentry}[3]{%
  \par\smallskip
  \noindent\textbf{#1}\hfill\textit{#2}\par\nobreak\vspace{2pt}
  \begingroup\leftskip=1.2cm\relax
  \begin{itemize}[leftmargin=1.2em,topsep=0pt,itemsep=1pt,parsep=0pt]
    #3
  \end{itemize}
  \endgroup
}

% Disable changelog when [nochangelog] option is active.
% The environment and entries become no-ops (content is absorbed, nothing rendered).
\if@changelog\else
  \renewenvironment{changelog}{}{}
  \renewcommand{\changelogentry}[3]{\ignorespaces}
\fi

\endinput
