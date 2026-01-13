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
    get_half_year_range,
    validate_custom_date_range,
    format_date_for_filename,
    format_period_title,
    get_available_time_ranges,
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
        # 使用过去的固定日期来测试
        # 2024年1月9日是周二
        tuesday = date(2024, 1, 9)
        sunday = date(2024, 1, 14)

        is_valid, error = validate_date_range(tuesday, sunday)
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


class TestGetHalfYearRange:
    """测试获取前半年日期范围"""

    def test_get_half_year_range(self):
        """测试获取前半年日期范围"""
        today = get_today_china()
        start, end = get_half_year_range()

        # 结束日期应该是今天
        assert end == today

        # 开始日期应该是约 6 个月前
        diff_days = (end - start).days
        assert 180 <= diff_days <= 184, "前半年应该是约 180-184 天"

    def test_half_year_range_not_in_future(self):
        """测试前半年范围不能包含未来"""
        _, end = get_half_year_range()
        today = get_today_china()

        assert end <= today


class TestValidateCustomDateRange:
    """测试自定义日期范围验证"""

    def test_valid_custom_date_range(self):
        """测试有效的自定义日期范围"""
        start = date(2024, 1, 15)  # 周一
        end = date(2024, 3, 15)    # 周五

        is_valid, error = validate_custom_date_range(start, end)
        assert is_valid is True
        assert error is None

    def test_valid_non_monday_start(self):
        """测试任意日期作为起始日期都有效"""
        # 周三作为起始日期
        start = date(2024, 1, 10)
        end = date(2024, 1, 15)

        is_valid, error = validate_custom_date_range(start, end)
        assert is_valid is True, "任意日期都可以作为起始日期"

    def test_start_date_after_end_date(self):
        """测试开始日期晚于结束日期"""
        start = date(2024, 1, 15)
        end = date(2024, 1, 10)

        is_valid, error = validate_custom_date_range(start, end)
        assert is_valid is False
        assert "开始日期不能晚于结束日期" in error

    def test_future_date_not_allowed(self):
        """测试不允许选择未来日期"""
        future_date = get_today_china() + timedelta(days=30)

        is_valid, error = validate_custom_date_range(get_today_china(), future_date)
        assert is_valid is False
        assert "不能选择未来日期" in error


class TestFormatDateForFilename:
    """测试文件名格式化"""

    def test_format_date_for_filename(self):
        """测试生成用于文件名的日期范围字符串"""
        start = date(2025, 7, 13)
        end = date(2026, 1, 13)

        filename = format_date_for_filename(start, end)
        assert filename == "2025-07-13_to_2026-01-13"

    def test_format_single_digit_dates(self):
        """测试单个数字的日期格式化"""
        start = date(2024, 1, 5)
        end = date(2024, 2, 3)

        filename = format_date_for_filename(start, end)
        assert filename == "2024-01-05_to_2024-02-03"


class TestFormatPeriodTitle:
    """测试时间段标题格式化"""

    def test_format_period_title(self):
        """测试生成时间段报告的标题"""
        start = date(2025, 7, 13)
        end = date(2026, 1, 13)

        title = format_period_title(start, end)
        assert title == "2025-07-13 ~ 2026-01-13"


class TestGetAvailableTimeRanges:
    """测试获取可选择的时间范围列表"""

    def test_get_available_time_ranges_contains_weeks(self):
        """测试时间范围列表包含周选项"""
        ranges = get_available_time_ranges()

        # 应该有本周和上周
        week_ranges = [r for r in ranges if r["type"] == "week"]
        assert len(week_ranges) >= 2

    def test_get_available_time_ranges_contains_half_year(self):
        """测试时间范围列表包含前半年选项"""
        ranges = get_available_time_ranges()

        half_year = [r for r in ranges if r.get("period_name") == "前半年"]
        assert len(half_year) == 1

        # 验证前半年选项有具体的日期
        assert half_year[0]["start"] is not None
        assert half_year[0]["end"] is not None

    def test_get_available_time_ranges_contains_custom(self):
        """测试时间范围列表包含自定义时间段选项"""
        ranges = get_available_time_ranges()

        custom = [r for r in ranges if r.get("period_name") == "custom"]
        assert len(custom) == 1

        # 自定义选项的日期为 None（需要用户输入）
        assert custom[0]["start"] is None
        assert custom[0]["end"] is None

    def test_time_ranges_have_required_fields(self):
        """测试时间范围选项包含必要字段"""
        ranges = get_available_time_ranges()

        for range_item in ranges:
            assert "type" in range_item
            assert "start" in range_item
            assert "end" in range_item
            assert "label" in range_item
            assert "display" in range_item
