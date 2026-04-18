---
layout: post
title:  "如何用 GitHub Actions 自部署 GitHub Readme Stats，并统计私有仓库数据"
date:   2026-04-04 16:02:00
categories: "博客与建站"
tags:
  - "GitHub"
  - "GitHub-Actions"
  - "GitHub-Readme-Stats"
  - "README"
description: "介绍如何通过 GitHub Actions 自部署 GitHub Readme Stats，并使用 PAT 统计私有仓库与 Top Languages 数据。"
keywords: "GitHub Readme Stats, GitHub Actions, GitHub Profile README, 私有仓库统计, PAT"
excerpt: "介绍如何通过 GitHub Actions 自部署 GitHub Readme Stats，并使用 PAT 统计私有仓库数据。"
mathjax: true
---
* TOC
{:toc}

### 故事背景

![我的stats]({{ '/assets/github-readme-stats/2.png' | relative_url }})

经常逛 GitHub 的人，应该都见过个人主页上的这种统计卡片。
这背后常见的实现方案，就是 **GitHub Readme Stats**。
它的统计原理是通过调用 GitHub API 获取用户的公共或私有数据，
然后通过动态生成的 SVG 图像呈现出来。

但是最近，由于用户量的增加，**GitHub Readme Stats** 的公共实例在 Vercel 上面临了流量和额度超限的问题，
导致许多用户无法加载其统计卡片。官方在其 GitHub 仓库的说明中指出：

![官方声明]({{ '/assets/github-readme-stats/0.png' | relative_url }})

这件事有多严重呢？比如下面，不仅我自己的统计无法显示，甚至 GitHub Readme Stats 官方仓库的统计也无法显示了。

![我的stats无法显示了]({{ '/assets/github-readme-stats/1.png' | relative_url }})

![官方的也无法显示]({{ '/assets/github-readme-stats/3.png' | relative_url }})

官方声明中提到，虽然公共实例通过缓存来提高稳定性，但由于流量高峰和 API 限制，卡片显示已经不再稳定。
为了避免此问题，官方建议用户自行托管服务（如 Vercel 或其他平台），
或者使用 **GitHub Actions** 工作流生成卡片并存储在个人仓库中。

下面就介绍一种几乎零维护的方案：直接用 GitHub Actions 生成静态 SVG，同时支持私有仓库统计。

### 通过 GitHub Actions 自部署 GitHub Readme Stats

为了避免公共实例的流量限制，可以选择通过 **GitHub Actions** 自行部署 GitHub Readme Stats。
这种方法最简单，不需要自行设置服务器，相比于自己部署 Vercel 服务，
它的部署过程更方便。只需要在个人 GitHub 仓库中配置一次 GitHub Actions 工作流，
GitHub 将自动为你生成并更新统计卡片，避免了公共服务的限制。

这个方法甚至不需要 fork 官方仓库，只需要在自己的 README 仓库
（也就是与你 GitHub 用户名同名的仓库）中，新建一个 workflow 即可。

比如我的仓库原来只有一个 `README.md` 文件，现在只需要新建
`.github/workflows/github-readme-stats.yml`，填入以下内容：

```yaml
name: Update README cards

on:
  schedule:
    - cron: "0 3 * * *"  # 每天更新一次
  workflow_dispatch:  # 允许手动触发

permissions:
  contents: write  # 允许工作流提交生成后的 SVG

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Generate stats card
        uses: readme-tools/github-readme-stats-action@v1
        with:
          card: stats
          options: username=${{ github.repository_owner }}&show_icons=true
          path: profile/stats.svg
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Generate top languages card
        uses: readme-tools/github-readme-stats-action@v1
        with:
          card: top-langs
          options: username=${{ github.repository_owner }}&layout=compact&langs_count=6
          path: profile/top-langs.svg
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Commit cards
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add profile/*.svg
          git commit -m "Update README cards" || exit 0
          git push
```

注意这里生成的图片位置分别是 `profile/stats.svg` 和 `profile/top-langs.svg`，
所以需要你在 `README.md` 中把原来对公共实例的引用，替换成本仓库里的静态文件，例如：

```markdown
![Stats](./profile/stats.svg)
![Top Languages](./profile/top-langs.svg)
```

然后提交代码。由于上述配置是每天生成一次，所以第一次通常需要你到 GitHub Actions 页面手动触发一次。

### 如何使用 GitHub Actions 配置统计私有仓库数据

#### 1. 生成 Personal Access Token (PAT) 以统计私有仓库

如果你希望通过 **GitHub Actions** 统计 **私有仓库** 的数据，
必须生成一个 **Personal Access Token (PAT)**，
因为默认工作流中使用的 `GITHUB_TOKEN` 更适合当前仓库内的自动化操作，
并不适合拿来读取你账号下所有私有仓库的统计信息。
要统计私有仓库数据，更稳妥的做法是使用你自己创建的 **PAT**。

#### **如何生成 Personal Access Token (PAT)**：

1. **登录 GitHub**：

   * 访问 [GitHub](https://github.com/) 并登录到你的账户。

2. **进入开发者设置**：

   * 在 GitHub 首页右上角点击头像，选择 **Settings**。
   * 在左侧菜单中，选择 **Developer settings**。

![生成PAT]({{ '/assets/github-readme-stats/4.png' | relative_url }})

3. **生成 Personal Access Token**：

   * 在 **Developer settings** 中选择 **Personal access tokens**。如果只是为了统计私有仓库，建议直接使用 **Tokens (classic)**。
   * 点击 **Generate new token** 创建一个新的 token。
   * 根据 GitHub Readme Stats 官方说明，如果要读取私有仓库统计，至少需要以下权限：

     * **repo**：允许访问私有仓库。
     * **read:user**：访问用户数据（用于获取贡献信息等）。

   官方文档还提到，**fine-grained token** 在这个场景下对私有贡献统计并不理想，
   因此这里更推荐 classic PAT。

4. **生成并保存 Token**：

   * 设置 **Token description**（例如 "GitHub Stats Token"）并选择所需的权限。

   * 点击 **Generate token**，生成后保存好这个 Token。

   > **注意**：**PAT** 生成后只能在此页面显示一次，因此请务必将其保存好。如果丢失，你将无法查看这个 Token，只能重新生成。

---

#### 2. 使用 GitHub Secrets 存储 PAT

为了避免将 **PAT** 直接暴露在工作流文件中（这将会泄露敏感信息），
我们使用 **GitHub Secrets** 来存储 Token。**GitHub Secrets** 是加密存储的环境变量，它可以在 GitHub Actions 中安全地使用，而不会被公开。

1. **进入仓库的 Settings**：

   * 在 GitHub README 这个仓库（也就是与你用户名同名的仓库）页面，点击右上角的 **Settings**。

2. **创建新的 Secret**：

   * 在左侧菜单中选择 **Secrets and variables** → **Actions**。
   * 点击 **New repository secret**。
   * 在 **Name** 中输入 `GH_TOKEN`（这是我们后续在工作流文件中使用的环境变量名称）。
   * 在 **Value** 中粘贴你生成的 **Personal Access Token (PAT)**。
   * 点击 **Add secret** 保存。

3. **在 GitHub Actions 中使用 Secret**：

   * 你可以通过 `${{ secrets.GH_TOKEN }}` 来引用在 **Secrets** 中存储的 Token。

---

#### 3. 为什么默认配置无法统计私有仓库

上面官方给出的基础配置无法统计私有仓库数据，是因为在那个配置中，
使用的是 `token: ${{ secrets.GITHUB_TOKEN }}`，
根据 GitHub Readme Stats 官方文档，默认的 `GITHUB_TOKEN` 仅适用于**公开统计**；
如果要统计私有仓库，则需要改用带 `repo` 和 `read:user` 权限的 **PAT**。

---

#### 4. 修改配置以支持私有仓库统计

为了确保 GitHub Actions 能统计私有仓库的数据，
我们需要修改配置文件，使用 **Personal Access Token (PAT)**，
并将其存储在 **GitHub Secrets** 中。以下是完整的工作流配置：

```yaml
name: Update README cards

on:
  schedule:
    - cron: "0 6 * * *"  # 每天早上6点更新
  workflow_dispatch:  # 允许手动触发

permissions:
  contents: write  # 允许 GitHub Actions 写入仓库内容

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Generate stats card
        uses: readme-tools/github-readme-stats-action@v1
        with:
          card: stats
          options: username=${{ github.repository_owner }}&show_icons=true
          path: profile/stats.svg
          token: ${{ secrets.GH_TOKEN }}  # 使用 GitHub Secrets 中存储的 PAT

      - name: Generate top languages card
        uses: readme-tools/github-readme-stats-action@v1
        with:
          card: top-langs
          options: username=${{ github.repository_owner }}&layout=compact&langs_count=6
          path: profile/top-langs.svg
          token: ${{ secrets.GH_TOKEN }}

      - name: Commit cards
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add profile/*.svg
          git commit -m "Update README cards" || exit 0
          git push
```

#### **配置解析**：

* **`permissions: contents: write`**：确保 GitHub Actions 有权限将生成的卡片推送到仓库。
* **`token: ${{ secrets.GH_TOKEN }}`**：使用存储在 GitHub Secrets 中的 **PAT**，允许读取私有仓库统计数据。
* **`top-langs`**：额外生成语言分布卡片，避免只生成总览 stats 卡片。
* **`cron: "0 6 * * *"`**：设置工作流每天凌晨六点自动更新统计卡片。

---

这种方法也有缺点，就是更新不够及时，比如我的配置是一天一次。
但是因为这个方法实在太简单太方便了，足以抵消这些缺点。
