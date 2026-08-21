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


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <reference.docx>")
        sys.exit(1)

    docx_path = sys.argv[1]
    doc = Document(docx_path)

    # ── Warning callout ──────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "Warning")
    set_left_border(style, "F57C00", size_pt=3)
    set_cell_shading(style, "FFF8E1")
    set_left_indent(style, 0.5)

    # ── Tip callout ──────────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "Tip")
    set_left_border(style, "2E7D32", size_pt=3)
    set_cell_shading(style, "E8F5E9")
    set_left_indent(style, 0.5)

    # ── Info callout ─────────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "Info")
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

    # ── Heading 1 — Huawei red ───────────────────────────────────────
    try:
        h1 = doc.styles["Heading 1"]
    except KeyError:
        h1 = doc.styles.add_style("Heading 1", WD_STYLE_TYPE.PARAGRAPH)
    set_run_font(h1, "HarmonyOS Sans", 20, color_hex="C7000B", bold=True)

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
