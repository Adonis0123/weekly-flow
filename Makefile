.PHONY: install test coverage clean lint format help

# 默认目标
help:
	@echo "Weekly Flow - 可用命令:"
	@echo ""
	@echo "  make install    安装开发依赖"
	@echo "  make test       运行测试"
	@echo "  make coverage   运行测试并生成覆盖率报告"
	@echo "  make clean      清理临时文件"
	@echo "  make install-skill  安装 Skill 到 Claude Code"
	@echo ""

# 安装开发依赖
install:
	uv pip install -e ".[dev]"

# 运行测试
test:
	uv run pytest tests/ -v

# 运行测试并生成覆盖率报告
coverage:
	uv run pytest tests/ --cov=src --cov-report=html --cov-report=term-missing
	@echo "覆盖率报告已生成: htmlcov/index.html"

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

# 安装 Skill 到 Claude Code
install-skill:
	chmod +x install.sh
	./install.sh
