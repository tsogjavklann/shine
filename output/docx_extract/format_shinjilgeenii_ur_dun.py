from __future__ import annotations

import shutil
import zipfile
from datetime import datetime
from pathlib import Path
import re

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt
from docx.text.paragraph import Paragraph


DOCX_PATH = Path("bagiin_ner_v29.docx")
BACKUP_DIR = Path("output/docx_backups")
FALLBACK_PATH = Path("output/bagiin_ner_v29_ur_dun_formatted.docx")


REPLACEMENTS = {
    "Энэ бүлэгт боловсролын цалингийн өгөөжийг гурван түвшинд үнэлсэн үр дүнг танилцуулна.": (
        "Энэ бүлэгт боловсролын цалингийн өгөөжийн эмпирик үр дүнг нэг логик дарааллаар танилцуулна. "
        "Эхлээд эцсийн ХХБР түүвэр дээр ЭХБК ба ХШХБК үнэлгээг ижил хяналт, ижил тогтмол нөлөө, ижил түүврийн жинтэйгээр харьцуулж, боловсролын эндоген сонголтыг засахад коэффициент хэрхэн өөрчлөгдөж буйг харуулна. "
        "Дараа нь эцэг, эхийн боловсролын дундаж хэрэгсэл хувьсагчийн эхний шатны хүчийг шалгана. "
        "Эцэст нь 17–18 насны сурагч-багшийн дундаж харьцаагаар босгоны сүлжээн хайлт хийж, регим тус бүрийн боловсролын өгөөж болон бүүтстрап дүгнэлтийг тайлбарлана."
    ),
    "Эцсийн ХХБР түүвэр 3,188 ажиглалтаас бүрдэнэ.": (
        "Эцсийн ХХБР түүвэр 3,188 ажиглалтаас бүрдэнэ. Энэ түүвэр дээрх бүх суурь үнэлгээ нь ижил хяналтын хувьсагч, төрсөн аймаг, төрсөн үеийн бүлэг, судалгааны давалгааны тогтмол нөлөө, өрхийн түүврийн жинг ашигласан тул ЭХБК ба ХШХБК-ийн коэффициентүүдийг шууд харьцуулах боломжтой. "
        "ЭХБК үнэлгээгээр боловсролын нэг жилийн коэффициент 0.0472 буюу ойролцоогоор 4.8 хувийн өгөөжтэй гарсан бол эцэг, эхийн боловсролын дундажийг хэрэгсэл хувьсагчаар ашигласан ХШХБК үнэлгээнд коэффициент 0.1033 буюу 10.9 хувийн өгөөжтэй байна."
    ),
    "Зураг 3-аас харахад хэрэгсэл хувьсагчтай үнэлгээ нь ЭХБК-ийн суурь холбооноос хоёр дахин өндөр байна.": (
        "Зураг 3-аас харахад хэрэгсэл хувьсагчтай үнэлгээ нь ЭХБК-ийн суурь холбооноос хоёр дахин өндөр байна. Энэ нь боловсролын жилийн хувьсагчийг энгийн регрессэд экзоген гэж үзэхэд бодит өгөөжийг доогуур үнэлэх эрсдэлтэйг харуулж байна. "
        "Ийм ялгаа нь хэмжилтийн алдаа, боловсролын сонголтын санамсаргүй бус байдал, гэр бүлийн суурь нөхцөл зэрэг шалтгаанаас үүсэх боломжтой тул цаашдын босго шинжилгээнд боловсролыг эндоген тайлбарлагч гэж үзэж, ХШХБК суурийг хадгалсан."
    ),
    "ХШХБК үнэлгээний хүчин төгөлдөр байдлын эхний шаардлага нь хэрэгсэл хувьсагч боловсролын жилтэй хангалттай хүчтэй холбоотой байх явдал юм.": (
        "ХШХБК үнэлгээний хүчин төгөлдөр байдлын эхний шаардлага нь хэрэгсэл хувьсагч боловсролын жилтэй хангалттай хүчтэй холбоотой байх явдал юм. Эцэг, эхийн боловсролын дундажийн эхний шатны коэффициент 0.3623, стандарт алдаа 0.0153, F статистик 558.45 гарсан. "
        "Энэ утга нь сул хэрэгсэл хувьсагчийн уламжлалт шалгуур болох 10-аас үлэмж өндөр тул боловсролын жилтэй хамаарах нөхцөл хангагдсан гэж үзнэ. Харин энэ нь хязгаарлалтын таамаглалыг автоматаар батална гэсэн үг биш юм."
    ),
    "ХХБР үнэлгээний дараагийн алхам нь 17–18 насны сурагч-багшийн дундаж харьцааны боломжит босго утгуудыг сүлжээн хайлтаар шалгах явдал юм.": (
        "ХХБР үнэлгээний дараагийн алхам нь 17–18 насны сурагч-багшийн дундаж харьцааны боломжит босго утгуудыг сүлжээн хайлтаар шалгах явдал юм. Тогтмол нөлөөг үлдэгдэлжүүлсний дараа боломжит босго бүр дээр хоёр регимийн хэрэгсэл хувьсагчтай налууг үнэлж, нэгтгэн агшаасан алдааны квадратын нийлбэрийг харьцуулсан. "
        "Хайлтыг босго хувьсагчийн 15–85 хувийн мужид хязгаарласнаар хоёр регимийн аль нэгэнд хэт цөөн ажиглалт үлдэхээс сэргийлсэн. Нийт 278 боломжит босго шалгагдаж, зорилгын функцийн хамгийн бага утга 19.53 сурагч/багш дээр тогтов."
    ),
    "ХХБР үнэлгээгээр доод регимийн боловсролын коэффициент 0.0784, дээд регимийн коэффициент 0.1094 гарсан.": (
        "ХХБР үнэлгээгээр доод регимийн боловсролын коэффициент 0.0784, дээд регимийн коэффициент 0.1094 гарсан. Хувийн өгөөж болгон хөрвүүлэхэд доод регимд боловсролын нэмэлт нэг жил цалинг ойролцоогоор 8.2 хувиар, дээд регимд 11.6 хувиар нэмэгдүүлж байна. "
        "Иймээс хоёр регимийн өгөөжийн ялгаа 3.1 нэгж хувь байна. Энэ ялгаа нь сурагч-багшийн харьцаа өндөр байх нь өөрөө цалинг өсгөдөг гэсэн дүгнэлт биш, харин сургуулийн орчны ачааллаар ялгагдах бүлгүүдэд боловсролын цалингийн өгөөж өөр налуутай байж болохыг харуулж байна."
    ),
    "Босгоны байрлал болон регимүүдийн өгөөжийн зөрүүг төрсөн аймгийн түвшинд кластерласан 399 удаагийн бүүтстрап дахин түүвэрлэлтийн аргаар шалгав.": (
        "Босгоны байрлал болон регимүүдийн өгөөжийн зөрүүг төрсөн аймгийн түвшинд кластерласан 399 удаагийн бүүтстрап дахин түүвэрлэлтийн аргаар шалгав. Босгоны бүүтстрап медиан 19.56, 2.5 ба 97.5 хувийн перцентиль нь 18.48 болон 25.53 байна. "
        "Энэ нь босго 19–20 орчимд төвлөрч байгаа боловч дээд талдаа тодорхой хэлбэлзэлтэйг харуулна. Иймээс босгоны яг нэг цэгийг бодлогын хатуу зааг гэж бус, сургуулийн орчны ачааллын ойролцоо шилжилтийн муж гэж тайлбарлах нь илүү зохистой."
    ),
    "Хүснэгт 7-оос харахад боловсролын өгөөж ЭХБК үнэлгээгээр 4.8 хувь, ХШХБК үнэлгээгээр 10.9 хувь байна.": (
        "Хүснэгт 7-оос харахад боловсролын өгөөж ЭХБК үнэлгээгээр 4.8 хувь, ХШХБК үнэлгээгээр 10.9 хувь байна. ХХБР үнэлгээ боловсролын өгөөжийг нэг дундаж налуугаар тайлбарлахын оронд сургуулийн орчны босгоор хоёр регимд хувааж, доод регимд 8.2 хувь, дээд регимд 11.6 хувь гэж ялган харууллаа. "
        "Иймээс энэ судалгааны гол эмпирик дүгнэлт нь боловсролын өгөөж эерэг бөгөөд статистикийн хувьд ач холбогдолтой төдийгүй, 17–18 насны сурагч-багшийн харьцаагаар илэрхийлэгдэх сургуулийн орчны регимүүдийн хооронд ялгаатай байна гэсэн үр дүн юм."
    ),
}


TABLE8_DATA = [
    ["Загвар", "N", "β", "SE / p", "Өгөөж", "Тайлбар"],
    ["ЭХБК", "3,188", "0.0472", "0.0034", "4.8%", "Суурь холбоо"],
    ["ХШХБК", "3,188", "0.1033", "0.0118", "10.9%", "Эндоген хазайлтыг зассан"],
    ["ХХБР доод регим", "1,051", "0.0784", "0.0191", "8.2%", "Сурагч-багш ≤ 19.53"],
    ["ХХБР дээд регим", "2,137", "0.1094", "0.0095", "11.6%", "Сурагч-багш > 19.53"],
    ["Регимийн зөрүү", "3,188", "0.0310", "p = 0.0451", "3.1 нэгж хувь", "Бүүтстрапаар дэмжигдсэн"],
    ["Эхний шатны F", "3,188", "558.45", "<0.001", "—", "Сул IV биш"],
    ["Босго γ", "3,188", "19.53", "—", "сурагч/багш", "Регим ялгах босго"],
    ["Бүүтстрап", "399", "—", "0 failed", "—", "Аймгаар кластерласан"],
    ["Тайлбар", "—", "—", "—", "—", "Шууд шалтгаан гэж тайлбарлахгүй"],
]


def insert_paragraph_after(paragraph: Paragraph, text: str) -> Paragraph:
    new_p = OxmlElement("w:p")
    paragraph._p.addnext(new_p)
    new_para = Paragraph(new_p, paragraph._parent)
    new_para.text = text
    return new_para


def format_run(run, size: int, bold: bool = False, italic: bool = False) -> None:
    run.font.name = "Times New Roman"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
    run.font.size = Pt(size)
    run.bold = bold
    run.italic = italic


def format_paragraph(paragraph: Paragraph, role: str) -> None:
    pf = paragraph.paragraph_format
    pf.space_before = Pt(0)
    pf.space_after = Pt(6)
    pf.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE

    if role == "heading1":
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        pf.first_line_indent = None
        for run in paragraph.runs:
            format_run(run, 14, bold=True)
    elif role == "heading2":
        paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
        pf.first_line_indent = None
        pf.space_before = Pt(8)
        for run in paragraph.runs:
            format_run(run, 12, bold=True)
    elif role == "caption":
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        pf.first_line_indent = None
        pf.line_spacing_rule = WD_LINE_SPACING.SINGLE
        pf.space_after = Pt(3)
        for run in paragraph.runs:
            format_run(run, 10, italic=True)
    elif role == "source":
        paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
        pf.first_line_indent = None
        pf.line_spacing_rule = WD_LINE_SPACING.SINGLE
        pf.space_after = Pt(6)
        for run in paragraph.runs:
            format_run(run, 10, italic=True)
    elif role == "image":
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        pf.first_line_indent = None
        pf.line_spacing_rule = WD_LINE_SPACING.SINGLE
        pf.space_after = Pt(6)
    else:
        paragraph.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        pf.first_line_indent = Cm(1.25)
        for run in paragraph.runs:
            format_run(run, 12)


def set_cell_shading(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=80, start=80, bottom=80, end=80) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = tc_pr.find(qn("w:tcMar"))
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, v in [("top", top), ("start", start), ("bottom", bottom), ("end", end)]:
        node = tc_mar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(v))
        node.set(qn("w:type"), "dxa")


def style_table(table) -> None:
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = True
    try:
        table.style = "Table Grid"
    except KeyError:
        pass

    for row_idx, row in enumerate(table.rows):
        for cell in row.cells:
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_margins(cell)
            if row_idx == 0:
                set_cell_shading(cell, "EDEDED")
            for paragraph in cell.paragraphs:
                paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER if row_idx == 0 else WD_ALIGN_PARAGRAPH.LEFT
                paragraph.paragraph_format.space_after = Pt(0)
                paragraph.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
                for run in paragraph.runs:
                    format_run(run, 9, bold=(row_idx == 0))


def set_table_content(table, data: list[list[str]]) -> None:
    while len(table.rows) < len(data):
        table.add_row()
    while len(table.rows) > len(data):
        row = table.rows[-1]
        row._tr.getparent().remove(row._tr)
    for row_idx, row_data in enumerate(data):
        for col_idx, cell in enumerate(table.rows[row_idx].cells):
            cell.text = row_data[col_idx] if col_idx < len(row_data) else ""


def main() -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = BACKUP_DIR / f"bagiin_ner_v29_before_ur_dun_reformat_{stamp}.docx"
    shutil.copy2(DOCX_PATH, backup)

    doc = Document(DOCX_PATH)

    # Strengthen the explanation without changing the empirical numbers.
    for paragraph in doc.paragraphs:
        text = paragraph.text.strip()
        for prefix, replacement in REPLACEMENTS.items():
            if text.startswith(prefix):
                paragraph.text = replacement
                break

    # Add the missing source line below the first results figure.
    figure3_caption = re.compile(r"^Зураг\s+3\s{2,}")
    for i, paragraph in enumerate(doc.paragraphs):
        if figure3_caption.match(paragraph.text.strip()):
            image_para = doc.paragraphs[i + 1]
            next_para = doc.paragraphs[i + 2]
            if "pic:pic" in image_para._p.xml and not next_para.text.strip().startswith("Эх сурвалж"):
                insert_paragraph_after(image_para, "Эх сурвалж: Оюутны тооцоолол")
            break

    # Fill all columns of the wide summary table so it no longer has empty cells.
    set_table_content(doc.tables[8], TABLE8_DATA)

    start = next(i for i, p in enumerate(doc.paragraphs) if p.text.strip().startswith("IV БҮЛЭГ"))
    end = next(i for i in range(start + 1, len(doc.paragraphs)) if doc.paragraphs[i].text.strip().startswith("V БҮЛЭГ"))

    caption_pattern = re.compile(r"^(Хүснэгт|Зураг)\s+\d+\s{2,}")
    for i in range(start, end):
        paragraph = doc.paragraphs[i]
        text = paragraph.text.strip()
        if "pic:pic" in paragraph._p.xml:
            format_paragraph(paragraph, "image")
        elif text.startswith("IV БҮЛЭГ"):
            format_paragraph(paragraph, "heading1")
        elif text.startswith("4."):
            format_paragraph(paragraph, "heading2")
        elif caption_pattern.match(text):
            format_paragraph(paragraph, "caption")
        elif text.startswith("Эх сурвалж") or text.startswith("Тэмдэглэл"):
            format_paragraph(paragraph, "source")
        elif text:
            format_paragraph(paragraph, "body")

    for table_idx in range(4, 10):
        style_table(doc.tables[table_idx])

    # Keep figures within a readable print width.
    for shape in doc.inline_shapes:
        if shape.width and shape.width > Inches(5.7):
            ratio = Inches(5.7) / shape.width
            shape.width = Inches(5.7)
            shape.height = int(shape.height * ratio)

    saved_path = DOCX_PATH
    try:
        doc.save(DOCX_PATH)
    except PermissionError:
        FALLBACK_PATH.parent.mkdir(parents=True, exist_ok=True)
        doc.save(FALLBACK_PATH)
        saved_path = FALLBACK_PATH

    with zipfile.ZipFile(saved_path) as zf:
        bad = zf.testzip()
        if bad:
            raise RuntimeError(f"Invalid docx zip member: {bad}")

    print(f"Formatted results section in {saved_path}")
    print(f"Backup: {backup}")
    if saved_path != DOCX_PATH:
        print("Original was locked; fallback copy was written.")


if __name__ == "__main__":
    main()
