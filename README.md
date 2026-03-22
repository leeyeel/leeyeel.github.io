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

- 向 `master` 推送后，会自动提交本次变更涉及的文章和页面 URL
- 在 GitHub Actions 中手动运行 `Submit IndexNow URLs`，会执行一次全站 URL 提交

手动本地 dry-run：

```bash
ruby scripts/indexnow_submit.rb --dry-run
ruby scripts/indexnow_submit.rb --dry-run --full
```
