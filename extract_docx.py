# -*- coding: utf-8 -*-
from docx import Document
from docx.table import Table
from docx.text.paragraph import Paragraph
from docx.oxml.ns import qn

def iter_block_items(parent):
    parent_elm = parent.element.body
    for child in parent_elm.iterchildren():
        if child.tag == qn('w:p'):
            yield Paragraph(child, parent)
        elif child.tag == qn('w:tbl'):
            yield Table(child, parent)

doc = Document(r"E:\GitHub\Dodot_Demo\docs\背包系统设计文档.docx")

lines = []
for block in iter_block_items(doc):
    if isinstance(block, Paragraph):
        style = block.style.name if block.style else ""
        text = block.text
        if text.strip() or style.lower().startswith('heading'):
            lines.append(f"[P:{style}] {text}")
    else:
        lines.append("[TABLE]")
        for row in block.rows:
            cells = [c.text.replace('\n', '\\n') for c in row.cells]
            lines.append(" | ".join(cells))
        lines.append("[/TABLE]")

with open(r"E:\GitHub\Dodot_Demo\extracted.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print("done")
