# blog.whatsroot.xyz

基于 Jekyll 构建的个人博客仓库，代码托管在 GitHub，站点部署在 Cloudflare Pages。

## 本地开发

安装依赖：

```bash
bundle install
```

启动本地预览：

```bash
bundle exec jekyll serve
```

默认访问地址：

```text
http://127.0.0.1:4000
```

## 目录说明

- `_posts/`: 博客文章
- `page/`: 独立页面，如归档、分类、关于
- `_layouts/` / `_includes/` / `_sass/`: Jekyll 模板与样式
- `assets/`, `css/`, `js/`: 静态资源
- `_config.yml`: 站点配置

## 部署

站点通过 Cloudflare Pages 从 `master` 分支自动部署，线上域名为：

```text
https://blog.whatsroot.xyz
```

## IndexNow

仓库已接入 IndexNow 自动提交：

- key 文件位于仓库根目录：`c0b8a0805b6846729f5d0e69605f44c6.txt`
- GitHub Actions 工作流位于 `.github/workflows/indexnow.yml`
- 提交脚本位于 `scripts/indexnow_submit.rb`

行为说明：

- 向 `master` 推送后，工作流会先计算本次要提交的 URL，再等待 Cloudflare Pages 上的线上 URL 可访问，然后才提交 IndexNow
- 手动运行 `Submit IndexNow URLs` 时，默认只提交最新一次 commit 涉及的可索引 URL；只有勾选 `full_scan` 时才执行全站提交
- 等待阶段会检查这几个基础 URL：
  - `https://blog.whatsroot.xyz/robots.txt`
  - `https://blog.whatsroot.xyz/sitemap.xml`
  - `https://blog.whatsroot.xyz/c0b8a0805b6846729f5d0e69605f44c6.txt`
- 对本次变更涉及的页面，工作流会做线上可访问性探测：
  - 少量变更时，检查全部新增/更新 URL
  - 大量变更或全站提交时，只抽样检查前 5 个和后 5 个 URL，避免等待过久
- 删除的页面不会参与“等待上线”检查，但仍会按 IndexNow 规范提交给搜索引擎
- 标记为 `robots: noindex,follow` 或 `sitemap: false` 的页面不会被提交到 IndexNow

手动本地 dry-run：

```bash
ruby scripts/indexnow_submit.rb --dry-run
ruby scripts/indexnow_submit.rb --dry-run --full
```

如需同时输出“等待上线检查”用的 URL 列表，可使用：

```bash
ruby scripts/indexnow_submit.rb --dry-run --write-wait-url-list indexnow_wait_urls.txt
ruby scripts/indexnow_submit.rb --dry-run --full --write-wait-url-list indexnow_wait_urls.txt
```
