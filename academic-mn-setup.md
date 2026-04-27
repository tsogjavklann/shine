# Claude Code дээр Монгол академик тайлан хийх — Суулгах заавар

## 1. Энэ хавтсыг хуулж авах

Энэ `academic-mn-setup` хавтасыг бүхэлд нь компьютер дээрээ хадгал. Жишээ нь:
```
~/Documents/academic-mn/
```

Чи энэ хавтасны дотор ороод тайлан бичнэ. Нэг төсөл = нэг хавтас гэсэн зарчмаар ажилла, эсвэл нэг хавтсанд олон тайлангаа төрөлжүүлж болно.

## 2. Шаардлагатай програмуудыг суулгах

### macOS (Homebrew)
```bash
# Node.js (docx-js-д хэрэгтэй)
brew install node
npm install -g docx

# Pandoc (текст хөрвүүлэлт)
brew install pandoc

# LibreOffice (PDF болгох, баталгаажуулалт)
brew install --cask libreoffice

# Poppler (PDF → зураг, preview харах)
brew install poppler
```

### Windows (winget эсвэл суулгагч)
```powershell
# Node.js
winget install OpenJS.NodeJS
npm install -g docx

# Pandoc
winget install JohnMacFarlane.Pandoc

# LibreOffice
winget install TheDocumentFoundation.LibreOffice

# Poppler — pdftoppm-г авахад Chocolatey эсвэл хуудаснаас татах:
# https://github.com/oschwartz10612/poppler-windows/releases
```

### Linux (apt-based)
```bash
sudo apt update
sudo apt install -y nodejs npm pandoc libreoffice poppler-utils python3 python3-pip
sudo npm install -g docx
```

### Шалгах
Бүгд суусан эсэхийг шалга:
```bash
node --version      # v18+ байх ёстой
npm list -g docx    # docx package суусан байх
pandoc --version    # pandoc 2.x+ 
libreoffice --version
pdftoppm -v
python3 --version
```

## 3. Claude Code-г суулгах (хэрэв суугаагүй бол)

```bash
npm install -g @anthropic-ai/claude-code
```

Дэлгэрэнгүй: https://docs.claude.com/en/docs/claude-code/overview

## 4. Тайлан хийх ажлын урсгал

### Алхам 1: Хавтас руу орох

```bash
cd ~/Documents/academic-mn
```

### Алхам 2: Эх сурвалжаа `inputs/` хавтаст хийх

Тайланд ашиглах бүх файлаа `inputs/` хавтаст хуул:
- Судалгааны PDF
- Статистикийн Excel
- Ашиглах зургууд
- Өмнөх тэмдэглэл, тойм

```bash
cp ~/Downloads/research.pdf inputs/
cp ~/Downloads/data.xlsx inputs/
cp ~/Downloads/chart.png inputs/
```

### Алхам 3: Claude Code эхлүүлэх

```bash
claude
```

Claude Code-г ачаалахад `CLAUDE.md` файлыг **автоматаар унших**. Ингэснээр бүх тохиргоо идэвхжинэ.

### Алхам 4: Тайлан хийлгэх

Жишээ prompt:

```
inputs/ хавтаст 3 файл байгаа. "Монголын хөдөө аж ахуйн 
салбарын цахилгаан эрчим хүчний хэрэглээ" сэдвээр 20 
хуудас курсын ажил бичнэ үү. МУИС-ийн стандартаар. 
Судалгааны объект нь сүүлийн 5 жилийн статистик.
```

Claude Code хариуд:
1. Эхлээд `skills/mongolian-academic/SKILL.md`-г унших
2. `skills/docx/SKILL.md`-г унших
3. `inputs/` доторхи файлуудыг уншиж танилцах
4. Тайлангийн төлөвлөгөө гаргаж чамд харуулах
5. Чамаас баталгаажуулалт авсны дараа бичиж эхлэх

### Алхам 5: Төлөвлөгөөг баталгаажуулах

Claude Code-ийн санал болгосон бүтцэд нэмж, хасах зүйлээ хэл. Жишээ:
- "Онолын хэсэгт 5G технологийн талаар 1 хуудас нэмээрэй"
- "3-р бүлгийн хуудасны тоог 5-аас 8 хуудас болго"
- "Дүгнэлтэд санал, зөвлөмжийн хэсэг нэм"

### Алхам 6: Тайланг хүлээж авах

Тайлан `outputs/` хавтаст .docx форматаар хадгалагдана. Microsoft Word эсвэл LibreOffice-д нээж шалга.

## 5. Тайлан муу гарвал

### Зөв бичгийн алдаа гарсан бол
```
"4-р хуудасны 3-р догол мөрөнд 'сургуульн' гэсэн буруу 
байна, 'сургуулийн' болго. Мөн бусад ижил төрлийн алдааг 
шалга."
```

### Форматын алдаа гарсан бол
```
"Хүснэгт 2 хар дэвсгэртэй харагдаж байна, цайруулж 
засаарай. ShadingType.CLEAR ашиглаарай гэж docx skill-д 
заасан."
```

### Бүтцийн асуудал гарсан бол
```
"Тайлангийн удиртгал хэт ерөнхий байна, judr эх сурвалжид 
байгаа 2022 оны статистикийн тоонуудыг оруулаарай."
```

## 6. Тайлан нэмж засах

Тайлан эргэж засах шаардлагатай бол:

```
outputs/tailan.docx-ийг унш. 2-р бүлгийн 2.1 хэсэгт 
"Монгол банкны 2023 оны тайлангаас" иш татаж, GDP-ийн 
тухай 1 догол мөр нэм. Дараа нь outputs/tailan-v2.docx 
болгон хадгал.
```

## 7. Түгээмэл асуудал шийдэх

| Асуудал | Шийдэл |
|---------|--------|
| "npm install -g docx алдаа" | sudo эрхтэй ажиллуул эсвэл `npx docx` ашигла |
| "pandoc command not found" | Брэшээс дахин суулга, terminal-аа шинэчил |
| Тайлан хоосон гарсан | `inputs/` хавтсанд файл байгаа эсэхийг шалга |
| Монгол үсэг `?` болж харагдах | Font нь Cambria/Times New Roman биш байна, CLAUDE.md-ийг дагаагүй |
| validate.py алдаа заасан | Claude Code-д "validate алдааг зас" гэж хэл |
| "ShadingType is not defined" | docx-js хуучин хувилбар, `npm update -g docx` |

## 8. Сайжруулах зөвлөмж

- **Олон тайлангийн эх сурвалж:** `inputs/` доторх олон байгаа бол дэд хавтас үүсгэ: `inputs/project-1/`, `inputs/project-2/`
- **Загварыг хадгалах:** Таалагдсан тайлан гарвал `skills/mongolian-academic/SKILL.md`-д загварын дээрх жишээг нэмж хадгал — Claude Code дараагийнхыг нь адилхан хийнэ
- **Тусгай сургуулийн шаардлага:** `CLAUDE.md`-ийн төгсгөлд "Манай сургуулийн стандарт" хэсэг нэмж, тусгайлсан шаардлагыг (font, margin, хавтасны загвар) зааж өг

## 9. Нэмэлт тусламж

- docx skill-ийн дэлгэрэнгүй: https://docs.anthropic.com
- Claude Code-ийн баримт: https://docs.claude.com/en/docs/claude-code/overview
- Асуух зүйл байвал Claude Code-руу өөр өөр prompt шиднэ үзэх: 
  "Яагаад энэ хүснэгт муу харагдаад байна вэ?", "Ном зүйн бичлэгийн стилийг тайлбарлаарай" гэх мэт
