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

### 方式一：一键安装（推荐）

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/Adonis0123/weekly-flow/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/Adonis0123/weekly-flow/main/install.ps1 | iex
```

### 方式二：下载发布包安装

从 [Releases](https://github.com/Adonis0123/weekly-flow/releases) 页面下载最新版本。

**macOS / Linux:**

```bash
# 下载并解压
curl -LO https://github.com/Adonis0123/weekly-flow/releases/latest/download/weekly-flow-v1.0.1.tar.gz
tar -xzf weekly-flow-v1.0.1.tar.gz
cd weekly-flow-v1.0.1

# 运行安装脚本
./install.sh
```

**Windows:**

1. 下载 `weekly-flow-v1.0.1.zip`
2. 解压到任意目录
3. 在 PowerShell 中运行：`.\install.ps1`

### 方式三：克隆仓库安装

```bash
# 克隆仓库
git clone https://github.com/Adonis0123/weekly-flow.git
cd weekly-flow

# 运行安装脚本
./install.sh           # macOS/Linux
.\install.ps1          # Windows PowerShell
```

### 方式四：手动安装

```bash
# 克隆仓库
git clone https://github.com/Adonis0123/weekly-flow.git

# 复制到 Claude Code skills 目录
cp -r weekly-flow ~/.claude/skills/weekly-report
```

### 方式五：项目级安装（团队共享）

```bash
# 在项目根目录创建
mkdir -p .claude/skills
cp -r weekly-flow .claude/skills/weekly-report

# 提交到 Git
git add .claude/skills/weekly-report
git commit -m "feat: add weekly-report skill"
```

## 使用方式

### 前置条件

需要先安装并启动 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)：

```bash
# 安装 Claude Code
npm install -g @anthropic-ai/claude-code

# 在任意 Git 项目目录中启动
claude
```

### 执行命令

在 Claude Code 会话中输入：

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
# 周报 (2026-01-06 ~ 2026-01-12)

project-frontend
  - 构建工具升级改造
  - 核心功能开发流程跟进
    - 方案合理性优化
  - 脚本国际化优化

project-backend
  - 自定义类型化消息渲染
  - 断线重连流程梳理

其他
  - 新版国际化方案讨论
```

## 系统要求

| 操作系统 | 要求 |
|---------|------|
| macOS | 10.15+ (Catalina 或更高) |
| Linux | 任意现代发行版 (Ubuntu 18.04+, CentOS 7+, etc.) |
| Windows | Windows 10/11 + PowerShell 5.1+ |

**依赖:**
- Git 2.0+
- Claude Code CLI

## 开发

### 安装开发依赖

```bash
# 使用 uv
uv pip install -e ".[dev]"

# 或使用 pip
pip install -e ".[dev]"

# 或使用 make
make install-dev
```

### 运行测试

```bash
# 运行所有测试
make test

# 查看覆盖率
make coverage
```

### 构建发布包

```bash
# 构建 tar.gz 和 zip 包
make build

# 发布文件位于 dist/ 目录
```

### 一键发布

确保已安装并登录 [GitHub CLI](https://cli.github.com/)：

```bash
# 安装 gh (macOS)
brew install gh

# 登录
gh auth login
```

执行一键发布：

```bash
make publish
```

会显示交互式菜单：

```
当前版本: v1.0.0

请选择版本更新类型:

  1) patch  - 补丁版本 (bug 修复)        -> v1.0.1
  2) minor  - 次要版本 (新功能，向后兼容) -> v1.1.0
  3) major  - 主要版本 (重大变更)        -> v2.0.0
  4) custom - 自定义版本号
  5) cancel - 取消发布
```

选择后自动完成：
1. 更新版本号
2. 提交并创建 Git tag
3. 构建发布包
4. 推送 tag（GitHub Actions 会自动创建 Release）

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
├── scripts/                    # 脚本目录
│   ├── build-release.sh        # 构建发布包脚本
│   └── release.sh              # 一键发布脚本
├── tests/                      # 测试目录
├── install.sh                  # macOS/Linux 安装脚本
├── install.ps1                 # Windows 安装脚本
├── Makefile                    # 开发命令
└── README.md                   # 使用文档
```

## 更新

重新运行安装脚本即可更新（默认会全量覆盖）：

```bash
curl -fsSL https://raw.githubusercontent.com/Adonis0123/weekly-flow/main/install.sh | bash
```

## 卸载

```bash
# 删除 Skill
rm -rf ~/.claude/skills/weekly-report

# 删除配置和周报（可选）
rm -rf ~/.weekly-reports
```

## 许可证

MIT License
