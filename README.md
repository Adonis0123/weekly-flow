# Weekly Flow

Claude Code Skill - 自动读取 Git 提交记录生成周报

## 功能特性

- 自动读取 Git 提交记录
- 支持多仓库汇总
- 自动识别当前用户 (`git config user.name`)
- 按项目分组，生成结构化周报
- 过滤琐碎提交（typo、merge、format 等）
- 支持添加补充说明
- 周报统一存储在 `~/.weekly-reports/` 目录

> 多分支说明：读取提交时应使用 `git log --all` 覆盖本地分支与远端跟踪分支；若本地未 fetch 到目标远端分支，需要先 `git fetch --all --prune`，否则会漏掉其它分支的提交。

## 安装

### 方式一：一键安装

```bash
# 克隆仓库
git clone https://github.com/your-username/weekly-flow.git
cd weekly-flow

# 运行安装脚本
chmod +x install.sh
./install.sh
```

### 方式二：手动安装

```bash
# 克隆仓库
git clone https://github.com/your-username/weekly-flow.git

# 复制到 Claude Code skills 目录
cp -r weekly-flow ~/.claude/skills/weekly-report
```

### 方式三：项目级安装（团队共享）

```bash
# 在项目根目录创建
mkdir -p .claude/skills
cp -r weekly-flow .claude/skills/weekly-report

# 提交到 Git
git add .claude/skills/weekly-report
git commit -m "feat: add weekly-report skill"
```

## 使用方式

在任意 Git 项目目录中执行：

```
/weekly-report
```

### 执行流程

1. **选择时间范围**
   - 本周
   - 上周
   - 自定义（输入周一日期）

2. **选择仓库**（如已配置多仓库）
   - 显示已配置的仓库列表
   - 可多选要包含的仓库

3. **添加补充内容**（可选）
   - 输入额外的工作内容

4. **生成周报**
   - 保存到 `~/.weekly-reports/{year}/week-{week}.md`

## 配置

配置文件位于 `~/.weekly-reports/config.json`：

```json
{
  "repos": [
    {
      "name": "project-a",
      "path": "/path/to/project-a"
    },
    {
      "name": "project-b",
      "path": "/path/to/project-b"
    }
  ],
  "default_author": "auto",
  "output_format": "markdown"
}
```

## 输出示例

```markdown
ai-video-collection
  - turbopack 升级改造
  - Agent 开发流程跟进
    - 方案合理性优化
  - 油猴脚本国际化优化

bandy-ai
  - 自定义类型化消息渲染
  - 断线重连流程梳理

其他
  - 新版国际化方案讨论
```

## 开发

### 安装开发依赖

```bash
# 使用 uv
uv pip install -e ".[dev]"

# 或使用 pip
pip install -e ".[dev]"
```

### 运行测试

```bash
# 运行所有测试
uv run pytest tests/ -v

# 运行特定模块测试
uv run pytest tests/test_git_analyzer.py -v

# 查看覆盖率
uv run pytest tests/ --cov=src --cov-report=html
```

### 项目结构

```
weekly-flow/
├── SKILL.md                    # Skill 核心配置
├── references/
│   └── WEEKLY_REPORT_FORMAT.md # 周报格式规范
├── src/                        # 源码目录
│   ├── date_utils.py           # 日期处理
│   ├── git_analyzer.py         # Git 分析
│   ├── report_generator.py     # 周报生成
│   ├── config_manager.py       # 配置管理
│   └── storage.py              # 存储管理
├── tests/                      # 测试目录
├── install.sh                  # 安装脚本
└── README.md                   # 使用文档
```

## 许可证

MIT License
