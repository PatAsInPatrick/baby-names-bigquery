-- MyOrder Cloud Hero #13 · Day 1 · ต่อยอดจาก Lab GSP072 (BigQuery: Qwik Start – Console)
-- ข้อมูล: babynames.names_2014 (สร้างเองจาก yob2014.txt) และ bigquery-public-data.samples.natality
-- แต่ละ query คั่นด้วย ";" เพื่อให้ analyze.py แยกรันได้

-- Q1 [babynames] ชื่อผู้หญิงยอดนิยม 10 อันดับแรก พร้อมจำนวน
SELECT name, count
FROM `babynames.names_2014`
WHERE gender = 'F'
ORDER BY count DESC
LIMIT 10;

-- Q2 [babynames] แต่ละเพศมีกี่ชื่อ และยอด count รวมเท่าไร
SELECT gender,
       COUNT(*)   AS num_names,
       SUM(count) AS total_babies
FROM `babynames.names_2014`
GROUP BY gender
ORDER BY gender;

-- Q3 [babynames] ชื่อ unisex: ชื่อเดียวกันที่ปรากฏทั้ง M และ F (เรียงตามยอดรวม, โชว์ 20 อันดับ)
SELECT name,
       SUM(IF(gender = 'M', count, 0)) AS male,
       SUM(IF(gender = 'F', count, 0)) AS female,
       SUM(count)                      AS total
FROM `babynames.names_2014`
GROUP BY name
HAVING COUNT(DISTINCT gender) = 2
ORDER BY total DESC
LIMIT 20;

-- Q3b [babynames] จำนวนชื่อ unisex ทั้งหมด
SELECT COUNT(*) AS unisex_names
FROM (
  SELECT name
  FROM `babynames.names_2014`
  GROUP BY name
  HAVING COUNT(DISTINCT gender) = 2
);

-- Q4 [natality] น้ำหนักแรกเกิดเฉลี่ย (weight_pounds) แยกตามปี
SELECT year,
       ROUND(AVG(weight_pounds), 3) AS avg_weight_pounds,
       COUNT(*)                     AS births
FROM `bigquery-public-data.samples.natality`
WHERE weight_pounds IS NOT NULL
GROUP BY year
ORDER BY year;

-- Q5 [natality] 10 รัฐที่มีจำนวนบันทึกมากที่สุด
SELECT state, COUNT(*) AS records
FROM `bigquery-public-data.samples.natality`
WHERE state IS NOT NULL
GROUP BY state
ORDER BY records DESC
LIMIT 10;

-- BONUS [babynames] ชื่ออันดับ 1 ของแต่ละเพศ ปี 2014 เทียบ 2015 (ต้องสร้าง names_2015 จาก yob2015.txt ก่อน)
WITH ranked AS (
  SELECT 2014 AS year, gender, name, count,
         ROW_NUMBER() OVER (PARTITION BY gender ORDER BY count DESC) AS rk
  FROM `babynames.names_2014`
  UNION ALL
  SELECT 2015 AS year, gender, name, count,
         ROW_NUMBER() OVER (PARTITION BY gender ORDER BY count DESC) AS rk
  FROM `babynames.names_2015`
)
SELECT gender, year, name, count
FROM ranked
WHERE rk = 1
ORDER BY gender, year;
