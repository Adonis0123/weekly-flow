"""Git 分析器模块测试"""

import subprocess
from datetime import date
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from src.git_analyzer import (
    get_git_user,
    get_git_user_email,
    get_commits,
    group_commits_by_project,
    parse_commit_message,
    is_git_repo,
    get_repo_name,
    scan_repos,
    merge_commits_from_repos,
    build_author_pattern,
    get_all_commits_from_repos,
)


class TestGetGitUser:
    """测试获取 Git 用户信息"""

    def test_get_git_user_from_config(self, mock_git_repo):
        """测试从 git config 获取用户信息"""
        with patch("src.git_analyzer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                stdout="adonis\n", returncode=0
            )
            user = get_git_user(mock_git_repo)
            assert user == "adonis"

    def test_get_git_user_not_configured(self, temp_dir):
        """测试未配置 git 用户时返回 None"""
        with patch("src.git_analyzer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                stdout="", returncode=1
            )
            user = get_git_user(temp_dir)
            assert user is None


class TestGetGitUserEmail:
    """测试获取 Git 用户邮箱"""

    def test_get_git_user_email_from_config(self, mock_git_repo):
        with patch("src.git_analyzer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                stdout="adonis@example.com\n", returncode=0
            )
            email = get_git_user_email(mock_git_repo)
            assert email == "adonis@example.com"

    def test_get_git_user_email_not_configured(self, temp_dir):
        with patch("src.git_analyzer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(stdout="", returncode=1)
            email = get_git_user_email(temp_dir)
            assert email is None


class TestBuildAuthorPattern:
    def test_build_author_pattern_name_only(self):
        pattern = build_author_pattern("adonis", None)
        assert pattern == "adonis"

    def test_build_author_pattern_email_only(self):
        pattern = build_author_pattern(None, "adonis@example.com")
        assert "adonis@example\\.com" in pattern

    def test_build_author_pattern_name_and_email(self):
        pattern = build_author_pattern("adonis", "adonis@example.com")
        assert "adonis" in pattern
        assert "adonis@example\\.com" in pattern
        assert "|" in pattern


class TestGetCommits:
    """测试获取提交记录"""

    def test_get_commits_in_date_range(self, mock_git_repo):
        """测试获取指定日期范围内的提交"""
        mock_output = """abc123|feat: 添加用户登录功能|adonis|2024-01-08
def456|fix: 修复登录页面样式问题|adonis|2024-01-09"""

        with patch("src.git_analyzer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                stdout=mock_output, returncode=0
            )
            commits = get_commits(
                repo_path=mock_git_repo,
                start_date=date(2024, 1, 8),
                end_date=date(2024, 1, 14),
                author="adonis",
            )

            assert len(commits) == 2
            assert commits[0]["hash"] == "abc123"
            assert commits[0]["message"] == "feat: 添加用户登录功能"

    def test_get_commits_empty_result(self, mock_git_repo):
        """测试无提交记录时返回空列表"""
        with patch("src.git_analyzer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(stdout="", returncode=0)
            commits = get_commits(
                repo_path=mock_git_repo,
                start_date=date(2024, 1, 8),
                end_date=date(2024, 1, 14),
            )
            assert commits == []

    def test_get_commits_filters_by_author(self, mock_git_repo):
        """测试按作者过滤提交"""
        with patch("src.git_analyzer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(stdout="", returncode=0)
            get_commits(
                repo_path=mock_git_repo,
                start_date=date(2024, 1, 8),
                end_date=date(2024, 1, 14),
                author="adonis",
            )

            # 验证命令中包含 author 参数
            call_args = mock_run.call_args[0][0]
            assert "--author=adonis" in call_args

    def test_get_commits_includes_end_date(self, mock_git_repo):
        """测试截止日期包含结束日当天（通过 until+1 天实现）"""
        with patch("src.git_analyzer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(stdout="", returncode=0)
            get_commits(
                repo_path=mock_git_repo,
                start_date=date(2024, 1, 8),
                end_date=date(2024, 1, 14),
            )

            call_args = mock_run.call_args[0][0]
            assert "--until=2024-01-15" in call_args

    def test_get_commits_accepts_author_pattern(self, mock_git_repo):
        """测试支持 name/email 联合 author pattern"""
        with patch("src.git_analyzer.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(stdout="", returncode=0)
            get_commits(
                repo_path=mock_git_repo,
                start_date=date(2024, 1, 8),
                end_date=date(2024, 1, 14),
                author="(adonis|adonis@example.com)",
            )

            call_args = mock_run.call_args[0][0]
            assert "--author=(adonis|adonis@example.com)" in call_args


class TestGetAllCommitsFromRepos:
    def test_auto_author_uses_name_and_email_pattern(self, temp_dir):
        repo = temp_dir / "repo"
        repo.mkdir()
        (repo / ".git").mkdir()

        with patch("src.git_analyzer.get_git_user", return_value="adonis"), patch(
            "src.git_analyzer.get_git_user_email", return_value="adonis@example.com"
        ), patch("src.git_analyzer.get_commits", return_value=[] ) as mock_get_commits:
            get_all_commits_from_repos(
                repo_paths=[repo],
                start_date=date(2024, 1, 8),
                end_date=date(2024, 1, 14),
                author=None,
            )

            assert mock_get_commits.call_count == 1
            _, _, _, passed_author = mock_get_commits.call_args[0]
            assert "adonis" in (passed_author or "")
            assert "adonis@example\\.com" in (passed_author or "")


class TestGroupCommitsByProject:
    """测试按项目分组提交"""

    def test_group_commits_single_project(self, sample_commits):
        """测试单项目分组"""
        # 过滤只保留一个项目的提交
        ai_commits = [c for c in sample_commits if c["project"] == "project-a"]
        grouped = group_commits_by_project(ai_commits)

        assert "project-a" in grouped
        assert len(grouped["project-a"]) == 3

    def test_group_commits_multiple_projects(self, sample_commits):
        """测试多项目分组"""
        grouped = group_commits_by_project(sample_commits)

        assert "project-a" in grouped
        assert "project-b" in grouped
        assert len(grouped) == 2

    def test_group_commits_empty_list(self):
        """测试空列表"""
        grouped = group_commits_by_project([])
        assert grouped == {}


class TestParseCommitMessage:
    """测试解析提交信息"""

    def test_parse_feat_commit(self):
        """测试解析 feat 类型提交"""
        result = parse_commit_message("feat: 添加用户登录功能")
        assert result["type"] == "feat"
        assert result["description"] == "添加用户登录功能"

    def test_parse_fix_commit(self):
        """测试解析 fix 类型提交"""
        result = parse_commit_message("fix: 修复登录页面样式问题")
        assert result["type"] == "fix"
        assert result["description"] == "修复登录页面样式问题"

    def test_parse_commit_with_scope(self):
        """测试解析带 scope 的提交"""
        result = parse_commit_message("feat(auth): 添加 OAuth 登录")
        assert result["type"] == "feat"
        assert result["scope"] == "auth"
        assert result["description"] == "添加 OAuth 登录"

    def test_parse_non_conventional_commit(self):
        """测试解析非常规提交"""
        result = parse_commit_message("更新依赖版本")
        assert result["type"] == "other"
        assert result["description"] == "更新依赖版本"

    def test_parse_trivial_commit(self):
        """测试识别琐碎提交"""
        result = parse_commit_message("fix typo")
        assert result["is_trivial"] is True

        result = parse_commit_message("update readme")
        assert result["is_trivial"] is True


class TestIsGitRepo:
    """测试判断是否为 Git 仓库"""

    def test_is_git_repo_true(self, mock_git_repo):
        """测试有效的 Git 仓库"""
        assert is_git_repo(mock_git_repo) is True

    def test_is_git_repo_false(self, temp_dir):
        """测试非 Git 仓库"""
        assert is_git_repo(temp_dir) is False


class TestGetRepoName:
    """测试获取仓库名称"""

    def test_get_repo_name_from_path(self, mock_git_repo):
        """测试从路径获取仓库名称"""
        name = get_repo_name(mock_git_repo)
        assert name is not None
        assert len(name) > 0


class TestScanRepos:
    """测试扫描多个仓库"""

    def test_scan_single_repo(self, mock_git_repo):
        """测试扫描单个仓库"""
        repos = scan_repos([mock_git_repo])
        assert len(repos) == 1
        assert repos[0]["path"] == mock_git_repo

    def test_scan_multiple_repos(self, temp_dir):
        """测试扫描多个仓库"""
        # 创建两个模拟仓库
        repo1 = temp_dir / "repo1"
        repo2 = temp_dir / "repo2"
        repo1.mkdir()
        repo2.mkdir()
        (repo1 / ".git").mkdir()
        (repo2 / ".git").mkdir()

        repos = scan_repos([repo1, repo2])
        assert len(repos) == 2

    def test_scan_repos_filters_invalid(self, temp_dir):
        """测试过滤无效仓库"""
        repo1 = temp_dir / "valid_repo"
        repo2 = temp_dir / "invalid_repo"
        repo1.mkdir()
        repo2.mkdir()
        (repo1 / ".git").mkdir()
        # repo2 没有 .git 目录

        repos = scan_repos([repo1, repo2])
        assert len(repos) == 1


class TestMergeCommitsFromRepos:
    """测试合并多仓库提交"""

    def test_merge_commits_from_multiple_repos(self, sample_commits):
        """测试合并多仓库提交记录"""
        commits_by_repo = {
            "project-a": [c for c in sample_commits if c["project"] == "project-a"],
            "project-b": [c for c in sample_commits if c["project"] == "project-b"],
        }

        merged = merge_commits_from_repos(commits_by_repo)

        # 应该包含所有提交
        assert len(merged) == 5
        # 每个提交都应该有 project 字段
        for commit in merged:
            assert "project" in commit

    def test_merge_commits_preserves_project_info(self, sample_commits):
        """测试合并时保留项目信息"""
        commits_by_repo = {
            "project-a": [sample_commits[0]],
            "project-b": [sample_commits[3]],
        }

        merged = merge_commits_from_repos(commits_by_repo)

        project_a_commits = [c for c in merged if c["project"] == "project-a"]
        project_b_commits = [c for c in merged if c["project"] == "project-b"]

        assert len(project_a_commits) == 1
        assert len(project_b_commits) == 1
