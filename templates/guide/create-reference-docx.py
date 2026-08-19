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
    set_run_font(style, "Consolas", 10, color_hex="1F2328")

    # ── Badge (character style) ──────────────────────────────────────
    style = add_or_get_character_style(doc, "badge")
    set_character_shading(style, "C7000B")
    set_run_font(style, "Consolas", 9, color_hex="FFFFFF", bold=True)

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

    # ── Save ─────────────────────────────────────────────────────────
    doc.save(docx_path)
    print(f"✓ Huawei styles added to {docx_path}")


if __name__ == "__main__":
    main()
