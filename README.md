# Baby Names × Natality on BigQuery 👶📊

> การบ้าน **MyOrder Cloud Hero #13 · Day 1** — เขียน SQL ต่อยอดจาก Lab **GSP072 · BigQuery: Qwik Start – Console**
> ใช้ 2 ชุดข้อมูล: ตารางที่สร้างเอง `babynames.names_2014` และ public dataset `bigquery-public-data.samples.natality`

## 1. ไฟล์ใน repo

| ไฟล์ | เนื้อหา |
|---|---|
| [`queries.sql`](queries.sql) | SQL ครบทุกข้อ (Q1–Q5 + โจทย์เสริม) มีคอมเมนต์เลขข้อ |
| [`analyze.py`](analyze.py) | รัน query ผ่าน BigQuery Python client แล้วเขียนผลเป็น Markdown ลง `results/` |
| [`results/`](results/) | ผลลัพธ์ของแต่ละข้อ (สร้างจาก `analyze.py`) |
| [`screenshots/`](screenshots/) | ภาพหน้าจอจาก BigQuery Console |
| `.env.example` | ตัวอย่างตั้งค่า Project ID (ไฟล์ `.env` จริงไม่ถูก commit) |

## 2. เตรียมข้อมูล

1. ดาวน์โหลด `names.zip` จาก SSA (ลิงก์ใน Lab) แตกไฟล์ได้ `yob2014.txt`, `yob2015.txt`
2. BigQuery Console → สร้าง dataset `babynames`
3. Create table → Upload `yob2014.txt` (CSV) → ชื่อตาราง `names_2014`, schema: `name:string, gender:string, count:integer`
4. (โจทย์เสริม) ทำซ้ำกับ `yob2015.txt` → ตาราง `names_2015`

## 3. วิธีรัน `analyze.py`

```powershell
pip install -r requirements.txt
gcloud auth application-default login
copy .env.example .env      # แก้ GOOGLE_CLOUD_PROJECT เป็น Project ID ของตัวเอง
python analyze.py           # รันทุกข้อ
python analyze.py Q1 Q4     # รันเฉพาะบางข้อ
```

## 4. คำตอบแต่ละข้อ

### Q1 — ชื่อผู้หญิงยอดนิยม 10 อันดับแรก (2014)

```sql
SELECT name, count FROM `babynames.names_2014`
WHERE gender = 'F' ORDER BY count DESC LIMIT 10;
```

ผล: [`results/Q1.md`](results/Q1.md)

**อธิบาย:** กรองเฉพาะ `gender = 'F'` แล้วเรียง `count` จากมากไปน้อย เอา 10 แถวแรก

### Q2 — แต่ละเพศมีกี่ชื่อ และยอดรวมเท่าไร

```sql
SELECT gender, COUNT(*) AS num_names, SUM(count) AS total_babies
FROM `babynames.names_2014` GROUP BY gender;
```

ผล: [`results/Q2.md`](results/Q2.md)

**อธิบาย:** `COUNT(*)` = จำนวนชื่อ (1 แถว = 1 ชื่อต่อเพศ), `SUM(count)` = จำนวนเด็กทั้งหมด ข้อสังเกต: ข้อมูล SSA ตัดชื่อที่มีเด็กน้อยกว่า 5 คนออก ยอดรวมจึงต่ำกว่าจำนวนเด็กเกิดจริงเล็กน้อย

### Q3 — ชื่อ unisex (มีทั้ง M และ F)

```sql
SELECT name,
       SUM(IF(gender='M', count, 0)) AS male,
       SUM(IF(gender='F', count, 0)) AS female,
       SUM(count) AS total
FROM `babynames.names_2014`
GROUP BY name
HAVING COUNT(DISTINCT gender) = 2
ORDER BY total DESC LIMIT 20;
```

ผล: [`results/Q3.md`](results/Q3.md) · จำนวนชื่อ unisex ทั้งหมด: [`results/Q3b.md`](results/Q3b.md)

**อธิบาย:** `GROUP BY name` แล้วใช้ `HAVING COUNT(DISTINCT gender) = 2` เก็บเฉพาะชื่อที่มีทั้งสองเพศ ใช้ `SUM(IF(...))` pivot ให้เห็นยอดชาย/หญิงในแถวเดียว (ทำแบบ self-join ก็ได้ แต่ต้องอ่านตารางสองรอบ)

### Q4 — น้ำหนักแรกเกิดเฉลี่ยแยกตามปี (natality)

```sql
SELECT year, ROUND(AVG(weight_pounds), 3) AS avg_weight_pounds, COUNT(*) AS births
FROM `bigquery-public-data.samples.natality`
WHERE weight_pounds IS NOT NULL
GROUP BY year ORDER BY year;
```

ผล: [`results/Q4.md`](results/Q4.md)

**อธิบาย:** `AVG()` ข้าม NULL อยู่แล้ว แต่ใส่ `WHERE weight_pounds IS NOT NULL` เพื่อให้ `births` นับเฉพาะแถวที่มีน้ำหนักจริง BigQuery เป็น columnar จึงสแกนแค่ 2 คอลัมน์ (`year`, `weight_pounds`) ไม่ใช่ทั้งตาราง

### Q5 — 10 รัฐที่มีจำนวนบันทึกมากที่สุด (natality)

```sql
SELECT state, COUNT(*) AS records
FROM `bigquery-public-data.samples.natality`
WHERE state IS NOT NULL
GROUP BY state ORDER BY records DESC LIMIT 10;
```

ผล: [`results/Q5.md`](results/Q5.md)

**อธิบาย:** ต้องกรอง `state IS NOT NULL` เพราะปีหลัง ๆ ของ dataset ไม่มีข้อมูลรัฐ ถ้าไม่กรอง NULL จะขึ้นเป็นอันดับ 1

### โจทย์เสริม — ชื่ออันดับ 1 ปี 2014 vs 2015

```sql
WITH ranked AS (
  SELECT 2014 AS year, gender, name, count,
         ROW_NUMBER() OVER (PARTITION BY gender ORDER BY count DESC) AS rk
  FROM `babynames.names_2014`
  UNION ALL
  SELECT 2015, gender, name, count,
         ROW_NUMBER() OVER (PARTITION BY gender ORDER BY count DESC)
  FROM `babynames.names_2015`
)
SELECT gender, year, name, count FROM ranked WHERE rk = 1 ORDER BY gender, year;
```

ผล: [`results/BONUS.md`](results/BONUS.md)

**อธิบาย:** ใช้ window function `ROW_NUMBER()` แบ่งตามเพศในแต่ละปี แล้ว `UNION ALL` สองปีเข้าด้วยกัน เลือกเฉพาะ `rk = 1`

## 5. ส่วนที่ใช้ AI ช่วย

- ใช้ **Claude Code** ช่วยร่าง `queries.sql`, `analyze.py` และโครง README
- ตรวจเองแล้ว: รัน query ทุกข้อใน BigQuery Console/`analyze.py` และเทียบผลกับ screenshot
- ตัดสินใจเอง: เลือกใช้ `SUM(IF())` แทน self-join ในข้อ 3, ใส่ `WHERE ... IS NOT NULL` ในข้อ 4–5

## 6. อ้างอิง

- Lab GSP072 — BigQuery: Qwik Start – Console
- [BigQuery Python client](https://cloud.google.com/python/docs/reference/bigquery/latest)
- [SSA Baby Names data](https://www.ssa.gov/oact/babynames/limits.html)
