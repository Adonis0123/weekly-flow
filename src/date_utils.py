"""日期处理工具模块

提供周报日期范围计算和验证功能。
"""

from datetime import date, datetime, timedelta, timezone
from typing import Optional, Tuple


# 中国时区（东八区）
CHINA_TZ = timezone(timedelta(hours=8))


def get_today_china() -> date:
    """获取中国时区（东八区）的今天日期

    Returns:
        中国时区的今天日期
    """
    return datetime.now(CHINA_TZ).date()


def get_week_range(offset: int = 0) -> Tuple[date, date]:
    """获取指定周的日期范围（周一到周日）

    Args:
        offset: 周偏移量，0 表示本周，-1 表示上周，以此类推

    Returns:
        (start_date, end_date): 周一和周日的日期元组
        如果周日在未来，则结束日期为今天
    """
    today = get_today_china()

    # 计算本周一
    days_since_monday = today.weekday()
    current_monday = today - timedelta(days=days_since_monday)

    # 应用偏移量
    target_monday = current_monday + timedelta(weeks=offset)
    target_sunday = target_monday + timedelta(days=6)

    # 结束日期不能超过今天
    end_date = min(target_sunday, today)

    return target_monday, end_date


def validate_date_range(
    start: date, end: date
) -> Tuple[bool, Optional[str]]:
    """验证日期范围是否有效

    Args:
        start: 开始日期
        end: 结束日期

    Returns:
        (is_valid, error_message): 验证结果和错误信息
    """
    today = get_today_china()

    # 检查开始日期是否晚于结束日期
    if start > end:
        return False, "开始日期不能晚于结束日期"

    # 检查是否选择了未来日期
    if end > today:
        return False, "不能选择未来日期"

    # 检查开始日期是否是周一
    if start.weekday() != 0:
        return False, "开始日期必须是周一"

    return True, None


def is_valid_week(start: date, end: date) -> bool:
    """检查是否为有效的周一到周日

    Args:
        start: 开始日期
        end: 结束日期

    Returns:
        是否为有效的完整周
    """
    # 开始日期必须是周一
    if start.weekday() != 0:
        return False

    # 结束日期必须是周日
    if end.weekday() != 6:
        return False

    # 间隔必须是 6 天（同一周）
    if (end - start).days != 6:
        return False

    return True


def get_week_number(d: date) -> int:
    """获取日期所在的周数

    Args:
        d: 日期

    Returns:
        ISO 周数 (1-53)
    """
    return d.isocalendar()[1]


def format_date_range(start: date, end: date) -> str:
    """格式化日期范围为字符串

    Args:
        start: 开始日期
        end: 结束日期

    Returns:
        格式化的日期范围字符串
    """
    return f"{start.isoformat()} ~ {end.isoformat()}"


def get_available_weeks(count: int = 5) -> list:
    """获取可选择的周列表

    Args:
        count: 返回的周数量

    Returns:
        周列表，每项包含 (offset, start_date, end_date, label)
    """
    weeks = []
    for i in range(count):
        offset = -i
        start, end = get_week_range(offset)

        if i == 0:
            label = "本周"
        elif i == 1:
            label = "上周"
        else:
            label = f"{i} 周前"

        weeks.append({
            "offset": offset,
            "start": start,
            "end": end,
            "label": label,
            "display": f"{label} ({format_date_range(start, end)})",
        })

    return weeks
