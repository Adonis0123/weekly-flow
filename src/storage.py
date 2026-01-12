"""存储管理模块

管理周报的存储和检索。
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class ReportEntry:
    summary: str
    details: List[str]


def _parse_report_markdown(content: str) -> tuple[list[str], dict[str, list[ReportEntry]]]:
    preamble: list[str] = []
    sections: dict[str, list[ReportEntry]] = {}

    current_section: Optional[str] = None
    current_entry: Optional[ReportEntry] = None
    started_sections = False

    for raw_line in content.splitlines():
        line = raw_line.rstrip("\n")
        if not line.strip():
            if not started_sections:
                preamble.append(line)
            continue

        if line.startswith("#"):
            if not started_sections:
                preamble.append(line)
                continue

        if not line.startswith(" "):
            started_sections = True
            current_section = line.strip()
            sections.setdefault(current_section, [])
            current_entry = None
            continue

        if line.startswith("  - "):
            if current_section is None:
                started_sections = True
                current_section = "其他"
                sections.setdefault(current_section, [])

            current_entry = ReportEntry(summary=line[4:].strip(), details=[])
            sections[current_section].append(current_entry)
            continue

        if line.startswith("    - ") and current_entry is not None:
            current_entry.details.append(line[6:].strip())
            continue

        # 兼容意外格式：把未知缩进行作为当前 entry 的 detail
        if current_entry is not None and line.startswith(" "):
            current_entry.details.append(line.strip())

    return preamble, sections


def _dedupe_preserve_order(items: List[str]) -> List[str]:
    seen: set[str] = set()
    result: List[str] = []
    for item in items:
        key = item.strip()
        if not key or key in seen:
            continue
        seen.add(key)
        result.append(item.strip())
    return result


def _merge_sections(
    existing: dict[str, list[ReportEntry]],
    new: dict[str, list[ReportEntry]],
) -> dict[str, list[ReportEntry]]:
    merged: dict[str, list[ReportEntry]] = {}

    # 保留已有 section 的顺序
    for section, entries in existing.items():
        merged[section] = [ReportEntry(e.summary, list(e.details)) for e in entries]

    # 合并新内容
    for section, entries in new.items():
        if section not in merged:
            merged[section] = [ReportEntry(e.summary, list(e.details)) for e in entries]
            continue

        by_summary: dict[str, ReportEntry] = {e.summary: e for e in merged[section]}
        for entry in entries:
            if entry.summary in by_summary:
                target = by_summary[entry.summary]
                target.details = _dedupe_preserve_order(target.details + entry.details)
            else:
                merged[section].append(ReportEntry(entry.summary, list(entry.details)))
                by_summary[entry.summary] = merged[section][-1]

    # 统一去重
    for section, entries in merged.items():
        for entry in entries:
            entry.details = _dedupe_preserve_order(entry.details)

    return merged


def _render_report_markdown(
    preamble: list[str],
    sections: dict[str, list[ReportEntry]],
) -> str:
    lines: list[str] = []
    if preamble:
        lines.extend(preamble)
        if lines and lines[-1].strip():
            lines.append("")

    for section, entries in sections.items():
        lines.append(section)
        for entry in entries:
            lines.append(f"  - {entry.summary}")
            for detail in entry.details:
                lines.append(f"    - {detail}")
        lines.append("")

    while lines and not lines[-1].strip():
        lines.pop()

    return "\n".join(lines) + "\n"


def merge_report_content(existing: str, new: str) -> str:
    existing_preamble, existing_sections = _parse_report_markdown(existing)
    new_preamble, new_sections = _parse_report_markdown(new)

    preamble = existing_preamble or new_preamble
    merged_sections = _merge_sections(existing_sections, new_sections)
    return _render_report_markdown(preamble, merged_sections)


def get_storage_dir(base_dir: Optional[Path] = None) -> Path:
    """获取存储目录

    Args:
        base_dir: 基础目录，默认为 ~/.weekly-reports

    Returns:
        存储目录路径
    """
    if base_dir is not None:
        return base_dir

    return Path.home() / ".weekly-reports"


def get_report_path(
    year: int,
    week: int,
    base_dir: Optional[Path] = None,
) -> Path:
    """获取周报文件路径

    Args:
        year: 年份
        week: 周数
        base_dir: 存储基础目录

    Returns:
        周报文件路径
    """
    storage_dir = get_storage_dir(base_dir)
    return storage_dir / str(year) / f"week-{week:02d}.md"


def save_report(
    content: str,
    year: int,
    week: int,
    base_dir: Optional[Path] = None,
) -> Path:
    """保存周报

    Args:
        content: 周报内容
        year: 年份
        week: 周数
        base_dir: 存储基础目录

    Returns:
        保存的文件路径
    """
    path = get_report_path(year, week, base_dir)

    # 确保目录存在
    path.parent.mkdir(parents=True, exist_ok=True)

    # 同一周多次生成时进行内容合并
    if path.exists():
        existing = path.read_text(encoding="utf-8")
        merged = merge_report_content(existing, content)
        path.write_text(merged, encoding="utf-8")
    else:
        path.write_text(content if content.endswith("\n") else content + "\n", encoding="utf-8")

    return path


def list_reports(base_dir: Optional[Path] = None) -> List[Dict[str, Any]]:
    """列出所有周报

    Args:
        base_dir: 存储基础目录

    Returns:
        周报列表，每项包含 year, week, path
    """
    storage_dir = get_storage_dir(base_dir)

    if not storage_dir.exists():
        return []

    reports = []

    # 遍历年份目录
    for year_dir in sorted(storage_dir.iterdir(), reverse=True):
        if not year_dir.is_dir() or not year_dir.name.isdigit():
            continue

        year = int(year_dir.name)

        # 遍历周报文件
        for report_file in sorted(year_dir.glob("week-*.md"), reverse=True):
            # 从文件名提取周数
            week_str = report_file.stem.replace("week-", "")
            try:
                week = int(week_str)
            except ValueError:
                continue

            reports.append({
                "year": year,
                "week": week,
                "path": report_file,
                "filename": report_file.name,
            })

    return reports


def get_report_by_week(
    year: int,
    week: int,
    base_dir: Optional[Path] = None,
) -> Optional[Dict[str, Any]]:
    """按周获取周报

    Args:
        year: 年份
        week: 周数
        base_dir: 存储基础目录

    Returns:
        周报信息字典，不存在时返回 None
    """
    path = get_report_path(year, week, base_dir)

    if not path.exists():
        return None

    return {
        "year": year,
        "week": week,
        "path": path,
        "content": path.read_text(encoding="utf-8"),
    }


def update_index(base_dir: Optional[Path] = None) -> None:
    """更新周报索引文件

    Args:
        base_dir: 存储基础目录
    """
    storage_dir = get_storage_dir(base_dir)
    storage_dir.mkdir(parents=True, exist_ok=True)

    reports = list_reports(base_dir)

    # 按年份分组
    by_year: Dict[int, List[Dict[str, Any]]] = {}
    for report in reports:
        year = report["year"]
        if year not in by_year:
            by_year[year] = []
        by_year[year].append(report)

    # 生成索引内容
    lines = ["# 周报索引\n"]

    for year in sorted(by_year.keys(), reverse=True):
        lines.append(f"\n## {year} 年\n")
        for report in by_year[year]:
            week = report["week"]
            filename = report["filename"]
            lines.append(f"- [第 {week} 周](./{year}/{filename})")

    # 如果没有周报
    if not reports:
        lines.append("\n暂无周报记录。\n")

    # 写入索引文件
    index_path = storage_dir / "index.md"
    index_path.write_text("\n".join(lines), encoding="utf-8")


def delete_report(
    year: int,
    week: int,
    base_dir: Optional[Path] = None,
) -> bool:
    """删除周报

    Args:
        year: 年份
        week: 周数
        base_dir: 存储基础目录

    Returns:
        是否成功删除
    """
    path = get_report_path(year, week, base_dir)

    if not path.exists():
        return False

    path.unlink()
    return True
