from __future__ import annotations

import shutil
import sys
from datetime import datetime
from pathlib import Path

from docx import Document


def main() -> None:
    docx_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("bagiin_ner_v29.docx")
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else docx_path
    backup_dir = Path("output/docx_backups")
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup_path = backup_dir / f"{docx_path.stem}_before_huraangui_{datetime.now():%Y%m%d_%H%M%S}.docx"
    shutil.copy2(docx_path, backup_path)

    doc = Document(docx_path)

    paragraph_1 = (
        "Монгол Улсын хөдөлмөрийн зах зээл дэх боловсролын цалингийн өгөөжийг тодорхойлох нь "
        "хүмүүн капиталын хөрөнгө оруулалт, боловсролын бодлого, хөдөлмөрийн бүтээмжийн уялдааг "
        "үнэлэхэд чухал ач холбогдолтой юм. Энэхүү судалгаагаар Өрхийн нийгэм, эдийн засгийн "
        "судалгааны 2020, 2021, 2022, 2024 оны давалгаанд тулгуурлан цалинтай ажиллагчдын "
        "боловсролын нэмэлт нэг жилийн өгөөжийг үнэлэв. Шинжилгээнд боловсрол, цалин, төрсөн "
        "аймаг, эцэг эхийн боловсрол болон сургуулийн орчны мэдээлэл бүрэн ажиглагдсан 3,188 "
        "ажиглалтыг хамруулсан. Боловсролын сонголт нь өрхийн суурь нөхцөл, ажиглагдахгүй ур "
        "чадвартай хамаарах боломжтой тул эцэг, эхийн боловсролын дундажийг хэрэгсэл хувьсагч "
        "болгон ашиглаж, 17–18 насанд харгалзах сурагч-багшийн дундаж харьцаагаар боловсролын "
        "өгөөжийн босго ялгааг шалгав."
    )

    paragraph_2 = (
        "Судалгааны үр дүнгээс харахад боловсролын нэг жилийн өгөөж ЭХБК үнэлгээгээр 4.8 хувь "
        "байсан бол эцэг, эхийн боловсролын дундажийг хэрэгсэл хувьсагчаар ашигласан ХШХБК "
        "үнэлгээгээр 10.9 хувь болж өсөв. Эхний шатны F шалгуурын утга 558.45 гарсан нь хэрэгсэл "
        "хувьсагч сул биш болохыг харуулж байна. ХХБР үнэлгээгээр сурагч-багшийн дундаж харьцааны "
        "босго 19.53 гэж тогтоогдсон бөгөөд уг босгоноос доош орчинд боловсролын нэг жилийн өгөөж "
        "8.2 хувь, босгоноос дээш орчинд 11.6 хувь байна. Хоёр регимийн өгөөжийн зөрүү 3.1 нэгж "
        "хувь бөгөөд төрсөн аймгаар дахин түүвэрлэсэн шалгалтаар 5 хувийн түвшинд статистикийн "
        "ач холбогдолтой гарсан. Иймд боловсролын өгөөжийг нэг дундаж тоогоор бус, хүүхэд ахуйн "
        "сургуулийн орчны ялгаатай нөхцөлтэй уялдуулан үнэлэх шаардлагатай бөгөөд багшийн нөөц, "
        "сургуулийн ачааллын бүс нутгийн ялгааг бууруулах бодлого чухал болохыг үр дүн харуулж байна."
    )

    start = end = None
    for idx, para in enumerate(doc.paragraphs):
        text = para.text.strip()
        if text == "ХУРААНГУЙ":
            start = idx
        elif start is not None and text == "ОРШИЛ":
            end = idx
            break

    if start is None or end is None:
        raise RuntimeError("Could not safely locate the ХУРААНГУЙ block.")

    body = [idx for idx in range(start + 1, end) if doc.paragraphs[idx].text.strip()]
    if len(body) < 2:
        raise RuntimeError("The ХУРААНГУЙ block has fewer than two body paragraphs.")

    doc.paragraphs[body[0]].text = paragraph_1
    doc.paragraphs[body[1]].text = paragraph_2
    for idx in body[2:]:
        doc.paragraphs[idx].text = ""

    doc.save(output_path)
    print(f"Updated: {output_path}")
    print(f"Backup: {backup_path}")


if __name__ == "__main__":
    main()
