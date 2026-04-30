from copy import deepcopy
from pathlib import Path
import shutil
from datetime import datetime

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor


DOCX = Path("bagiin_ner_v29.docx")
BACKUP_DIR = Path("output/docx_backups")
BACKUP_DIR.mkdir(parents=True, exist_ok=True)


def clear_runs(paragraph):
    for run in list(paragraph.runs):
        run._element.getparent().remove(run._element)


def set_text(paragraph, text, *, bold=False, italic=False, size=12, align=None,
             first_line=True, spacing=True):
    clear_runs(paragraph)
    run = paragraph.add_run(text)
    run.font.name = "Times New Roman"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.color.rgb = RGBColor(0, 0, 0)

    if align is not None:
        paragraph.alignment = align
    if spacing:
        paragraph.paragraph_format.line_spacing = 1.5
        paragraph.paragraph_format.space_before = Pt(0)
        paragraph.paragraph_format.space_after = Pt(6)
    if first_line:
        paragraph.paragraph_format.first_line_indent = Cm(1.25)
    else:
        paragraph.paragraph_format.first_line_indent = Cm(0)


def set_heading(paragraph, text, level=2):
    set_text(
        paragraph,
        text,
        bold=True,
        size=14 if level == 1 else 12,
        align=WD_ALIGN_PARAGRAPH.CENTER if level == 1 else WD_ALIGN_PARAGRAPH.LEFT,
        first_line=False,
    )
    paragraph.style = f"Heading {level}"


def set_caption(paragraph, text):
    set_text(
        paragraph,
        text,
        italic=True,
        size=10,
        align=WD_ALIGN_PARAGRAPH.CENTER,
        first_line=False,
        spacing=True,
    )


def set_note(paragraph, text):
    set_text(
        paragraph,
        text,
        italic=True,
        size=10,
        align=WD_ALIGN_PARAGRAPH.LEFT,
        first_line=False,
        spacing=True,
    )


def style_table(table):
    table.style = "Table Grid"
    for row_i, row in enumerate(table.rows):
        for cell in row.cells:
            tc_pr = cell._tc.get_or_add_tcPr()
            if row_i == 0:
                shd = tc_pr.find(qn("w:shd"))
                if shd is None:
                    shd = OxmlElement("w:shd")
                    tc_pr.append(shd)
                shd.set(qn("w:fill"), "D9EAF7")
            for paragraph in cell.paragraphs:
                paragraph.paragraph_format.line_spacing = 1.0
                paragraph.paragraph_format.space_before = Pt(0)
                paragraph.paragraph_format.space_after = Pt(2)
                paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER if row_i == 0 else WD_ALIGN_PARAGRAPH.LEFT
                for run in paragraph.runs:
                    run.font.name = "Times New Roman"
                    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
                    run.font.size = Pt(9)
                    run.font.bold = row_i == 0


def replace_text_exact(paragraphs, old, new, *, formatter=None):
    for p in paragraphs:
        if " ".join(p.text.split()) == old:
            if formatter:
                formatter(p, new)
            else:
                set_text(p, new)
            return True
    return False


backup = BACKUP_DIR / f"bagiin_ner_v29_before_consistency_repair_{datetime.now():%Y%m%d_%H%M%S}.docx"
shutil.copy2(DOCX, backup)

doc = Document(DOCX)
paras = doc.paragraphs

# Front lists: make them match the current report rather than the removed old figures.
front_updates = {
    20: "Хүснэгт 1. Түүврийн бүрдүүлэлт ба шинжилгээний шатлал",
    21: "Хүснэгт 2. Үндсэн хувьсагчдын тодорхойлолт",
    22: "Хүснэгт 3. ЭХБК ба ХШХБК үнэлгээний харьцуулалт",
    23: "Хүснэгт 4. Эцэг, эхийн боловсролын дундажийн эхний шатны шалгалт",
    24: "Хүснэгт 5. ХХБР үндсэн үнэлгээний үр дүн",
    25: "Хүснэгт 6. Бүүтстрап дүгнэлтийн нэгтгэл",
    26: "Хүснэгт 7. Загваруудын нэгдсэн үр дүн",
    27: "Хүснэгт 8. Эцсийн түүврийн оношилгоо",
    29: "Зураг 1. ЭХБК ба ХШХБК үнэлгээний харьцуулалт",
    30: "Зураг 2. Босгоны сүлжээн хайлтын үр дүн",
    31: "Зураг 3. Босгоор ялгасан боловсролын өгөөж",
    32: "Зураг 4. Босго утгын бүүтстрап тархалт",
    33: "Зураг 5. Регимүүдийн өгөөжийн зөрүүний бүүтстрап тархалт",
}
for idx, text in front_updates.items():
    if idx < len(paras):
        set_text(paras[idx], text, size=12, align=WD_ALIGN_PARAGRAPH.LEFT, first_line=False)

# Renumber the five actual academic figures from 1 to 5.
caption_updates = {
    "Зураг 3 ЭХБК ба ХШХБК үнэлгээний харьцуулалт": "Зураг 1. ЭХБК ба ХШХБК үнэлгээний харьцуулалт",
    "Зураг 4 Босгоны сүлжээн хайлтын үр дүн": "Зураг 2. Босгоны сүлжээн хайлтын үр дүн",
    "Зураг 5 Босгоор ялгасан боловсролын өгөөж": "Зураг 3. Босгоор ялгасан боловсролын өгөөж",
    "Зураг 6 Босго утгын бүүтстрап тархалт": "Зураг 4. Босго утгын бүүтстрап тархалт",
    "Зураг 7 Регимүүдийн өгөөжийн зөрүүний бүүтстрап тархалт": "Зураг 5. Регимүүдийн өгөөжийн зөрүүний бүүтстрап тархалт",
}
for old, new in caption_updates.items():
    replace_text_exact(paras, old, new, formatter=lambda p, t: set_caption(p, t))

table_caption_updates = {
    "Хүснэгт 3 ЭХБК ба ХШХБК үнэлгээний харьцуулалт": "Хүснэгт 3. ЭХБК ба ХШХБК үнэлгээний харьцуулалт",
    "Хүснэгт 4 Эцэг, эхийн боловсролын дундажийн эхний шатны шалгалт": "Хүснэгт 4. Эцэг, эхийн боловсролын дундажийн эхний шатны шалгалт",
    "Хүснэгт 5 ХХБР үндсэн үнэлгээний үр дүн": "Хүснэгт 5. ХХБР үндсэн үнэлгээний үр дүн",
    "Хүснэгт 6 Бүүтстрап дүгнэлтийн нэгтгэл": "Хүснэгт 6. Бүүтстрап дүгнэлтийн нэгтгэл",
    "Хүснэгт 7 Загваруудын нэгдсэн үр дүн": "Хүснэгт 7. Загваруудын нэгдсэн үр дүн",
    "Хүснэгт 8 Эцсийн түүврийн оношилгоо": "Хүснэгт 8. Эцсийн түүврийн оношилгоо",
}
for old, new in table_caption_updates.items():
    replace_text_exact(paras, old, new, formatter=lambda p, t: set_caption(p, t))

reference_updates = {
    "Зураг 3-аас харахад": "Зураг 1-ээс харахад",
    "Зураг 4-т төвлөрсөн": "Зураг 2-т төвлөрсөн",
}
for p in paras:
    text = p.text
    changed = False
    for old, new in reference_updates.items():
        if old in text:
            text = text.replace(old, new)
            changed = True
    if changed:
        set_text(p, text)

# Rewrite the conclusion so it no longer contradicts the current IVTR specification.
conclusion_updates = {
    210: "Энэхүү судалгаагаар Монгол Улсад боловсролын нэг жилийн цалингийн өгөөжийг ӨНЭЗС-ийн 2020, 2021, 2022, 2024 оны өгөгдөлд тулгуурлан, боловсролын эндоген шинж болон өгөөжийн босготой ялгааг хамтад нь харгалзах байдлаар үнэлэв. Үндсэн арга нь Caner, Hansen (2004)-ийн логикт суурилсан хэрэгсэл хувьсагчтай босго утгат регресс бөгөөд боловсролын жилийн хэрэгсэл хувьсагчаар эцэг, эхийн боловсролын дундаж, босго хувьсагчаар 17–18 насны сурагч-багшийн дундаж харьцааг ашигласан.",
    211: "Нэгдүгээрт, ЭХБК үнэлгээгээр боловсролын нэг жилийн өгөөж 4.8 хувь гарсан бол ижил түүвэр, ижил хяналт, ижил тогтмол нөлөөн дээр ХШХБК аргаар үнэлэхэд уг өгөөж 10.9 хувь болж өссөн. Энэ ялгаа нь боловсролын сонголтыг энгийн регрессэд бүрэн экзоген гэж үзэхэд өгөөжийг доогуур үнэлэх эрсдэлтэйг харуулж байна.",
    212: "Хоёрдугаарт, эцэг, эхийн боловсролын дундаж нь боловсролын жилтэй хүчтэй холбоотой байна. Эхний шатны F статистик 558.45 гарсан нь сул хэрэгсэл хувьсагчийн уламжлалт шалгуураас үлэмж өндөр тул хэрэгсэл хувьсагчийн хамаарлын шаардлага хангагдаж байна. Гэхдээ уг хувьсагчийн хязгаарлалтын таамаглалыг бүрэн батлах боломжгүй тул үр дүнг болгоомжтой тайлбарлах шаардлагатай.",
    213: "Гуравдугаарт, ХХБР үнэлгээгээр 17–18 насны сурагч-багшийн дундаж харьцааны босго 19.53 орчимд тогтож, боловсролын өгөөж доод регимд 8.2 хувь, дээд регимд 11.6 хувь байна. Хоёр регимийн ялгаа 3.1 нэгж хувь бөгөөд 399 удаагийн кластерласан бүүтстрапын хүрээнд статистикийн хувьд ач холбогдолтой гарсан боловч давталтын тоог 1,999 болгон өргөтгөөгүй тул энэ олдворыг хэт хүчтэй дүгнэлт бус, үндсэн эмпирик нотолгоо гэж үзнэ.",
    217: "Судалгааны үр дүн нь боловсрол, хөдөлмөрийн зах зээлийн бодлогод дараах гурван чиглэлийн санаа өгч байна. Эдгээр санал нь сурагч-багшийн харьцааг цалингийн шууд шалтгаан гэж үзэх бус, сургуулийн орчны ачаалал боловсролын өгөөж ялгаатай илрэх нөхцөл байж болохыг анхааруулж байгаа юм.",
    218: "Нэгдүгээрт, боловсролын өгөөж ЭХБК үнэлгээнээс өндөр гарч байгаа тул боловсролд оруулах хөрөнгө оруулалтын хөдөлмөрийн зах зээлийн ач холбогдлыг бодлогын үнэлгээнд дутуу тооцохгүй байх шаардлагатай. Ялангуяа цалинтай ажиллагчдын хувьд нэмэлт боловсрол нь орлогын мэдэгдэхүйц өсөлттэй холбоотой байна.",
    219: "Хоёрдугаарт, сурагч-багшийн харьцаагаар ялгагдсан регимүүдийн өгөөж өөр байгаа нь сургуулийн орчны ялгааг бодлогын түвшинд анхаарах үндэслэл болно. Багшийн ачаалал, сургалтын орчны нөөц, бүс нутгийн сургуулийн чанарын ялгаа нь боловсролын дараах хөдөлмөрийн зах зээлийн үр өгөөжтэй уялдах боломжтой.",
    220: "Гуравдугаарт, ӨНЭЗС болон боловсролын захиргааны өгөгдлийг хувь хүний боловсролын түүх, төрсөн газар, сургуулийн орчны үзүүлэлттэй илүү нарийвчлалтай холбох мэдээллийн тогтолцоог сайжруулах шаардлагатай. Ингэснээр боловсролын чанар, сургалтын орчин, хөдөлмөрийн үр дүнгийн хоорондын холбоог илүү нарийн үнэлэх боломж бүрдэнэ.",
    222: "Энэхүү судалгаа хэд хэдэн хязгаарлалттай. Нэгдүгээрт, эцэг, эхийн боловсролын мэдээлэл нь өрхийн бүрэлдэхүүний бүртгэлээс байгуулагдсан тул эцсийн IVTR түүвэр бүх 25–60 насны цалинтай ажиллагчдыг бүрэн төлөөлөхгүй, харин эцэг эсвэл эхийн боловсролын мэдээлэл ажиглагдсан харьцангуй залуу ажиллагчдад төвлөрсөн.",
    223: "Хоёрдугаарт, эцэг, эхийн боловсролын дундаж нь боловсролын жилтэй хүчтэй холбоотой боловч цалинд зөвхөн боловсролоор дамжин нөлөөлнө гэсэн хязгаарлалтын таамаглалыг шууд шалгах боломжгүй. Гэр бүлийн сүлжээ, хүмүүжил, ажиглагдахгүй чадвар зэрэг сувгаар үлдэх нөлөө байж болох тул шалтгаант тайлбарыг хязгаартай хэрэглэнэ.",
    224: "Гуравдугаарт, босго хувьсагч нь сурагч-багшийн аймаг-жилийн дундаж харьцаа тул хувь хүний сурсан сургуулийн бодит анги дүүргэлт, багшийн чанар, сургалтын материал зэрэг нарийн ялгааг бүрэн хэмжихгүй. Цаашдын судалгаанд сургууль түвшний өгөгдөл, боловсролын чанарын шууд үзүүлэлт, мөн илүү олон бүүтстрап давталт ашиглан үр дүнгийн бат бөх байдлыг өргөтгөх шаардлагатай.",
    225: "Дүгнэж хэлбэл, Монгол Улсад боловсролын цалингийн өгөөж эерэг бөгөөд ЭХБК-ийн дундаж холбооноос өндөр байж болохын зэрэгцээ хүүхэд ахуйн сургуулийн орчны ачааллаар ялгаатай илрэх боломжтой байна. Иймээс боловсролын өгөөжийг нэг шугаман дундаж тоогоор тайлбарлахаас илүү эндоген сонголт, сургуулийн орчны босго, түүврийн онцлогийг хамтад нь авч үзэх нь зүйтэй.",
}
for idx, text in conclusion_updates.items():
    if idx < len(paras):
        set_text(paras[idx], text)

# Clean the appendix narrative so it matches the current variables and data join.
appendix_updates = {
    262: ("Хавсралт А. Босго хувьсагчийн оношилгоо", True),
    263: ("ХХБР шинжилгээнд босго хувьсагчаар 17 болон 18 насанд харгалзах төрсөн аймгийн сурагч-багшийн дундаж харьцааг ашигласан. Босгоны сүлжээн хайлтыг боломжит утгуудын 15–85 хувийн мужид явуулж, хамгийн бага зорилгын функц бүхий босгыг 19.53 гэж сонгосон.", False),
    264: ("Хүснэгт А.1 Босго хувьсагчийн оношилгоо", False),
    265: ("Эх сурвалж: Оюутны тооцоолол", False),
    266: ("Хавсралт Б. Өгөгдөл нэгтгэл ба түүврийн шилжилт", True),
    267: ("ӨНЭЗС-ийн өрхийн бүрэлдэхүүний мэдээллээс эцэг, эхийн боловсролын дундажийг байгуулж, цалин, боловсролын жил, хяналтын хувьсагчид бүрэн ажиглагдсан ажиллагчдын түүврийг ялгасан.", False),
    268: ("Сургуулийн орчны үзүүлэлтийг төрсөн аймаг, төрсөн он дээр тулгуурлан тухайн хүний 17 болон 18 настай байсан жилтэй холбосон. Ингэснээр эцсийн ХХБР түүвэр 3,188 ажиглалтаас бүрдсэн.", False),
    269: ("Эцсийн түүвэр нь 22 төрсөн аймаг, 4 төрсөн үеийн бүлэг, 4 судалгааны давалгааг хамарсан бөгөөд үр дүнг төрсөн аймгийн түвшинд кластерласан стандарт алдаа болон бүүтстрапаар шалгасан.", False),
    270: ("", False),
    271: ("", False),
    272: ("Хавсралт В. Программ хангамжийн код", True),
    273: ("Бүх шинжилгээг R болон Python орчинд гүйцэтгэв. Үндсэн тооцоонд тогтмол нөлөөний үлдэгдэлжүүлэлт, жинлэсэн ЭХБК, ХШХБК, босгоны сүлжээн хайлт, хоёр шаттай GMM налуугийн үнэлгээ, төрсөн аймгийн түвшний кластерласан бүүтстрап ашигласан.", False),
}
for idx, (text, is_heading) in appendix_updates.items():
    if idx < len(paras):
        if text:
            if is_heading:
                set_heading(paras[idx], text, level=2)
            elif text.startswith("Хүснэгт"):
                set_caption(paras[idx], text)
            elif text.startswith("Эх сурвалж"):
                set_note(paras[idx], text)
            else:
                set_text(paras[idx], text)
        else:
            clear_runs(paras[idx])

# Re-apply consistent result-section formatting.
for i in range(151, min(206, len(paras))):
    t = " ".join(paras[i].text.split())
    if not t:
        continue
    if "БҮЛЭГ." in t:
        set_heading(paras[i], t, level=1)
    elif t[:3].count(".") >= 1 and t[0].isdigit():
        set_heading(paras[i], t, level=2)
    elif t.startswith("Хүснэгт") or t.startswith("Зураг"):
        set_caption(paras[i], t)
    elif t.startswith("Тэмдэглэл") or t.startswith("Эх сурвалж"):
        set_note(paras[i], t)
    else:
        set_text(paras[i], t)

for table in doc.tables:
    style_table(table)

for shape in doc.inline_shapes:
    try:
        if shape.width > Cm(14.5):
            ratio = Cm(14.5) / shape.width
            shape.width = Cm(14.5)
            shape.height = int(shape.height * ratio)
    except Exception:
        pass

doc.save(DOCX)
print(f"saved={DOCX}")
print(f"backup={backup}")
