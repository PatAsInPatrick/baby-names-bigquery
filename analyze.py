"""รันทุก query ใน queries.sql ผ่าน BigQuery Python client แล้วเขียนผลเป็น Markdown ลง results/

ใช้งาน:
    pip install -r requirements.txt
    gcloud auth application-default login
    copy .env.example .env   (แล้วแก้ GOOGLE_CLOUD_PROJECT)
    python analyze.py          # รันทุกข้อ
    python analyze.py Q1 Q4    # รันเฉพาะบางข้อ
"""
import os
import re
import sys
from pathlib import Path

from google.cloud import bigquery

ROOT = Path(__file__).parent
sys.stdout.reconfigure(encoding="utf-8")  # console Windows ภาษาไทย


def load_env(path=ROOT / ".env"):
    # อ่าน .env แบบง่าย ๆ ไม่ต้องลง python-dotenv
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def parse_queries(sql_text):
    """คืน dict {"Q1": sql, ...} โดยใช้คอมเมนต์ "-- Q1 ..." / "-- BONUS ..." เป็นชื่อ"""
    queries = {}
    for chunk in sql_text.split(";"):
        m = re.search(r"^--\s*(Q\d+b?|BONUS)\b", chunk, re.M)
        body = "\n".join(l for l in chunk.splitlines() if not l.strip().startswith("--")).strip()
        if m and body:
            queries[m.group(1)] = body
    return queries


def to_markdown(rows, fields):
    head = "| " + " | ".join(fields) + " |\n|" + "---|" * len(fields) + "\n"
    return head + "".join("| " + " | ".join(str(r[f]) for f in fields) + " |\n" for r in rows)


def main():
    load_env()
    client = bigquery.Client(project=os.environ.get("GOOGLE_CLOUD_PROJECT"))
    queries = parse_queries((ROOT / "queries.sql").read_text(encoding="utf-8"))
    wanted = sys.argv[1:] or list(queries)
    out_dir = ROOT / "results"
    out_dir.mkdir(exist_ok=True)

    for name in wanted:
        job = client.query(queries[name])
        rows = list(job.result())
        fields = [f.name for f in job.result().schema]
        md = to_markdown(rows, fields)
        mb = (job.total_bytes_processed or 0) / 1e6
        (out_dir / f"{name}.md").write_text(
            f"### {name}\n\n```sql\n{queries[name]}\n```\n\n{md}\n_bytes processed: {mb:,.1f} MB_\n",
            encoding="utf-8",
        )
        print(f"\n== {name} ({mb:,.1f} MB) ==\n{md}")


if __name__ == "__main__":
    main()
