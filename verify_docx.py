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

doc = Document(r"E:\GitHub\Dodot_Demo\docs\背包系统_类字段与功能细化设计.docx")
lines = []
n_para = 0
n_table = 0
for block in iter_block_items(doc):
    if isinstance(block, Paragraph):
        t = block.text
        if t.strip():
            n_para += 1
            lines.append(t)
    else:
        n_table += 1
        lines.append("[TABLE %d rows]" % len(block.rows))
        for row in block.rows:
            lines.append(" | ".join(c.text for c in row.cells))

with open(r"E:\GitHub\Dodot_Demo\verify.txt", "w", encoding="utf-8") as f:
    f.write("paragraphs=%d tables=%d\n\n" % (n_para, n_table))
    f.write("\n".join(lines))
print("done", n_para, n_table)
