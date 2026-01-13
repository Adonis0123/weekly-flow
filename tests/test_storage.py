"""存储管理模块测试"""

from datetime import date
from pathlib import Path

import pytest

from src.storage import (
    get_storage_dir,
    get_report_path,
    save_report,
    list_reports,
    get_report_by_week,
    update_index,
    get_period_report_path,
    save_period_report,
    list_period_reports,
    get_period_report,
    delete_period_report,
)


class TestGetStorageDir:
    """测试获取存储目录"""

    def test_get_default_storage_dir(self):
        """测试获取默认存储目录"""
        storage_dir = get_storage_dir()

        assert storage_dir.name == ".weekly-reports"
        assert str(Path.home()) in str(storage_dir)

    def test_get_custom_storage_dir(self, temp_dir):
        """测试获取自定义存储目录"""
        storage_dir = get_storage_dir(base_dir=temp_dir)

        assert storage_dir == temp_dir


class TestGetReportPath:
    """测试获取周报路径"""

    def test_get_report_path(self, temp_dir):
        """测试获取周报路径"""
        path = get_report_path(2024, 1, base_dir=temp_dir)

        assert "2024" in str(path)
        assert "week-01.md" in str(path)

    def test_get_report_path_different_weeks(self, temp_dir):
        """测试不同周的路径"""
        path_1 = get_report_path(2024, 1, base_dir=temp_dir)
        path_52 = get_report_path(2024, 52, base_dir=temp_dir)

        assert "week-01.md" in str(path_1)
        assert "week-52.md" in str(path_52)

    def test_get_report_path_different_years(self, temp_dir):
        """测试不同年份的路径"""
        path_2024 = get_report_path(2024, 1, base_dir=temp_dir)
        path_2025 = get_report_path(2025, 1, base_dir=temp_dir)

        assert "2024" in str(path_2024)
        assert "2025" in str(path_2025)


class TestSaveReport:
    """测试保存周报"""

    def test_save_report_new(self, temp_dir):
        """测试保存新周报"""
        content = "# 周报\n\n- 项目 A\n  - 功能开发"

        path = save_report(content, 2024, 1, base_dir=temp_dir)

        assert path.exists()
        assert path.read_text() == content + "\n"

    def test_save_report_creates_year_directory(self, temp_dir):
        """测试自动创建年份目录"""
        content = "# 周报"

        save_report(content, 2024, 1, base_dir=temp_dir)

        year_dir = temp_dir / "2024"
        assert year_dir.exists()
        assert year_dir.is_dir()

    def test_save_report_merges_existing(self, temp_dir):
        """测试同一周多次生成时合并周报内容"""
        save_report("my-project\n  - 旧条目\n", 2024, 1, base_dir=temp_dir)
        save_report("my-project\n  - 新条目\n", 2024, 1, base_dir=temp_dir)

        path = get_report_path(2024, 1, base_dir=temp_dir)
        content = path.read_text()
        assert "my-project" in content
        assert "旧条目" in content
        assert "新条目" in content


class TestListReports:
    """测试列出周报"""

    def test_list_reports_empty(self, temp_dir):
        """测试空目录"""
        reports = list_reports(base_dir=temp_dir)

        assert reports == []

    def test_list_reports_single_year(self, temp_dir):
        """测试单年份周报"""
        save_report("week 1", 2024, 1, base_dir=temp_dir)
        save_report("week 2", 2024, 2, base_dir=temp_dir)

        reports = list_reports(base_dir=temp_dir)

        assert len(reports) == 2

    def test_list_reports_multiple_years(self, temp_dir):
        """测试多年份周报"""
        save_report("2024 week 1", 2024, 1, base_dir=temp_dir)
        save_report("2025 week 1", 2025, 1, base_dir=temp_dir)

        reports = list_reports(base_dir=temp_dir)

        assert len(reports) == 2
        years = [r["year"] for r in reports]
        assert 2024 in years
        assert 2025 in years

    def test_list_reports_sorted_by_date(self, temp_dir):
        """测试按日期排序"""
        save_report("older", 2024, 1, base_dir=temp_dir)
        save_report("newer", 2024, 10, base_dir=temp_dir)

        reports = list_reports(base_dir=temp_dir)

        # 应该按时间倒序
        assert reports[0]["week"] > reports[1]["week"] or reports[0]["year"] > reports[1]["year"]


class TestGetReportByWeek:
    """测试按周获取周报"""

    def test_get_existing_report(self, temp_dir):
        """测试获取已存在的周报"""
        content = "# 周报内容"
        save_report(content, 2024, 1, base_dir=temp_dir)

        report = get_report_by_week(2024, 1, base_dir=temp_dir)

        assert report is not None
        assert report["content"] == content + "\n"
        assert report["year"] == 2024
        assert report["week"] == 1

    def test_get_non_existing_report(self, temp_dir):
        """测试获取不存在的周报"""
        report = get_report_by_week(2024, 99, base_dir=temp_dir)

        assert report is None


class TestUpdateIndex:
    """测试更新索引"""

    def test_update_index_empty(self, temp_dir):
        """测试空目录的索引"""
        update_index(base_dir=temp_dir)

        index_path = temp_dir / "index.md"
        assert index_path.exists()

    def test_update_index_with_reports(self, temp_dir):
        """测试有周报的索引"""
        save_report("week 1", 2024, 1, base_dir=temp_dir)
        save_report("week 2", 2024, 2, base_dir=temp_dir)

        update_index(base_dir=temp_dir)

        index_path = temp_dir / "index.md"
        content = index_path.read_text()

        assert "2024" in content
        assert "week-01" in content or "第 1 周" in content


class TestGetPeriodReportPath:
    """测试获取时间段报告路径"""

    def test_get_period_report_path(self, temp_dir):
        """测试获取时间段报告路径"""
        start_date = date(2025, 7, 13)
        end_date = date(2026, 1, 13)

        path = get_period_report_path(start_date, end_date, base_dir=temp_dir)

        assert "periods" in str(path)
        assert "2025-07-13_to_2026-01-13.md" in str(path)

    def test_get_period_report_path_different_dates(self, temp_dir):
        """测试不同日期的路径"""
        path_1 = get_period_report_path(date(2024, 1, 1), date(2024, 6, 30), base_dir=temp_dir)
        path_2 = get_period_report_path(date(2024, 7, 1), date(2024, 12, 31), base_dir=temp_dir)

        assert "2024-01-01_to_2024-06-30.md" in str(path_1)
        assert "2024-07-01_to_2024-12-31.md" in str(path_2)


class TestSavePeriodReport:
    """测试保存时间段报告"""

    def test_save_period_report_new(self, temp_dir):
        """测试保存新时间段报告"""
        content = "# 工作总结\n\n- 项目 A\n  - 功能开发"
        start_date = date(2025, 7, 13)
        end_date = date(2026, 1, 13)

        path = save_period_report(content, start_date, end_date, base_dir=temp_dir)

        assert path.exists()
        assert path.read_text() == content + "\n"

    def test_save_period_report_creates_periods_directory(self, temp_dir):
        """测试自动创建 periods 目录"""
        content = "# 工作总结"
        start_date = date(2025, 7, 13)
        end_date = date(2026, 1, 13)

        save_period_report(content, start_date, end_date, base_dir=temp_dir)

        periods_dir = temp_dir / "periods"
        assert periods_dir.exists()
        assert periods_dir.is_dir()

    def test_save_period_report_merges_existing(self, temp_dir):
        """测试同一时间段多次生成时合并内容"""
        start_date = date(2025, 7, 13)
        end_date = date(2026, 1, 13)

        save_period_report("my-project\n  - 旧条目\n", start_date, end_date, base_dir=temp_dir)
        save_period_report("my-project\n  - 新条目\n", start_date, end_date, base_dir=temp_dir)

        path = get_period_report_path(start_date, end_date, base_dir=temp_dir)
        content = path.read_text()
        assert "my-project" in content
        assert "旧条目" in content
        assert "新条目" in content


class TestListPeriodReports:
    """测试列出时间段报告"""

    def test_list_period_reports_empty(self, temp_dir):
        """测试空目录"""
        reports = list_period_reports(base_dir=temp_dir)

        assert reports == []

    def test_list_period_reports_single(self, temp_dir):
        """测试单个时间段报告"""
        save_period_report("report 1", date(2025, 7, 13), date(2026, 1, 13), base_dir=temp_dir)

        reports = list_period_reports(base_dir=temp_dir)

        assert len(reports) == 1
        assert reports[0]["start_date"] == date(2025, 7, 13)
        assert reports[0]["end_date"] == date(2026, 1, 13)

    def test_list_period_reports_multiple(self, temp_dir):
        """测试多个时间段报告"""
        save_period_report("report 1", date(2024, 1, 1), date(2024, 6, 30), base_dir=temp_dir)
        save_period_report("report 2", date(2024, 7, 1), date(2024, 12, 31), base_dir=temp_dir)

        reports = list_period_reports(base_dir=temp_dir)

        assert len(reports) == 2


class TestGetPeriodReport:
    """测试按日期范围获取时间段报告"""

    def test_get_existing_period_report(self, temp_dir):
        """测试获取已存在的时间段报告"""
        content = "# 工作总结内容"
        start_date = date(2025, 7, 13)
        end_date = date(2026, 1, 13)
        save_period_report(content, start_date, end_date, base_dir=temp_dir)

        report = get_period_report(start_date, end_date, base_dir=temp_dir)

        assert report is not None
        assert report["content"] == content + "\n"
        assert report["start_date"] == start_date
        assert report["end_date"] == end_date

    def test_get_non_existing_period_report(self, temp_dir):
        """测试获取不存在的时间段报告"""
        report = get_period_report(date(2099, 1, 1), date(2099, 12, 31), base_dir=temp_dir)

        assert report is None


class TestDeletePeriodReport:
    """测试删除时间段报告"""

    def test_delete_existing_period_report(self, temp_dir):
        """测试删除已存在的时间段报告"""
        start_date = date(2025, 7, 13)
        end_date = date(2026, 1, 13)
        save_period_report("content", start_date, end_date, base_dir=temp_dir)

        result = delete_period_report(start_date, end_date, base_dir=temp_dir)

        assert result is True
        assert get_period_report(start_date, end_date, base_dir=temp_dir) is None

    def test_delete_non_existing_period_report(self, temp_dir):
        """测试删除不存在的时间段报告"""
        result = delete_period_report(date(2099, 1, 1), date(2099, 12, 31), base_dir=temp_dir)

        assert result is False
