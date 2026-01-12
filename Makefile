.PHONY: install install-dev install-skill test coverage clean lint format help build release publish

# 默认目标
help:
	@echo "Weekly Flow - 可用命令"
	@echo ""
	@echo "安装:"
	@echo "  make install-skill  安装 Skill 到 Claude Code"
	@echo "  make install-dev    安装开发依赖"
	@echo ""
	@echo "构建发布:"
	@echo "  make build          构建发布包 (tar.gz + zip)"
	@echo "  make publish        一键发布 (交互式选择版本)"
	@echo ""
	@echo "开发:"
	@echo "  make test           运行测试"
	@echo "  make coverage       运行测试并生成覆盖率报告"
	@echo "  make lint           代码检查"
	@echo "  make format         格式化代码"
	@echo "  make clean          清理临时文件"
	@echo ""

# 安装开发依赖
install-dev:
	uv pip install -e ".[dev]" || pip install -e ".[dev]"

# 安装 Skill 到 Claude Code
install-skill:
	chmod +x install.sh
	./install.sh

# 构建发布包
build:
	@chmod +x scripts/build-release.sh
	@./scripts/build-release.sh

# 创建 GitHub Release（需要 gh CLI 和推送 tag）
release: build
	@echo "提示: 请先创建并推送 tag，例如:"
	@echo "  git tag v1.0.0"
	@echo "  git push origin v1.0.0"
	@echo ""
	@echo "GitHub Actions 会自动创建 Release"
	@echo "或者手动创建:"
	@VERSION=$$(grep 'version = ' pyproject.toml | head -1 | cut -d'"' -f2); \
	echo "  gh release create v$$VERSION dist/*.tar.gz dist/*.zip dist/checksums.txt"

# 一键发布（交互式选择版本）
publish:
	@chmod +x scripts/release.sh
	@./scripts/release.sh

# 运行测试
test:
	uv run pytest tests/ -v || pytest tests/ -v

# 运行测试并生成覆盖率报告
coverage:
	uv run pytest tests/ --cov=src --cov-report=html --cov-report=term-missing || pytest tests/ --cov=src --cov-report=html
	@echo "覆盖率报告已生成: htmlcov/index.html"

# 代码检查
lint:
	uv run black --check src/ tests/ || black --check src/ tests/
	uv run isort --check-only src/ tests/ || isort --check-only src/ tests/

# 格式化代码
format:
	uv run black src/ tests/ || black src/ tests/
	uv run isort src/ tests/ || isort src/ tests/

# 清理临时文件
clean:
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -rf .coverage
	rm -rf htmlcov
	rm -rf *.egg-info
	rm -rf dist
	rm -rf build
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "清理完成"
