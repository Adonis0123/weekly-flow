"""Pytest 配置和共享 fixtures"""

import json
import os
import tempfile
from datetime import date, timedelta
from pathlib import Path
from typing import Any, Dict, List

import pytest

from src.date_utils import get_today_china


@pytest.fixture
def sample_commits() -> List[Dict[str, Any]]:
    """模拟 Git 提交数据"""
    return [
        {
            "hash": "abc123",
            "message": "feat: 添加用户登录功能",
            "author": "adonis",
            "date": "2024-01-08",
            "branch": "main",
            "project": "project-a",
        },
        {
            "hash": "def456",
            "message": "fix: 修复登录页面样式问题",
            "author": "adonis",
            "date": "2024-01-09",
            "branch": "main",
            "project": "project-a",
        },
        {
            "hash": "ghi789",
            "message": "chore: 更新依赖版本",
            "author": "adonis",
            "date": "2024-01-10",
            "branch": "develop",
            "project": "project-a",
        },
        {
            "hash": "jkl012",
            "message": "feat: 实现消息推送功能",
            "author": "adonis",
            "date": "2024-01-08",
            "branch": "main",
            "project": "project-b",
        },
        {
            "hash": "mno345",
            "message": "fix typo",
            "author": "adonis",
            "date": "2024-01-09",
            "branch": "main",
            "project": "project-b",
        },
    ]


@pytest.fixture
def sample_config() -> Dict[str, Any]:
    """模拟配置数据"""
    return {
        "repos": [
            {
                "name": "project-a",
                "path": "/home/user/projects/project-a",
            },
            {
                "name": "project-b",
                "path": "/home/user/projects/project-b",
            },
        ],
        "default_author": "auto",
        "output_format": "markdown",
    }


@pytest.fixture
def temp_dir():
    """创建临时目录"""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def mock_git_repo(temp_dir):
    """创建模拟 Git 仓库"""
    git_dir = temp_dir / ".git"
    git_dir.mkdir()

    # 创建基本的 git config
    config_file = git_dir / "config"
    config_file.write_text(
        """[user]
    name = adonis
    email = adonis@example.com
"""
    )

    return temp_dir


@pytest.fixture
def mock_config_file(temp_dir, sample_config):
    """创建模拟配置文件"""
    config_path = temp_dir / "config.json"
    config_path.write_text(json.dumps(sample_config, indent=2))
    return config_path


@pytest.fixture
def monday_date() -> date:
    """返回本周一的日期"""
    today = get_today_china()
    days_since_monday = today.weekday()
    return today - timedelta(days=days_since_monday)


@pytest.fixture
def sunday_date(monday_date) -> date:
    """返回本周日的日期"""
    return monday_date + timedelta(days=6)


@pytest.fixture
def last_monday_date(monday_date) -> date:
    """返回上周一的日期"""
    return monday_date - timedelta(days=7)


@pytest.fixture
def last_sunday_date(monday_date) -> date:
    """返回上周日的日期"""
    return monday_date - timedelta(days=1)
