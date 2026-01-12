"""配置管理模块测试"""

import json
from pathlib import Path

import pytest

from src.config_manager import (
    load_config,
    save_config,
    add_repo,
    remove_repo,
    get_repos,
    validate_repo,
    get_config_path,
    DEFAULT_CONFIG,
)


class TestLoadConfig:
    """测试加载配置"""

    def test_load_existing_config(self, temp_dir, sample_config):
        """测试加载已存在的配置文件"""
        config_path = temp_dir / "config.json"
        config_path.write_text(json.dumps(sample_config))

        config = load_config(config_path)

        assert config["repos"] == sample_config["repos"]
        assert config["default_author"] == "auto"

    def test_load_non_existing_config(self, temp_dir):
        """测试加载不存在的配置文件返回默认配置"""
        config_path = temp_dir / "non_existing.json"

        config = load_config(config_path)

        assert config == DEFAULT_CONFIG

    def test_load_invalid_json(self, temp_dir):
        """测试加载无效 JSON 返回默认配置"""
        config_path = temp_dir / "invalid.json"
        config_path.write_text("not valid json {{{")

        config = load_config(config_path)

        assert config == DEFAULT_CONFIG


class TestSaveConfig:
    """测试保存配置"""

    def test_save_config_new_file(self, temp_dir, sample_config):
        """测试保存到新文件"""
        config_path = temp_dir / "new_config.json"

        save_config(sample_config, config_path)

        assert config_path.exists()
        loaded = json.loads(config_path.read_text())
        assert loaded["repos"] == sample_config["repos"]

    def test_save_config_overwrite(self, temp_dir, sample_config):
        """测试覆盖已存在的文件"""
        config_path = temp_dir / "config.json"
        config_path.write_text("{}")

        save_config(sample_config, config_path)

        loaded = json.loads(config_path.read_text())
        assert len(loaded["repos"]) == 2

    def test_save_config_creates_parent_dirs(self, temp_dir, sample_config):
        """测试自动创建父目录"""
        config_path = temp_dir / "subdir" / "config.json"

        save_config(sample_config, config_path)

        assert config_path.exists()


class TestAddRepo:
    """测试添加仓库"""

    def test_add_new_repo(self, sample_config):
        """测试添加新仓库"""
        config = sample_config.copy()
        config["repos"] = sample_config["repos"].copy()

        updated = add_repo(config, "new-project", "/path/to/new-project")

        assert len(updated["repos"]) == 3
        assert any(r["name"] == "new-project" for r in updated["repos"])

    def test_add_duplicate_repo_updates_path(self, sample_config):
        """测试添加重复仓库时更新路径"""
        config = sample_config.copy()
        config["repos"] = sample_config["repos"].copy()

        updated = add_repo(config, "ai-video-collection", "/new/path")

        # 数量不变
        assert len(updated["repos"]) == 2
        # 路径已更新
        repo = next(r for r in updated["repos"] if r["name"] == "ai-video-collection")
        assert repo["path"] == "/new/path"


class TestRemoveRepo:
    """测试移除仓库"""

    def test_remove_existing_repo(self, sample_config):
        """测试移除已存在的仓库"""
        config = sample_config.copy()
        config["repos"] = sample_config["repos"].copy()

        updated = remove_repo(config, "bandy-ai")

        assert len(updated["repos"]) == 1
        assert not any(r["name"] == "bandy-ai" for r in updated["repos"])

    def test_remove_non_existing_repo(self, sample_config):
        """测试移除不存在的仓库"""
        config = sample_config.copy()
        config["repos"] = sample_config["repos"].copy()

        updated = remove_repo(config, "non-existing")

        # 数量不变
        assert len(updated["repos"]) == 2


class TestGetRepos:
    """测试获取仓库列表"""

    def test_get_repos_from_config(self, sample_config):
        """测试从配置获取仓库列表"""
        repos = get_repos(sample_config)

        assert len(repos) == 2
        assert any(r["name"] == "ai-video-collection" for r in repos)
        assert any(r["name"] == "bandy-ai" for r in repos)

    def test_get_repos_empty_config(self):
        """测试空配置"""
        repos = get_repos({"repos": []})

        assert repos == []


class TestValidateRepo:
    """测试验证仓库"""

    def test_validate_valid_repo(self, mock_git_repo):
        """测试有效的 Git 仓库"""
        is_valid, error = validate_repo(mock_git_repo)

        assert is_valid is True
        assert error is None

    def test_validate_non_existing_path(self, temp_dir):
        """测试不存在的路径"""
        non_existing = temp_dir / "non_existing"

        is_valid, error = validate_repo(non_existing)

        assert is_valid is False
        assert "不存在" in error

    def test_validate_non_git_directory(self, temp_dir):
        """测试非 Git 目录"""
        normal_dir = temp_dir / "normal"
        normal_dir.mkdir()

        is_valid, error = validate_repo(normal_dir)

        assert is_valid is False
        assert "Git" in error


class TestGetConfigPath:
    """测试获取配置路径"""

    def test_get_default_config_path(self):
        """测试获取默认配置路径"""
        path = get_config_path()

        assert path.name == "config.json"
        assert ".weekly-reports" in str(path)

    def test_get_config_path_with_custom_base(self, temp_dir):
        """测试使用自定义基础目录"""
        path = get_config_path(base_dir=temp_dir)

        assert path.parent == temp_dir
        assert path.name == "config.json"
