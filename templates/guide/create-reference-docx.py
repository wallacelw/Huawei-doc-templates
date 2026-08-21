#!/usr/bin/env python3
"""
Add custom Huawei styles to a pandoc reference DOCX.

Usage:
    # Step 1: Generate the base reference doc from pandoc
    pandoc -o guide-reference.docx --print-default-data-file reference.docx
    # Step 2: Add Huawei styles
    python3 create-reference-docx.py guide-reference.docx

Requires: python-docx (pip install python-docx)
"""

import sys
from docx import Document
from docx.shared import Pt, Cm, RGBColor, Emu
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls, qn
from docx.enum.style import WD_STYLE_TYPE
from lxml import etree


def add_or_get_paragraph_style(doc, name, base_style=None):
    """Get an existing paragraph style or create a new one."""
    try:
        return doc.styles[name]
    except KeyError:
        return doc.styles.add_style(name, WD_STYLE_TYPE.PARAGRAPH)


def add_or_get_character_style(doc, name, base_style=None):
    """Get an existing character style or create a new one."""
    try:
        return doc.styles[name]
    except KeyError:
        return doc.styles.add_style(name, WD_STYLE_TYPE.CHARACTER)


def set_cell_shading(style, color_hex):
    """Add cell/paragraph shading via OXML (pPr/shd)."""
    color_hex = color_hex.replace("#", "")
    pPr = style.element.get_or_add_pPr()
    # Remove existing shd
    for existing in pPr.findall(qn("w:shd")):
        pPr.remove(existing)
    shd = parse_xml(
        f'<w:shd {nsdecls("w")} w:fill="{color_hex}" w:val="clear"/>'
    )
    pPr.append(shd)


def set_left_border(style, color_hex, size_pt=3):
    """Add a left paragraph border via OXML (pPr/pBdr/left)."""
    color_hex = color_hex.replace("#", "")
    size_eighth_pt = int(size_pt * 8)  # Word uses eighth-points
    pPr = style.element.get_or_add_pPr()
    # Remove existing pBdr
    for existing in pPr.findall(qn("w:pBdr")):
        pPr.remove(existing)
    pBdr = parse_xml(
        f'<w:pBdr {nsdecls("w")}>'
        f'  <w:left w:val="single" w:sz="{size_eighth_pt}" '
        f'w:space="4" w:color="{color_hex}"/>'
        f'</w:pBdr>'
    )
    pPr.append(pBdr)


def set_bottom_border(style, color_hex, size_pt=1.5):
    """Add a bottom paragraph border via OXML (pPr/pBdr/bottom)."""
    color_hex = color_hex.replace("#", "")
    size_eighth_pt = int(size_pt * 8)
    pPr = style.element.get_or_add_pPr()
    for existing in pPr.findall(qn("w:pBdr")):
        pPr.remove(existing)
    pBdr = parse_xml(
        f'<w:pBdr {nsdecls("w")}>'
        f'  <w:bottom w:val="single" w:sz="{size_eighth_pt}" '
        f'w:space="1" w:color="{color_hex}"/>'
        f'</w:pBdr>'
    )
    # Insert before spacing (OOXML order: pBdr before spacing)
    spacing = pPr.find(qn("w:spacing"))
    if spacing is not None:
        spacing.addprevious(pBdr)
    else:
        pPr.append(pBdr)


def set_left_indent(style, cm_value):
    """Set left indent on a paragraph style."""
    pf = style.paragraph_format
    pf.left_indent = Cm(cm_value)


def set_run_font(style, font_name, size_pt, color_hex=None, bold=False):
    """Configure font properties on a style's base run format."""
    rf = style.font
    rf.name = font_name
    rf.size = Pt(size_pt)
    if color_hex:
        rf.color.rgb = RGBColor.from_string(color_hex.replace("#", ""))
    if bold:
        rf.bold = True


def set_character_shading(style, color_hex):
    """Add run-level shading (rPr/shd) for character styles like badge."""
    color_hex = color_hex.replace("#", "")
    rPr = style.element.get_or_add_rPr()
    for existing in rPr.findall(qn("w:shd")):
        rPr.remove(existing)
    shd = parse_xml(
        f'<w:shd {nsdecls("w")} w:fill="{color_hex}" w:val="clear"/>'
    )
    rPr.append(shd)


def set_theme_fonts(doc, body_font):
    """Set the DOCX theme majorFont/minorFont and docDefaults to body_font.

    python-docx exposes no API for the theme part, so we reach into the
    package parts and mutate theme1.xml via lxml. This makes every style
    that references the theme (asciiTheme="minorHAnsi"/"majorHAnsi")
    inherit body_font, while styles with explicit rFonts (e.g. Source Code
    -> Cascadia Code) keep their explicit font.
    """
    A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"

    # 1. Find the theme part
    theme_part = None
    for part in doc.part.package.iter_parts():
        if str(part.partname) == "/word/theme/theme1.xml":
            theme_part = part
            break
    if theme_part is None:
        raise RuntimeError("word/theme/theme1.xml not found in package")

    # 2. Set majorFont + minorFont (latin, ea, cs) typeface
    root = etree.fromstring(theme_part.blob)
    font_scheme = root.find(f"{{{A_NS}}}themeElements/{{{A_NS}}}fontScheme")
    if font_scheme is None:
        raise RuntimeError("a:fontScheme not found in theme1.xml")
    for font_tag in ("majorFont", "minorFont"):
        group = font_scheme.find(f"{{{A_NS}}}{font_tag}")
        if group is None:
            continue
        for child_name in ("latin", "ea", "cs"):
            child = group.find(f"{{{A_NS}}}{child_name}")
            if child is None:
                child = etree.SubElement(group, f"{{{A_NS}}}{child_name}")
            child.set("typeface", body_font)
    theme_part._blob = etree.tostring(
        root, xml_declaration=True, encoding="UTF-8", standalone=True
    )

    # 3. Update docDefaults/rPrDefault rFonts for consistency
    dd = doc.styles.element.find(qn("w:docDefaults"))
    if dd is not None:
        rpr_default = dd.find(qn("w:rPrDefault"))
        if rpr_default is not None:
            rpr = rpr_default.find(qn("w:rPr"))
            if rpr is not None:
                rfonts = rpr.find(qn("w:rFonts"))
                if rfonts is not None:
                    for attr in ("ascii", "hAnsi", "eastAsia", "cs"):
                        rfonts.set(qn(f"w:{attr}"), body_font)


def fix_generated_docx(docx_path):
    """Post-process a pandoc-generated DOCX to fix heading styles.

    Pandoc overrides the reference doc's Heading styles with its own defaults
    (blue accent1 color, no border). This fixes them to match the PDF:
    near-black text, red bottom border on H1.

    Bypasses python-docx entirely — modifies styles.xml in the zip directly,
    because python-docx's save() overwrites any part blob modifications.
    """
    import zipfile, shutil
    W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

    with zipfile.ZipFile(docx_path, 'r') as z:
        styles_xml = z.read('word/styles.xml')

    root = etree.fromstring(styles_xml)

    for heading_id in ['Heading1', 'Heading2', 'Heading3', 'Heading4']:
        style = None
        for s in root.findall(f"{{{W_NS}}}style"):
            if s.get(f"{{{W_NS}}}styleId") == heading_id:
                style = s
                break
        if style is None:
            continue

        rPr = style.find(f"{{{W_NS}}}rPr")
        if rPr is None:
            rPr = etree.SubElement(style, f"{{{W_NS}}}rPr")

        # Fix color: remove all attributes, set explicit val
        color = rPr.find(f"{{{W_NS}}}color")
        if color is not None:
            for attr in list(color.attrib.keys()):
                del color.attrib[attr]
            color.set(f"{{{W_NS}}}val", "1F2328")
        else:
            color = etree.SubElement(rPr, f"{{{W_NS}}}color")
            color.set(f"{{{W_NS}}}val", "1F2328")

        # Fix font: remove theme refs, set explicit
        rFonts = rPr.find(f"{{{W_NS}}}rFonts")
        if rFonts is not None:
            for attr in list(rFonts.attrib.keys()):
                if "Theme" in attr or "theme" in attr:
                    del rFonts.attrib[attr]
            rFonts.set(f"{{{W_NS}}}ascii", "HarmonyOS Sans")
            rFonts.set(f"{{{W_NS}}}hAnsi", "HarmonyOS Sans")

        # Add bottom border to Heading 1
        if heading_id == 'Heading1':
            pPr = style.find(f"{{{W_NS}}}pPr")
            if pPr is not None:
                for pBdr in pPr.findall(f"{{{W_NS}}}pBdr"):
                    pPr.remove(pBdr)
                pBdr = etree.SubElement(pPr, f"{{{W_NS}}}pBdr")
                bottom = etree.SubElement(pBdr, f"{{{W_NS}}}bottom")
                bottom.set(f"{{{W_NS}}}val", "single")
                bottom.set(f"{{{W_NS}}}sz", "12")  # 1.5pt = 12 eighth-points
                bottom.set(f"{{{W_NS}}}space", "1")
                bottom.set(f"{{{W_NS}}}color", "C7000B")

    modified_xml = etree.tostring(
        root, xml_declaration=True, encoding="UTF-8", standalone=True
    )

    # Replace styles.xml in the DOCX zip
    tmp_path = docx_path + '.tmp'
    with zipfile.ZipFile(docx_path, 'r') as zin:
        with zipfile.ZipFile(tmp_path, 'w', zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                if item.filename == 'word/styles.xml':
                    zout.writestr(item, modified_xml)
                else:
                    zout.writestr(item, zin.read(item.filename))
    shutil.move(tmp_path, docx_path)
    print(f"✓ Fixed heading styles in {docx_path}")


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "--fix":
        fix_generated_docx(sys.argv[2])
        return
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <reference.docx>")
        sys.exit(1)

    docx_path = sys.argv[1]
    doc = Document(docx_path)

    # ── Warning callout ──────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "warning")
    set_left_border(style, "F57C00", size_pt=3)
    set_cell_shading(style, "FFF8E1")
    set_left_indent(style, 0.5)

    # ── Tip callout ──────────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "tip")
    set_left_border(style, "2E7D32", size_pt=3)
    set_cell_shading(style, "E8F5E9")
    set_left_indent(style, 0.5)

    # ── Info callout ─────────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "infobox")
    set_left_border(style, "1565C0", size_pt=3)
    set_cell_shading(style, "E3F2FD")
    set_left_indent(style, 0.5)

    # ── Objectives block ─────────────────────────────────────────────
    add_or_get_paragraph_style(doc, "objectives")

    # ── Changelog section ────────────────────────────────────────────
    add_or_get_paragraph_style(doc, "changelog")

    # ── Huawei table ─────────────────────────────────────────────────
    add_or_get_paragraph_style(doc, "hutable")

    # ── Source Code ──────────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "Source Code")
    set_cell_shading(style, "F6F8FA")
    set_run_font(style, "Cascadia Code", 10, color_hex="1F2328")

    # ── Badge (character style) ──────────────────────────────────────
    style = add_or_get_character_style(doc, "badge")
    set_character_shading(style, "C7000B")
    set_run_font(style, "Cascadia Code", 9, color_hex="FFFFFF", bold=True)

    # ── Heading 1 — black text + red bottom rule (matches PDF) ─────────
    try:
        h1 = doc.styles["Heading 1"]
    except KeyError:
        h1 = doc.styles.add_style("Heading 1", WD_STYLE_TYPE.PARAGRAPH)
    set_run_font(h1, "HarmonyOS Sans", 20, color_hex="1F2328", bold=True)
    set_bottom_border(h1, "C7000B", size_pt=1.5)

    # ── Headings 2-4 — near-black text (matches PDF) ──────────────────
    for level, size in [("Heading 2", 18), ("Heading 3", 16), ("Heading 4", 14)]:
        try:
            h = doc.styles[level]
        except KeyError:
            h = doc.styles.add_style(level, WD_STYLE_TYPE.PARAGRAPH)
        set_run_font(h, "HarmonyOS Sans", size, color_hex="1F2328", bold=True)

    # ── Hyperlink ────────────────────────────────────────────────────
    try:
        hl = doc.styles["Hyperlink"]
    except KeyError:
        hl = doc.styles.add_style("Hyperlink", WD_STYLE_TYPE.CHARACTER)
    set_run_font(hl, "HarmonyOS Sans", 10.5, color_hex="0000FF")
    # Remove underline via OXML
    rPr = hl.element.get_or_add_rPr()
    for existing in rPr.findall(qn("w:u")):
        rPr.remove(existing)
    u_elem = parse_xml(f'<w:u {nsdecls("w")} w:val="none"/>')
    rPr.append(u_elem)

    # ── Theme + default fonts: HarmonyOS Sans for all body/heading text ──
    set_theme_fonts(doc, "HarmonyOS Sans")

    # ── Save ─────────────────────────────────────────────────────────
    doc.save(docx_path)
    print(f"✓ Huawei styles added to {docx_path}")


if __name__ == "__main__":
    main()
