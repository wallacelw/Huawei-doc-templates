--- guide-pandoc.lua
--- =====================================================================
---  Pandoc Lua filter for the Huawei guide.cls template.
---  Translates custom commands and environments to DOCX, Markdown, and HTML5.
---
---  Usage:
---    pandoc --lua-filter=guide-pandoc.lua -f latex+raw_tex -t docx  input.tex
---    pandoc --lua-filter=guide-pandoc.lua -f latex+raw_tex -t markdown input.tex
---    pandoc --lua-filter=guide-pandoc.lua -f latex+raw_tex -t html5  input.tex
---
---  Requires pandoc >= 3.0 (Table Cell/Row API).
---  Most features work with pandoc >= 2.9; hutable requires >= 3.0.
--- =====================================================================

-- =====================================================================
--  Language labels (English / Portuguese)
-- =====================================================================
local labels = {
  en = {
    warning     = "Important",
    tip         = "Tip",
    infobox     = "Info",
    genobj      = "General Objective:",
    obj         = "Objective:",
    prereq      = "Prerequisites:",
    stepbystep  = "Step by step:",
    changelog   = "Changelog",
  },
  pt = {
    warning     = "Importante",
    tip         = "Dica",
    infobox     = "Informação",
    genobj      = "Objetivo Geral:",
    obj         = "Objetivo:",
    prereq      = "Pré-requisitos:",
    stepbystep  = "Passo a passo:",
    changelog   = "Histórico de versões",
  },
}

-- Active language: "en" or "pt" (set by documentclass option detection)
local lang = "en"

-- Convenience: return the label for the current language
local function L(key)
  return labels[lang][key] or key
end

-- =====================================================================
--  Utility helpers
-- =====================================================================

--- Trim leading/trailing whitespace from a string.
local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Read a file's contents, returning nil on failure.
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

--- Parse balanced-brace argument from position after opening brace.
--- Returns (content, end_pos) or (nil, nil).
--- Handles nested braces: \foo{a{b}c} → "a{b}c"
local function parse_brace_arg(text, start)
  local depth = 1  -- start at 1: we are already inside the opening brace
  local i = start
  while i <= #text do
    local c = text:sub(i, i)
    if c == "{" then
      depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
      if depth == 0 then
        return text:sub(start, i - 1), i
      end
    elseif c == "\\" and i < #text then
      -- Skip the next character after backslash (escaped char or command)
      i = i + 1
    end
    i = i + 1
  end
  return nil, nil
end

--- Find a command in text: \cmdname{arg}. Returns arg content or nil.
local function find_cmd_arg(text, cmd)
  local pattern = "\\" .. cmd .. "%s*{"
  local start = text:find(pattern)
  if not start then return nil end
  -- Find the opening brace
  local brace_pos = text:find("{", start)
  if not brace_pos then return nil end
  local content, _ = parse_brace_arg(text, brace_pos + 1)
  return content
end

--- Find all occurrences of \cmd{arg} in text.
--- Returns a table of arg strings.
local function find_all_cmd_args(text, cmd)
  local results = {}
  local pattern = "\\" .. cmd .. "%s*{"
  local pos = 1
  while true do
    local start = text:find(pattern, pos)
    if not start then break end
    local brace_pos = text:find("{", start)
    if not brace_pos then break end
    local content, end_pos = parse_brace_arg(text, brace_pos + 1)
    if content then
      table.insert(results, content)
      pos = (end_pos or brace_pos) + 1
    else
      break
    end
  end
  return results
end

-- Forward declaration: set after RawInline/RawBlock are defined.
-- Used by parse_latex_blocks/parse_latex_inlines to walk parsed content.
local inner_filter = nil

--- Pre-process LaTeX text to replace custom commands with standard LaTeX
--- that pandoc.read understands.  Unknown commands like \inlinecode are
--- consumed by pandoc.read rather than preserved as RawInline, so we must
--- translate them before parsing.
local function preprocess_latex(text)
  -- \inlinecode{...} → \texttt{...}
  text = text:gsub("\\inlinecode%s*(%b{})", function(arg)
    return "\\texttt{" .. arg:sub(2, -2) .. "}"
  end)
  -- \param{...} → \textit{...}
  text = text:gsub("\\param%s*(%b{})", function(arg)
    return "\\textit{" .. arg:sub(2, -2) .. "}"
  end)
  -- \badge{...} → \textbf{[...]}
  text = text:gsub("\\badge%s*(%b{})", function(arg)
    return "\\textbf{[" .. arg:sub(2, -2) .. "]}"
  end)
  -- \menu{A, B, C} → \textbf{A} $\rightarrow$ \textbf{B} $\rightarrow$ \textbf{C}
  text = text:gsub("\\menu%s*(%b{})", function(arg)
    local content = arg:sub(2, -2)
    local parts = {}
    for item in content:gmatch("([^,]+)") do
      item = trim(item)
      if item ~= "" then
        table.insert(parts, "\\textbf{" .. item .. "}")
      end
    end
    return table.concat(parts, " \\textbf{→} ")
  end)
  -- \weblink{url}{text} → \href{url}{text}
  text = text:gsub("\\weblink%s*(%b{})%s*(%b{})", function(url_arg, text_arg)
    return "\\href{" .. url_arg:sub(2, -2) .. "}{" .. text_arg:sub(2, -2) .. "}"
  end)
  -- \note{...} → \textit{Note: ...}
  text = text:gsub("\\note%s*(%b{})", function(arg)
    return "\\textit{Note: " .. arg:sub(2, -2) .. "}"
  end)
  return text
end

--- Parse inner LaTeX content into pandoc Blocks using pandoc.read.
--- Walks the result with inner_filter to process any raw LaTeX inside.
local function parse_latex_blocks(content)
  content = preprocess_latex(content)
  local ok, result = pcall(pandoc.read, content, "latex")
  if ok and result then
    if inner_filter then
      local walked = pandoc.Blocks({})
      for _, blk in ipairs(result.blocks) do
        walked:insert(pandoc.walk_block(blk, inner_filter))
      end
      return walked
    end
    return result.blocks
  end
  -- Fallback: treat as plain text paragraphs
  return {pandoc.Para(pandoc.Str(content))}
end

--- Parse inner LaTeX content into pandoc Inlines.
--- Walks the result with inner_filter to process any raw LaTeX inside.
local function parse_latex_inlines(content)
  content = preprocess_latex(content)
  local ok, result = pcall(pandoc.read, content, "latex")
  if ok and result then
    -- Flatten blocks into inlines (join with space)
    local inlines = pandoc.Inlines({})
    for _, block in ipairs(result.blocks) do
      local blk = block
      if inner_filter then
        blk = pandoc.walk_block(block, inner_filter)
      end
      if blk.t == "Para" then
        inlines:extend(blk.content)
      elseif blk.t == "Plain" then
        inlines:extend(blk.content)
      end
    end
    return inlines
  end
  return pandoc.Inlines({pandoc.Str(content)})
end

--- Create a format-appropriate callout box.
--- @param cls string: "warning", "tip", or "infobox"
--- @param label string: display label (e.g. "Important")
--- @param content pandoc.Blocks: parsed inner content
local function make_callout(cls, label, content)
  -- Prepend the bold label as a paragraph
  local label_para = pandoc.Para({
    pandoc.Strong({pandoc.Str(label)}),
    pandoc.Str(" "),
  })

  if FORMAT:match("docx") then
    -- DOCX: Div with class attribute
    local div_content = pandoc.Blocks({label_para})
    div_content:extend(content)
    return pandoc.Div(div_content, pandoc.Attr("", {cls}, {}))

  elseif FORMAT:match("markdown") then
    -- Markdown: BlockQuote with **Label:** prefix
    -- Avoid double colon if label already ends with ":"
    local label_text = label
    if not label_text:match(":$") then
      label_text = label_text .. ":"
    end
    local label_inline = pandoc.Inlines({
      pandoc.Strong({pandoc.Str(label_text)}),
      pandoc.Space(),
    })
    local quote_blocks = pandoc.Blocks({})
    -- Add label to first paragraph if possible
    if #content > 0 and content[1].t == "Para" then
      local first_para = pandoc.Para(label_inline:clone())
      first_para.content:extend(content[1].content)
      quote_blocks:insert(first_para)
      for i = 2, #content do
        quote_blocks:insert(content[i])
      end
    else
      quote_blocks:insert(pandoc.Para(label_inline))
      quote_blocks:extend(content)
    end
    return pandoc.BlockQuote(quote_blocks)

  else
    -- HTML5 (and fallback): Div with callout class
    local div_content = pandoc.Blocks({label_para})
    div_content:extend(content)
    return pandoc.Div(div_content, pandoc.Attr("", {"callout", cls}, {}))
  end
end

-- =====================================================================
--  Document-level: Pandoc handler
--  Read the source .tex file to extract metadata and language option.
-- =====================================================================

-- Commands to strip from the document body (preamble setters + structural)
local strip_commands = {
  ["setguidetitle"]  = true,
  ["setheadertitle"] = true,
  ["setcovertext"]   = true,
  ["setheaderlogo"]  = true,
  ["setcoverlogo"]   = true,
  ["setdocversion"]  = true,
  ["setdocdate"]     = true,
  ["makecover"]      = true,
  ["maketoc"]        = true,
  ["startbody"]      = true,
}

function Pandoc(doc)
  -- -----------------------------------------------------------------
  --  Detect language from source file
  -- -----------------------------------------------------------------
  local source_path = nil
  if PANDOC_STATE and PANDOC_STATE.input_files then
    -- pandoc >= 2.12: PANDOC_STATE.input_files is a list
    for _, f in ipairs(PANDOC_STATE.input_files) do
      source_path = f
      break
    end
  end

  if source_path then
    local src = read_file(source_path)
    if src then
      -- Detect \documentclass[portuguese]{guide}
      if src:find("\\documentclass%s*%[.*portuguese.*%]%s*{guide}") then
        lang = "pt"
      end

      -- Extract metadata: \setguidetitle{...}
      local title = find_cmd_arg(src, "setguidetitle")
      if title then
        local current_title = doc.meta.title
        if not current_title or (type(current_title) == "table" and #current_title == 0) then
          doc.meta.title = pandoc.Inlines({pandoc.Str(title)})
        end
      end

      -- Extract metadata: \setdocversion{...}
      local version = find_cmd_arg(src, "setdocversion")
      if version then
        doc.meta["doc-version"] = version
      end

      -- Extract metadata: \setdocdate{...}
      local date = find_cmd_arg(src, "setdocdate")
      if date then
        -- Replace \today with the current date
        date = date:gsub("\\today", os.date("%Y-%m-%d"))
        doc.meta.date = date
      end
    end
  end

  -- -----------------------------------------------------------------
  --  Strip structural/preamble commands from the body
  -- -----------------------------------------------------------------
  local function strip_from_inlines(inlines)
    local new_inlines = pandoc.Inlines({})
    local i = 1
    while i <= #inlines do
      local inl = inlines[i]
      if inl.t == "RawInline" and inl.format == "latex" then
        local text = inl.text
        -- Check each strip command
        local skip = false
        for cmd, _ in pairs(strip_commands) do
          if text:match("^%s*\\" .. cmd .. "%s*%[") or
             text:match("^%s*\\" .. cmd .. "%s*{") or
             text:match("^%s*\\" .. cmd .. "%s*$") then
            skip = true
            break
          end
        end
        if not skip then
          new_inlines:insert(inl)
        end
      else
        new_inlines:insert(inl)
      end
      i = i + 1
    end
    return new_inlines
  end

  local function strip_from_blocks(blocks)
    local new_blocks = pandoc.Blocks({})
    for _, blk in ipairs(blocks) do
      if blk.t == "RawBlock" and blk.format == "latex" then
        local text = blk.text
        local skip = false
        for cmd, _ in pairs(strip_commands) do
          if text:match("^%s*\\" .. cmd .. "%s*%[") or
             text:match("^%s*\\" .. cmd .. "%s*{") or
             text:match("^%s*\\" .. cmd .. "%s*$") then
            skip = true
            break
          end
        end
        if not skip then
          new_blocks:insert(blk)
        end
      else
        -- Recurse into block content
        if blk.t == "Para" then
          blk.content = strip_from_inlines(blk.content)
        elseif blk.t == "Plain" then
          blk.content = strip_from_inlines(blk.content)
        elseif blk.t == "Div" then
          blk.content = strip_from_blocks(blk.content)
        elseif blk.t == "BlockQuote" then
          blk.content = strip_from_blocks(blk.content)
        elseif blk.t == "BulletList" then
          -- pandoc 3.x: items are single Block elements
          for i, item in ipairs(blk.content) do
            if item.t == "Para" or item.t == "Plain" then
              item.content = strip_from_inlines(item.content)
            end
          end
        elseif blk.t == "OrderedList" then
          -- blk.content[1] is the list items, blk.content[2] is the list attrs
          -- pandoc 3.x: items are single Block elements
          for i, item in ipairs(blk.content[1]) do
            if item.t == "Para" or item.t == "Plain" then
              item.content = strip_from_inlines(item.content)
            end
          end
        end
        new_blocks:insert(blk)
      end
    end
    return new_blocks
  end

  doc.blocks = strip_from_blocks(doc.blocks)

  -- -----------------------------------------------------------------
  --  Promote \codefile Code inlines to CodeBlocks
  --  When \codefile appears inline in a Para, the RawInline handler
  --  returns pandoc.Code with a "codefile" class. Multi-line code
  --  content should be a fenced code block, not inline code.
  --  Walk blocks: find Para containing Code with "codefile" class,
  --  split the Para, and insert a CodeBlock.
  -- -----------------------------------------------------------------
  local function promote_codefile_inlines(blocks)
    local new_blocks = pandoc.Blocks({})
    for _, blk in ipairs(blocks) do
      if blk.t == "Para" then
        -- Collect all Code inlines with "codefile" class
        local codefile_positions = {}

        for i, inl in ipairs(blk.content) do
          if inl.t == "Code" then
            local has_codefile = false
            for _, cls in ipairs(inl.classes) do
              if cls == "codefile" then has_codefile = true end
            end
            if has_codefile then
              -- Build classes list without the "codefile" marker
              local codefile_classes = {}
              for _, cls in ipairs(inl.classes) do
                if cls ~= "codefile" then
                  table.insert(codefile_classes, cls)
                end
              end
              table.insert(codefile_positions, {
                idx = i,
                text = inl.text,
                classes = codefile_classes,
              })
            end
          end
        end

        if #codefile_positions > 0 then
          -- Split the Para into multiple blocks at each codefile position
          local prev_end = 0
          for _, cf in ipairs(codefile_positions) do
            -- Text before this Code → separate Para
            if cf.idx > prev_end + 1 then
              local before = pandoc.Inlines({})
              for i = prev_end + 1, cf.idx - 1 do
                before:insert(blk.content[i])
              end
              new_blocks:insert(pandoc.Para(before))
            end

            -- Code → CodeBlock
            new_blocks:insert(pandoc.CodeBlock(cf.text,
              pandoc.Attr("", cf.classes, {})))

            prev_end = cf.idx
          end

          -- Text after the last Code → separate Para
          local last_idx = codefile_positions[#codefile_positions].idx
          if last_idx < #blk.content then
            local after = pandoc.Inlines({})
            for i = last_idx + 1, #blk.content do
              after:insert(blk.content[i])
            end
            new_blocks:insert(pandoc.Para(after))
          end
        else
          new_blocks:insert(blk)
        end
      else
        new_blocks:insert(blk)
      end
    end
    return new_blocks
  end

  doc.blocks = promote_codefile_inlines(doc.blocks)

  return doc
end

-- =====================================================================
--  RawBlock handler — environments
-- =====================================================================

function RawBlock(raw)
  if raw.format ~= "latex" then return nil end
  local text = raw.text

  -- -------------------------------------------------------------------
  --  \begin{code}[lang]...\end{code}  →  CodeBlock
  -- -------------------------------------------------------------------
  do
    local lang_hint, body
    -- With optional language: \begin{code}[bash]...\end{code}
    lang_hint, body = text:match("\\begin%s*{code}%s*%[([^%]]*)%]%s*(.-)%s*\\end%s*{code}")
    if not lang_hint then
      -- Without language: \begin{code}...\end{code}
      body = text:match("\\begin%s*{code}%s*(.-)%s*\\end%s*{code}")
    end
    if body then
      -- Trim trailing whitespace from each line (fancyvrb artifact)
      local cleaned = body:gsub("\n%s+\n", "\n\n"):gsub("%s+$", "")
      local classes = {}
      if lang_hint and lang_hint ~= "" then
        classes = {lang_hint}
      end
      return pandoc.CodeBlock(cleaned, pandoc.Attr("", classes, {}))
    end
  end

  -- -------------------------------------------------------------------
  --  \begin{warning}...\end{warning}  →  callout box
  -- -------------------------------------------------------------------
  do
    local body = text:match("\\begin%s*{warning}%s*(.-)%s*\\end%s*{warning}")
    if body then
      local content = parse_latex_blocks(body)
      return make_callout("warning", L("warning"), content)
    end
  end

  -- -------------------------------------------------------------------
  --  \begin{tip}...\end{tip}  →  callout box
  -- -------------------------------------------------------------------
  do
    local body = text:match("\\begin%s*{tip}%s*(.-)%s*\\end%s*{tip}")
    if body then
      local content = parse_latex_blocks(body)
      return make_callout("tip", L("tip"), content)
    end
  end

  -- -------------------------------------------------------------------
  --  \begin{infobox}...\end{infobox}  →  callout box
  -- -------------------------------------------------------------------
  do
    local body = text:match("\\begin%s*{infobox}%s*(.-)%s*\\end%s*{infobox}")
    if body then
      local content = parse_latex_blocks(body)
      return make_callout("infobox", L("infobox"), content)
    end
  end

  -- -------------------------------------------------------------------
  --  \begin{objectives}...\end{objectives}
  --  Parse inner commands: \generalobjective, \objective,
  --  \prerequisites, \stepbystep
  -- -------------------------------------------------------------------
  do
    local body = text:match("\\begin%s*{objectives}%s*(.-)%s*\\end%s*{objectives}")
    if body then
      local blocks = pandoc.Blocks({})

      -- Helper: add a labeled paragraph (bold label + content)
      local function add_labeled_para(label_text, content_text)
        local inlines = pandoc.Inlines({
          pandoc.Strong({pandoc.Str(label_text)}),
          pandoc.Space(),
        })
        if content_text and content_text ~= "" then
          local parsed = parse_latex_inlines(content_text)
          inlines:extend(parsed)
        end
        blocks:insert(pandoc.Para(inlines))
      end

      -- Parse \generalobjective{...}
      local genobj = find_cmd_arg(body, "generalobjective")
      if genobj then
        add_labeled_para(L("genobj"), genobj)
      end

      -- Parse \objective{...}
      local obj_args = find_all_cmd_args(body, "objective")
      for _, arg in ipairs(obj_args) do
        add_labeled_para(L("obj"), arg)
      end

      -- Parse \prerequisites (no argument — just a label)
      if body:find("\\prerequisites") then
        add_labeled_para(L("prereq"), nil)
        -- Parse any following itemize/enumerate as normal content
        local after_prereq = body:match("\\prerequisites%s*(.*)")
        if after_prereq then
          local parsed = parse_latex_blocks(after_prereq)
          for _, blk in ipairs(parsed) do
            blocks:insert(blk)
          end
        end
      end

      -- Parse \stepbystep (no argument — just a label)
      if body:find("\\stepbystep") then
        add_labeled_para(L("stepbystep"), nil)
        local after_step = body:match("\\stepbystep%s*(.*)")
        if after_step then
          local parsed = parse_latex_blocks(after_step)
          for _, blk in ipairs(parsed) do
            blocks:insert(blk)
          end
        end
      end

      -- If nothing was parsed, fall back to full content parse
      if #blocks == 0 then
        blocks = parse_latex_blocks(body)
      end

      if FORMAT:match("docx") or FORMAT:match("html5") then
        return pandoc.Div(blocks, pandoc.Attr("", {"objectives"}, {}))
      else
        -- Markdown: BlockQuote
        return pandoc.BlockQuote(blocks)
      end
    end
  end

  -- -------------------------------------------------------------------
  --  \begin{hutable}{|spec|}...\end{hutable}  →  pandoc Table
  -- -------------------------------------------------------------------
  do
    local body = text:match("\\begin%s*{hutable}%s*%b{}%s*(.-)%s*\\end%s*{hutable}")
    -- Also extract the column spec from the argument
    local spec_arg = text:match("\\begin%s*{hutable}%s*({[^}]*})")

    if body and spec_arg then
      -- Count columns from spec: |l|l|l| → 3 columns
      local col_spec_str = spec_arg:sub(2, -2) -- strip outer braces
      local num_cols = 0
      for _ in col_spec_str:gmatch("[lcrp]") do
        num_cols = num_cols + 1
      end
      if num_cols == 0 then num_cols = 1 end

      -- Clean the body: strip \rowcolor{...}, \thd{...} → just content,
      -- strip \tbody
      local cleaned = body
      cleaned = cleaned:gsub("\\rowcolor%s*%b{}", "")     -- \rowcolor{huaweired}
      cleaned = cleaned:gsub("\\tbody", "")                -- \tbody marker
      cleaned = cleaned:gsub("\\thd%s*(%b{})", function(m)
        -- \thd{content} → just content (strip outer braces)
        return m:sub(2, -2)
      end)

      -- Split into rows on \\
      local rows = {}
      for row_str in cleaned:gmatch("(.-)\\\\") do
        row_str = trim(row_str)
        if row_str ~= "" then
          -- Split on & (column separator)
          local cells = {}
          local cell_start = 1
          local depth = 0
          for i = 1, #row_str do
            local c = row_str:sub(i, i)
            if c == "{" then depth = depth + 1
            elseif c == "}" then depth = depth - 1
            elseif c == "&" and depth == 0 then
              local cell = trim(row_str:sub(cell_start, i - 1))
              table.insert(cells, cell)
              cell_start = i + 1
            end
          end
          -- Last cell
          local cell = trim(row_str:sub(cell_start))
          table.insert(cells, cell)

          -- Pad or trim to num_cols
          while #cells < num_cols do
            table.insert(cells, "")
          end
          while #cells > num_cols do
            table.remove(cells)
          end

          table.insert(rows, cells)
        end
      end

      -- Handle last row without trailing \\
      -- Check if there's remaining content after the last \\
      local after_last_sep = cleaned:match("\\\\%s*(.*)$")
      if after_last_sep then
        after_last_sep = trim(after_last_sep)
        if after_last_sep ~= "" then
          -- Split on & (column separator)
          local cells = {}
          local cell_start = 1
          local depth = 0
          for i = 1, #after_last_sep do
            local c = after_last_sep:sub(i, i)
            if c == "{" then depth = depth + 1
            elseif c == "}" then depth = depth - 1
            elseif c == "&" and depth == 0 then
              local cell = trim(after_last_sep:sub(cell_start, i - 1))
              table.insert(cells, cell)
              cell_start = i + 1
            end
          end
          -- Last cell
          local cell = trim(after_last_sep:sub(cell_start))
          table.insert(cells, cell)

          -- Pad or trim to num_cols
          while #cells < num_cols do
            table.insert(cells, "")
          end
          while #cells > num_cols do
            table.remove(cells)
          end

          table.insert(rows, cells)
        end
      elseif #rows == 0 and cleaned ~= "" then
        -- No \\ at all — treat entire content as a single row
        local row_str = trim(cleaned)
        if row_str ~= "" then
          local cells = {}
          local cell_start = 1
          local depth = 0
          for i = 1, #row_str do
            local c = row_str:sub(i, i)
            if c == "{" then depth = depth + 1
            elseif c == "}" then depth = depth - 1
            elseif c == "&" and depth == 0 then
              local cell = trim(row_str:sub(cell_start, i - 1))
              table.insert(cells, cell)
              cell_start = i + 1
            end
          end
          local cell = trim(row_str:sub(cell_start))
          table.insert(cells, cell)

          while #cells < num_cols do
            table.insert(cells, "")
          end
          while #cells > num_cols do
            table.remove(cells)
          end

          table.insert(rows, cells)
        end
      end

      if #rows > 0 then
        -- First row = header, rest = body
        local header_row = table.remove(rows, 1)

        -- Helper: render a LaTeX cell text to markdown-safe plain text.
        -- Parses the cell as LaTeX, then writes it as markdown.
        local function cell_to_md(cell_text)
          cell_text = preprocess_latex(cell_text)
          local inlines = parse_latex_inlines(cell_text)
          local doc = pandoc.Pandoc({pandoc.Para(inlines)})
          local md = pandoc.write(doc, "markdown"):gsub("\n", " "):gsub("%s+$", "")
          return md
        end

        -- Build a markdown table string and parse it.
        -- This is version-safe across pandoc 2.x and 3.x.
        local md_lines = {}

        -- Header row
        local hdr_cells = {}
        for _, cell_text in ipairs(header_row) do
          table.insert(hdr_cells, cell_to_md(cell_text))
        end
        table.insert(md_lines, "| " .. table.concat(hdr_cells, " | ") .. " |")

        -- Separator row
        local sep_cells = {}
        for _ = 1, num_cols do
          table.insert(sep_cells, "---")
        end
        table.insert(md_lines, "| " .. table.concat(sep_cells, " | ") .. " |")

        -- Body rows
        for _, row in ipairs(rows) do
          local body_cells = {}
          for _, cell_text in ipairs(row) do
            table.insert(body_cells, cell_to_md(cell_text))
          end
          table.insert(md_lines, "| " .. table.concat(body_cells, " | ") .. " |")
        end

        local md_table = table.concat(md_lines, "\n") .. "\n"
        local parsed = pandoc.read(md_table, "markdown")
        if #parsed.blocks > 0 and parsed.blocks[1].t == "Table" then
          -- For markdown output, use RawBlock to preserve pipe table syntax.
          -- The markdown writer converts Table AST to simple tables (whitespace-
          -- aligned), which lose the pipe delimiters. RawBlock passes the pipe
          -- table through verbatim.
          if FORMAT:match("markdown") then
            return pandoc.RawBlock("markdown", md_table)
          end
          return parsed.blocks[1]
        end
        -- Fallback: return as a code block
        return pandoc.CodeBlock(md_table)
      else
        -- Empty table: return a warning paragraph
        return pandoc.Para({pandoc.Str("[Empty table]")})
      end
    end
  end

  -- -------------------------------------------------------------------
  --  \begin{changelog}...\end{changelog}
  --  Parse \changelogentry{ver}{date}{\item ...} entries
  -- -------------------------------------------------------------------
  do
    local body = text:match("\\begin%s*{changelog}%s*(.-)%s*\\end%s*{changelog}")
    if body then
      local blocks = pandoc.Blocks({})

      -- Add section header for changelog
      blocks:insert(pandoc.Header(1, pandoc.Inlines({pandoc.Str(L("changelog"))})))

      -- Parse each \changelogentry{version}{date}{items}
      -- Use pattern matching with balanced braces
      local pos = 1
      while true do
        local entry_start = body:find("\\changelogentry%s*{", pos)
        if not entry_start then break end

        -- Find first arg: version
        local brace1 = body:find("{", entry_start)
        if not brace1 then break end
        local version, end1 = parse_brace_arg(body, brace1 + 1)
        if not version then break end

        -- Find second arg: date
        local brace2 = body:find("{", end1 + 1)
        if not brace2 then break end
        local date_str, end2 = parse_brace_arg(body, brace2 + 1)
        if not date_str then break end

        -- Find third arg: items (contains \item ...)
        local brace3 = body:find("{", end2 + 1)
        if not brace3 then break end
        local items_content, end3 = parse_brace_arg(body, brace3 + 1)
        if not items_content then break end

        -- Emit: **version** (date) as a paragraph
        local entry_header = pandoc.Para({
          pandoc.Strong({pandoc.Str(version)}),
          pandoc.Str("  "),
          pandoc.Emph({pandoc.Str(date_str)}),
        })
        blocks:insert(entry_header)

        -- Parse the items content (contains \item ...)
        local items_parsed = parse_latex_blocks(items_content)
        for _, blk in ipairs(items_parsed) do
          blocks:insert(blk)
        end

        pos = (end3 or brace3) + 1
      end

      return blocks
    end
  end

  -- -------------------------------------------------------------------
  --  \objective{...}  →  blockquote with "Objective:" label
  -- -------------------------------------------------------------------
  do
    local arg = text:match("\\objective%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2)
      local parsed = parse_latex_blocks(content)
      return make_callout("infobox", L("obj"), parsed)
    end
  end

  -- -------------------------------------------------------------------
  --  \stepbystep  →  bold paragraph (section marker)
  -- -------------------------------------------------------------------
  do
    if text:match("^%s*\\stepbystep%s*$") then
      return pandoc.Para({
        pandoc.Strong({pandoc.Str(L("stepbystep"))}),
      })
    end
  end

  -- -------------------------------------------------------------------
  --  \image[opts]{file}  →  Image (block-level)
  -- -------------------------------------------------------------------
  do
    local file = text:match("\\image%s*%b[]%s*(%b{})")
    if not file then
      file = text:match("\\image%s*(%b{})")
    end
    if file then
      local path = file:sub(2, -2)
      local basename = path:match("([^/]+)$") or path
      return pandoc.Para({pandoc.Image(pandoc.Inlines({pandoc.Str(basename)}), path)})
    end
  end

  -- -------------------------------------------------------------------
  --  \imagecap[opts]{file}{caption}  →  Image with caption (block-level)
  -- -------------------------------------------------------------------
  do
    local start = text:find("\\imagecap%s*")
    if start then
      local pos = start + #("\\imagecap")
      local opt_bracket = text:find("%[", pos)
      local after_opts = pos
      if opt_bracket and opt_bracket < (text:find("{", pos) or math.huge) then
        local depth = 0
        local i = opt_bracket
        while i <= #text do
          local c = text:sub(i, i)
          if c == "[" then depth = depth + 1
          elseif c == "]" then
            depth = depth - 1
            if depth == 0 then after_opts = i + 1; break end
          end
          i = i + 1
        end
      end

      local brace1 = text:find("{", after_opts)
      if brace1 then
        local file_path, end1 = parse_brace_arg(text, brace1 + 1)
        if file_path then
          local brace2 = text:find("{", end1 + 1)
          if brace2 then
            local caption_text, _ = parse_brace_arg(text, brace2 + 1)
            if caption_text then
              local caption_inlines = parse_latex_inlines(caption_text)
              return pandoc.Para({pandoc.Image(caption_inlines, file_path)})
            end
          end
        end
      end
    end
  end

  -- -------------------------------------------------------------------
  --  \note{...}  →  blockquote with "Note:" label (block-level)
  -- -------------------------------------------------------------------
  do
    local arg = text:match("\\note%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2)
      local parsed = parse_latex_blocks(content)
      return make_callout("infobox", "Note", parsed)
    end
  end

  -- -------------------------------------------------------------------
  --  \imageplaceholder{path}{desc}  →  Image (block-level)
  -- -------------------------------------------------------------------
  do
    local start = text:find("\\imageplaceholder%s*{")
    if start then
      local brace1 = text:find("{", start)
      if brace1 then
        local path, end1 = parse_brace_arg(text, brace1 + 1)
        if path then
          local brace2 = text:find("{", end1 + 1)
          if brace2 then
            local desc, _ = parse_brace_arg(text, brace2 + 1)
            if desc then
              local caption_inlines = parse_latex_inlines(desc)
              return pandoc.Para({pandoc.Image(caption_inlines, path)})
            end
          end
        end
      end
    end
  end

  -- -------------------------------------------------------------------
  --  \badge{...}  →  bold bracketed text (block-level)
  -- -------------------------------------------------------------------
  do
    local arg = text:match("\\badge%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2)
      if FORMAT:match("docx") or FORMAT:match("html5") then
        return pandoc.Div(
          pandoc.Blocks({pandoc.Para({pandoc.Str(content)})}),
          pandoc.Attr("", {"badge"}, {})
        )
      else
        return pandoc.Para({pandoc.Strong({pandoc.Str("[" .. content .. "]")})})
      end
    end
  end

  -- -------------------------------------------------------------------
  --  \codefile[lang]{file}  →  CodeBlock (block-level)
  -- -------------------------------------------------------------------
  do
    local lang_hint, file_arg = text:match("\\codefile%s*%[([^%]]*)%]%s*(%b{})")
    if not lang_hint then
      file_arg = text:match("\\codefile%s*(%b{})")
    end
    if file_arg then
      local file_path = file_arg:sub(2, -2)
      local content = read_file(file_path)
      if content then
        local classes = {}
        if lang_hint and lang_hint ~= "" then
          classes = {lang_hint}
        end
        return pandoc.CodeBlock(content, pandoc.Attr("", classes, {}))
      else
        return pandoc.Para({
          pandoc.Emph({pandoc.Str("[Code file not found: " .. file_path .. "]")})
        })
      end
    end
  end

  return nil
end

-- =====================================================================
--  RawInline handler — inline commands
-- =====================================================================

function RawInline(raw)
  if raw.format ~= "latex" then return nil end
  local text = raw.text

  -- -------------------------------------------------------------------
  --  \inlinecode{x}  →  Code("x")
  -- -------------------------------------------------------------------
  do
    local arg = text:match("\\inlinecode%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2) -- strip outer braces
      return pandoc.Code(content)
    end
  end

  -- -------------------------------------------------------------------
  --  \menu{A, B, C}  →  **A** → **B** → **C**
  -- -------------------------------------------------------------------
  do
    local arg = text:match("\\menu%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2) -- strip outer braces
      local inlines = pandoc.Inlines({})
      local first = true
      -- Split on comma (respecting braces)
      for item in content:gmatch("([^,]+)") do
        item = trim(item)
        if item ~= "" then
          if not first then
            inlines:insert(pandoc.Str(" → "))
          end
          inlines:insert(pandoc.Strong({pandoc.Str(item)}))
          first = false
        end
      end
      return inlines
    end
  end

  -- -------------------------------------------------------------------
  --  \badge{x}  →  format-specific span
  -- -------------------------------------------------------------------
  do
    local arg = text:match("\\badge%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2)
      if FORMAT:match("docx") then
        return pandoc.Span(
          pandoc.Inlines({pandoc.Str(content)}),
          pandoc.Attr("", {"badge"}, {})
        )
      elseif FORMAT:match("html5") then
        return pandoc.Span(
          pandoc.Inlines({pandoc.Str(content)}),
          pandoc.Attr("", {"badge"}, {})
        )
      else
        -- Markdown: [x]
        return pandoc.Inlines({pandoc.Str("[" .. content .. "]")})
      end
    end
  end

  -- -------------------------------------------------------------------
  --  \note{x}  →  italic text with "Note: " prefix
  -- -------------------------------------------------------------------
  do
    local arg = text:match("\\note%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2)
      local inlines = pandoc.Inlines({pandoc.Str("Note: ")})
      inlines:extend(parse_latex_inlines(content))
      return pandoc.Emph(inlines)
    end
  end

  -- -------------------------------------------------------------------
  --  \weblink{url}{text}  →  Link
  -- -------------------------------------------------------------------
  do
    -- Match \weblink{url}{text} using balanced braces
    local start = text:find("\\weblink%s*{")
    if start then
      local brace1 = text:find("{", start)
      if brace1 then
        local url, end1 = parse_brace_arg(text, brace1 + 1)
        if url then
          local brace2 = text:find("{", end1 + 1)
          if brace2 then
            local link_text, _ = parse_brace_arg(text, brace2 + 1)
            if link_text then
              local inlines = parse_latex_inlines(link_text)
              return pandoc.Link(inlines, url)
            end
          end
        end
      end
    end
  end

  -- -------------------------------------------------------------------
  --  \param{x}  →  italic text
  -- -------------------------------------------------------------------
  do
    local arg = text:match("\\param%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2)
      local inlines = parse_latex_inlines(content)
      return pandoc.Emph(inlines)
    end
  end

  -- -------------------------------------------------------------------
  --  \image[opts]{file}  →  Image (ignore optional dimensions)
  -- -------------------------------------------------------------------
  do
    -- With optional args: \image[...]{file}
    local file = text:match("\\image%s*%b[]%s*(%b{})")
    if not file then
      -- Without optional args: \image{file}
      file = text:match("\\image%s*(%b{})")
    end
    if file then
      local path = file:sub(2, -2) -- strip outer braces
      -- Use just the filename as alt text
      local basename = path:match("([^/]+)$") or path
      return pandoc.Image(pandoc.Inlines({pandoc.Str(basename)}), path)
    end
  end

  -- -------------------------------------------------------------------
  --  \imagecap[opts]{file}{caption}  →  Image with caption
  -- -------------------------------------------------------------------
  do
    local start = text:find("\\imagecap%s*")
    if start then
      -- Skip optional [...]
      local pos = start + #("\\imagecap")
      local opt_bracket = text:find("%[", pos)
      local after_opts = pos
      if opt_bracket and opt_bracket < (text:find("{", pos) or math.huge) then
        -- Skip balanced brackets
        local depth = 0
        local i = opt_bracket
        while i <= #text do
          local c = text:sub(i, i)
          if c == "[" then depth = depth + 1
          elseif c == "]" then
            depth = depth - 1
            if depth == 0 then after_opts = i + 1; break end
          end
          i = i + 1
        end
      end

      -- Parse {file}
      local brace1 = text:find("{", after_opts)
      if brace1 then
        local file_path, end1 = parse_brace_arg(text, brace1 + 1)
        if file_path then
          -- Parse {caption}
          local brace2 = text:find("{", end1 + 1)
          if brace2 then
            local caption_text, _ = parse_brace_arg(text, brace2 + 1)
            if caption_text then
              local caption_inlines = parse_latex_inlines(caption_text)
              return pandoc.Image(caption_inlines, file_path)
            end
          end
        end
      end
    end
  end

  -- -------------------------------------------------------------------
  --  \imageplaceholder{path}{desc}  →  italic placeholder text
  -- -------------------------------------------------------------------
  do
    local start = text:find("\\imageplaceholder%s*{")
    if start then
      local brace1 = text:find("{", start)
      if brace1 then
        local path, end1 = parse_brace_arg(text, brace1 + 1)
        if path then
          local brace2 = text:find("{", end1 + 1)
          if brace2 then
            local desc, _ = parse_brace_arg(text, brace2 + 1)
            if desc then
              return pandoc.Emph({
                pandoc.Str("[Image placeholder: " .. path .. " — " .. desc .. "]")
              })
            end
          end
        end
      end
    end
  end

  -- -------------------------------------------------------------------
  --  \codefile[lang]{file}  →  read file, return Code (inline fallback)
  --  When \codefile appears as RawInline, we return inline Code.
  --  The second-pass filter handles the RawBlock case (→ CodeBlock).
  -- -------------------------------------------------------------------
  do
    local lang_hint, file_arg
    -- With optional lang: \codefile[lang]{file}
    lang_hint, file_arg = text:match("\\codefile%s*%[([^%]]*)%]%s*(%b{})")
    if not lang_hint then
      -- Without lang: \codefile{file}
      file_arg = text:match("\\codefile%s*(%b{})")
    end
    if file_arg then
      local file_path = file_arg:sub(2, -2)
      local content = read_file(file_path)
      if content then
        local classes = {}
        if lang_hint and lang_hint ~= "" then
          classes = {lang_hint}
        end
        -- Return inline Code with "codefile" marker class.
        -- The Pandoc function will promote multi-line codefile Code inlines
        -- to CodeBlocks (splitting the surrounding Para if needed).
        local all_classes = {"codefile"}
        for _, c in ipairs(classes) do
          table.insert(all_classes, c)
        end
        return pandoc.Code(content, pandoc.Attr("", all_classes, {}))
      else
        return pandoc.Emph({pandoc.Str("[Code file not found: " .. file_path .. "]")})
      end
    end
  end

  -- -------------------------------------------------------------------
  --  Strip preamble/structural commands that appear as inline raw
  -- -------------------------------------------------------------------
  for cmd, _ in pairs(strip_commands) do
    if text:match("^%s*\\" .. cmd .. "%s*%[") or
       text:match("^%s*\\" .. cmd .. "%s*{") or
       text:match("^%s*\\" .. cmd .. "%s*$") then
      return pandoc.Inlines({})
    end
  end

  return nil
end

-- =====================================================================
--  Set up inner filter for walking parsed LaTeX content
--  (must be after RawInline/RawBlock definitions)
-- =====================================================================

inner_filter = {
  RawInline = RawInline,
  RawBlock = RawBlock,
}

-- Global functions Pandoc/RawBlock/RawInline are auto-discovered by pandoc.
