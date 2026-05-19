#!/usr/bin/env python3

import json
import re
import shutil
import sqlite3
import sys
from pathlib import Path


def _reset_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def _load_schema_sql(repo_root: Path) -> list[str]:
    source = (repo_root / "lib" / "services" / "database_service.dart").read_text(
        encoding="utf-8"
    )

    tables = re.findall(r"await db\.execute\('''\n(.*?)\n\s*'''\);", source, re.S)
    indexes = re.findall(
        r"await db\.execute\(\s*'((?:CREATE INDEX|CREATE UNIQUE INDEX)[^']+)'\s*,?\s*\);",
        source,
        re.S,
    )

    statements = [
        sql.strip()
        for sql in tables
        if sql.strip().upper().startswith("CREATE TABLE")
    ]
    statements.extend(
        sql.strip()
        for sql in indexes
        if sql.strip().upper().startswith("CREATE INDEX")
        or sql.strip().upper().startswith("CREATE UNIQUE INDEX")
    )
    return statements


def _initialize_clean_database(db_path: Path, repo_root: Path) -> None:
    conn = sqlite3.connect(db_path)
    try:
        conn.execute("PRAGMA foreign_keys = ON")
        for statement in _load_schema_sql(repo_root):
            conn.execute(statement)
        conn.commit()
    finally:
        conn.close()


def main() -> int:
    if len(sys.argv) != 2:
        print("用法: python3 tool/prepare_clean_release.py <release_dir>")
        return 1

    repo_root = Path(__file__).resolve().parent.parent
    release_dir = Path(sys.argv[1]).resolve()
    exe_path = release_dir / "asr_tools.exe"
    data_dir = release_dir / "data"

    if not release_dir.exists():
        print(f"发布目录不存在: {release_dir}")
        return 1
    if not exe_path.exists():
        print(f"未找到发布程序: {exe_path}")
        return 1
    if not data_dir.exists():
        print(f"未找到 data 目录: {data_dir}")
        return 1

    config_dir = data_dir / "config"
    database_dir = data_dir / "database"
    projects_dir = data_dir / "projects"
    temp_dir = data_dir / "temp"

    _reset_dir(config_dir)
    _reset_dir(database_dir)
    _reset_dir(projects_dir)
    _reset_dir(temp_dir)

    settings_path = config_dir / "asr_tools_settings.json"
    settings_path.write_text(
        json.dumps({}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    db_path = database_dir / "asr_tools.db"
    _initialize_clean_database(db_path, repo_root)

    print(f"已清理发布目录数据: {release_dir}")
    print(f"- settings: {settings_path}")
    print(f"- database: {db_path}")
    print(f"- projects: {projects_dir}")
    print(f"- temp: {temp_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
