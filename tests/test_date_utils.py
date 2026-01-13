"""日期工具模块测试"""

from datetime import date, timedelta

import pytest

from src.date_utils import (
    get_week_range,
    validate_date_range,
    is_valid_week,
    get_week_number,
    format_date_range,
    get_today_china,
)


class TestGetWeekRange:
    """测试获取周日期范围"""

    def test_get_current_week_range(self):
        """测试获取本周的日期范围（周一到周日或今天）"""
        today = get_today_china()
        start, end = get_week_range(offset=0)

        # 开始日期应该是周一
        assert start.weekday() == 0, "开始日期应该是周一"
        # 结束日期应该是周日或今天（取较小值）
        expected_sunday = start + timedelta(days=6)
        expected_end = min(expected_sunday, today)
        assert end == expected_end, "结束日期应该是周日或今天"

    def test_get_previous_week_range(self):
        """测试获取上周的日期范围"""
        current_start, _ = get_week_range(offset=0)
        prev_start, prev_end = get_week_range(offset=-1)

        # 上周一应该比本周一早 7 天
        assert (current_start - prev_start).days == 7
        # 上周日应该是周日
        assert prev_end.weekday() == 6

    def test_get_week_range_with_negative_offset(self):
        """测试使用负数偏移量获取之前的周"""
        start_2_weeks_ago, end_2_weeks_ago = get_week_range(offset=-2)
        start_1_week_ago, _ = get_week_range(offset=-1)

        assert (start_1_week_ago - start_2_weeks_ago).days == 7

    def test_week_range_does_not_exceed_today(self):
        """测试周范围的结束日期不能超过今天"""
        today = get_today_china()
        _, end = get_week_range(offset=0)

        # 如果今天不是周日，结束日期应该是今天
        if today.weekday() != 6:
            assert end <= today, "结束日期不能超过今天"


class TestValidateDateRange:
    """测试日期范围验证"""

    def test_valid_date_range(self, monday_date, sunday_date):
        """测试有效的日期范围"""
        # 如果周日在未来，使用今天
        today = get_today_china()
        end_date = min(sunday_date, today)

        if monday_date <= today:
            is_valid, error = validate_date_range(monday_date, end_date)
            assert is_valid is True
            assert error is None

    def test_start_date_after_end_date(self):
        """测试开始日期晚于结束日期"""
        start = date(2024, 1, 10)
        end = date(2024, 1, 5)

        is_valid, error = validate_date_range(start, end)
        assert is_valid is False
        assert "开始日期不能晚于结束日期" in error

    def test_future_date_not_allowed(self):
        """测试不允许选择未来日期"""
        future_date = get_today_china() + timedelta(days=30)

        is_valid, error = validate_date_range(get_today_china(), future_date)
        assert is_valid is False
        assert "不能选择未来日期" in error

    def test_start_date_must_be_monday(self):
        """测试开始日期必须是周一"""
        # 找一个周二
        today = get_today_china()
        days_until_tuesday = (1 - today.weekday()) % 7
        if days_until_tuesday == 0:
            days_until_tuesday = 7
        tuesday = today - timedelta(days=7) + timedelta(days=days_until_tuesday)

        # 确保是过去的周二
        while tuesday > today:
            tuesday -= timedelta(days=7)

        is_valid, error = validate_date_range(tuesday, tuesday + timedelta(days=5))
        assert is_valid is False
        assert "开始日期必须是周一" in error


class TestIsValidWeek:
    """测试检查是否为有效的周一到周日"""

    def test_valid_monday_to_sunday(self, monday_date, sunday_date):
        """测试有效的周一到周日"""
        # 使用过去的一周来确保日期有效
        past_monday = monday_date - timedelta(days=7)
        past_sunday = sunday_date - timedelta(days=7)

        assert is_valid_week(past_monday, past_sunday) is True

    def test_invalid_start_not_monday(self):
        """测试开始日期不是周一"""
        # 使用周二作为开始
        tuesday = date(2024, 1, 9)  # 这是一个周二
        sunday = date(2024, 1, 14)

        assert is_valid_week(tuesday, sunday) is False

    def test_invalid_end_not_sunday(self):
        """测试结束日期不是周日"""
        monday = date(2024, 1, 8)
        saturday = date(2024, 1, 13)  # 这是一个周六

        assert is_valid_week(monday, saturday) is False

    def test_invalid_not_same_week(self):
        """测试开始和结束不在同一周"""
        monday = date(2024, 1, 8)
        next_sunday = date(2024, 1, 21)  # 下下周日

        assert is_valid_week(monday, next_sunday) is False


class TestGetWeekNumber:
    """测试获取周数"""

    def test_get_week_number_start_of_year(self):
        """测试年初的周数"""
        # 2024年1月1日是周一，应该是第1周
        week_num = get_week_number(date(2024, 1, 1))
        assert week_num >= 1

    def test_get_week_number_mid_year(self):
        """测试年中的周数"""
        week_num = get_week_number(date(2024, 6, 15))
        assert 20 <= week_num <= 30

    def test_get_week_number_end_of_year(self):
        """测试年末的周数"""
        # 使用12月25日，这肯定是年末的周
        week_num = get_week_number(date(2024, 12, 25))
        assert week_num >= 52


class TestFormatDateRange:
    """测试日期范围格式化"""

    def test_format_date_range_same_month(self):
        """测试同一月份的日期范围格式化"""
        start = date(2024, 1, 8)
        end = date(2024, 1, 14)

        formatted = format_date_range(start, end)
        assert "2024-01-08" in formatted
        assert "2024-01-14" in formatted

    def test_format_date_range_different_months(self):
        """测试跨月份的日期范围格式化"""
        start = date(2024, 1, 29)
        end = date(2024, 2, 4)

        formatted = format_date_range(start, end)
        assert "2024-01-29" in formatted
        assert "2024-02-04" in formatted
