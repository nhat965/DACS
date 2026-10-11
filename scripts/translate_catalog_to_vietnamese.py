from __future__ import annotations

import html
import json
import os
import time
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen

import mysql.connector

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("description", "benefits", "key_ingredients", "usage_instruction", "warnings")
MARKER = "LUMI_FIELD_"
MAX_QUERY = 4500


def load_env() -> None:
    path = ROOT / ".env.local"
    for raw in path.read_text(encoding="utf-8").splitlines():
        if "=" in raw and not raw.lstrip().startswith("#"):
            key, value = raw.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def translate(text: str) -> str:
    if not text.strip():
        return text
    url = "https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=en&tl=vi&q=" + quote(text, safe="")
    for attempt in range(3):
        try:
            request = Request(url, headers={"User-Agent": "LumiBeautyCatalog/1.0"})
            with urlopen(request, timeout=30) as response:
                payload = json.loads(response.read().decode("utf-8"))
            if isinstance(payload, list) and payload and isinstance(payload[0], str):
                return html.unescape(payload[0])
            return html.unescape("".join(str(part[0]) for part in payload[0] if part and part[0]))
        except Exception:
            if attempt == 2:
                raise
            time.sleep(1.5 * (attempt + 1))
    return text


def translate_row(row: dict[str, object]) -> dict[str, str]:
    values = {field: str(row.get(field) or "") for field in FIELDS}
    joined = "\n\n".join(f"{MARKER}{i}\n{values[field]}" for i, field in enumerate(FIELDS))
    if len(joined) > MAX_QUERY:
        return {field: translate(values[field]) if values[field] else "" for field in FIELDS}
    result = translate(joined)
    output: dict[str, str] = {}
    for i, field in enumerate(FIELDS):
        marker = f"{MARKER}{i}"
        start = result.find(marker)
        if start < 0:
            output[field] = values[field]
            continue
        start += len(marker)
        end = result.find(MARKER, start)
        output[field] = result[start:end if end >= 0 else None].strip()
    return output


def main() -> None:
    load_env()
    connection = mysql.connector.connect(
        host=os.getenv("MYSQL_HOST", "127.0.0.1"), port=int(os.getenv("MYSQL_PORT", "3306")),
        user=os.getenv("MYSQL_USER", "root"), password=os.getenv("MYSQL_PASSWORD", ""),
        database=os.getenv("MYSQL_DATABASE", "cosmetic_ecommerce"), charset="utf8mb4", autocommit=False,
    )
    cursor = connection.cursor(dictionary=True)
    selected_ids = {
        int(value.strip())
        for value in os.getenv("TRANSLATE_IDS", "").split(",")
        if value.strip().isdigit()
    }
    query = "SELECT id, description, benefits, key_ingredients, usage_instruction, warnings FROM products"
    if selected_ids:
        placeholders = ",".join(["%s"] * len(selected_ids))
        query += f" WHERE id IN ({placeholders})"
        cursor.execute(query, tuple(sorted(selected_ids)))
    else:
        cursor.execute(query)
    rows = cursor.fetchall()
    try:
        for number, row in enumerate(rows, 1):
            translated = translate_row(row)
            cursor.execute(
                "UPDATE products SET description=%s, benefits=%s, key_ingredients=%s, usage_instruction=%s, warnings=%s WHERE id=%s",
                tuple(translated[field] for field in FIELDS) + (row["id"],),
            )
            if number % 10 == 0 or number == len(rows):
                connection.commit()
                print(f"translated {number}/{len(rows)}", flush=True)
            time.sleep(0.12)
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
        connection.close()


if __name__ == "__main__":
    main()
