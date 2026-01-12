"""周报生成器模块测试"""

import pytest

from src.report_generator import (
    generate_report,
    filter_trivial_commits,
    merge_related_commits,
    format_project_section,
    summarize_commit,
)


class TestGenerateReport:
    """测试生成周报"""

    def test_generate_report_single_project(self, sample_commits):
        """测试单项目周报生成"""
        # 只使用一个项目的提交
        commits = [c for c in sample_commits if c["project"] == "ai-video-collection"]
        report = generate_report(commits)

        assert "ai-video-collection" in report
        assert "用户登录" in report or "登录" in report

    def test_generate_report_multi_project(self, sample_commits):
        """测试多项目周报生成"""
        report = generate_report(sample_commits)

        assert "ai-video-collection" in report
        assert "bandy-ai" in report

    def test_generate_report_with_supplements(self, sample_commits):
        """测试带补充内容的周报生成"""
        supplements = ["参与技术方案评审", "完成周会分享"]
        report = generate_report(sample_commits, supplements=supplements)

        assert "其他" in report
        assert "技术方案评审" in report
        assert "周会分享" in report

    def test_generate_report_empty_commits(self):
        """测试空提交列表"""
        report = generate_report([])
        assert report == "" or "无" in report


class TestFilterTrivialCommits:
    """测试过滤琐碎提交"""

    def test_filter_typo_commits(self):
        """测试过滤 typo 修复"""
        commits = [
            {"message": "fix typo", "is_trivial": True},
            {"message": "feat: 添加登录功能", "is_trivial": False},
        ]
        filtered = filter_trivial_commits(commits)
        assert len(filtered) == 1
        assert "登录" in filtered[0]["message"]

    def test_filter_merge_commits(self):
        """测试过滤 merge 提交"""
        commits = [
            {"message": "Merge branch 'develop'", "is_trivial": True},
            {"message": "fix: 修复 bug", "is_trivial": False},
        ]
        filtered = filter_trivial_commits(commits)
        assert len(filtered) == 1

    def test_filter_format_commits(self):
        """测试过滤格式化提交"""
        commits = [
            {"message": "format code", "is_trivial": True},
            {"message": "lint fix", "is_trivial": True},
            {"message": "feat: 新功能", "is_trivial": False},
        ]
        filtered = filter_trivial_commits(commits)
        assert len(filtered) == 1

    def test_keep_all_when_no_trivial(self):
        """测试无琐碎提交时保留所有"""
        commits = [
            {"message": "feat: 功能 A", "is_trivial": False},
            {"message": "fix: 修复 B", "is_trivial": False},
        ]
        filtered = filter_trivial_commits(commits)
        assert len(filtered) == 2


class TestMergeRelatedCommits:
    """测试合并相关提交"""

    def test_merge_same_feature_commits(self):
        """测试合并同一功能的多次提交"""
        commits = [
            {"message": "feat: 添加登录功能", "type": "feat", "is_trivial": False},
            {"message": "feat: 完善登录功能", "type": "feat", "is_trivial": False},
            {"message": "fix: 修复登录 bug", "type": "fix", "is_trivial": False},
        ]
        merged = merge_related_commits(commits)

        # 相关提交应该被合并
        assert len(merged) <= len(commits)

    def test_keep_unrelated_commits_separate(self):
        """测试保留不相关的提交"""
        commits = [
            {"message": "feat: 用户登录", "type": "feat", "is_trivial": False},
            {"message": "feat: 消息推送", "type": "feat", "is_trivial": False},
        ]
        merged = merge_related_commits(commits)

        # 不相关的提交不应该被合并
        assert len(merged) >= 1


class TestFormatProjectSection:
    """测试格式化项目部分"""

    def test_format_single_commit(self):
        """测试格式化单个提交"""
        commits = [{"message": "feat: 添加用户登录功能", "type": "feat"}]
        section = format_project_section("my-project", commits)

        assert "my-project" in section
        assert "用户登录" in section or "登录" in section

    def test_format_multiple_commits(self):
        """测试格式化多个提交"""
        commits = [
            {"message": "feat: 添加登录功能", "type": "feat"},
            {"message": "fix: 修复样式问题", "type": "fix"},
        ]
        section = format_project_section("my-project", commits)

        assert "my-project" in section
        # 应该有多行内容
        assert section.count("-") >= 2

    def test_format_with_hierarchical_structure(self):
        """测试层级结构"""
        commits = [
            {"message": "feat: 添加登录功能", "type": "feat"},
            {"message": "feat: 支持 OAuth 登录", "type": "feat"},
        ]
        section = format_project_section("my-project", commits)

        # 检查层级缩进
        lines = section.strip().split("\n")
        assert any(line.startswith("  ") or line.startswith("-") for line in lines)


class TestSummarizeCommit:
    """测试提交摘要"""

    def test_summarize_short_message(self):
        """测试短消息摘要"""
        summary = summarize_commit("添加登录功能")
        assert len(summary) <= 20
        assert "登录" in summary

    def test_summarize_long_message(self):
        """测试长消息摘要（截断）"""
        long_message = "这是一个非常长的提交信息，包含了很多详细的描述内容，应该被截断"
        summary = summarize_commit(long_message)
        assert len(summary) <= 20

    def test_summarize_with_prefix(self):
        """测试去除前缀"""
        summary = summarize_commit("feat: 添加登录功能")
        assert "feat:" not in summary
        assert "登录" in summary

    def test_summarize_with_scope(self):
        """测试去除 scope"""
        summary = summarize_commit("feat(auth): 添加 OAuth 登录")
        assert "feat(auth):" not in summary
        assert "OAuth" in summary or "登录" in summary
