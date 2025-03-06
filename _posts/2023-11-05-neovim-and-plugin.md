---
layout: post
title:  "2023年vim转neovim,及基础插件安装"
date:   2023-11-05 22:37:00
categories: 实践记录
tags: vim neovim 
excerpt: 适用于熟悉vim但不熟悉neovim同时又想转向neovim的小伙伴
mathjax: true
---

### 历史，以及优缺点

2013年第一次使用vim,从此vim一直是我Linux上唯一的编辑器。

因为都在写c/c++,这些年基本就是ctag,cscope,tlist这几个主要插件，主题molokai，最多再配置一下补全功能ycm。
在阅读以C为主的代码时通常是足够的，而且跳转速度极快。加入新团队后,发现原先的方案已经落伍了。
首先就是在解析c++方面静态解析不够强大，其次是除c/c++之外的语言解析不够强大。
在看到同事使用lsp跳转之后，当即决定转向lsp。
当前vim8上的LSP体验已经很强大，远超ctag跟cscope的跳转功能，
补全功能也要比ycm的配置方便很多。

为了快速用起来，直接使用了github上开源的配置方案，
在使用一段时间后，一些问题逐渐暴露出来。
首先就是很多插件对vim8的支持不够友好，插件有版本不兼容的问题。
为了不影响使用不断删除不兼容的插件，由于插件之间也有相互依赖，到最后变成一坨速度又慢，又不够好用的配置。

其次如果为了兼容升级vim9话, 由于我一直用的是ubuntu LTS版本，22.04目前默认的版本是vim8,
而macos上已经时vim9,两者不能通用，需要在ubuntu上安装新版本。且vim9很多又与vim8也不够兼容,与其重新适应vim9,不如直接neovim。

最后是目前最活跃的插件，对neovim的支持更好，最终决定直接从vim8转向neovim。

neovim目前最大的问题就是仍然在快速迭代，特别是插件，过几个月可能就需要更换一批，
比如之前的packer,null-ls等。尽管如此，我还是希望尝试neovim。


### neovim入门介绍

neovim作为vim的重构版本，用户使用上与vim并没有什么区别，区别主要是软件本身的区别。

尽管neovim也兼容vim的配置，不过个人更倾向于更neo的配置。neovim配置文件默认位于~/.config/nvim/中
默认会加载目录下的init.vim或init.lua,init.vim支持vimscript语法，init.lua是lua语法。
所以使用init.vim更容易从.vimrc迁移过来，没有任何成本。尽管如此我更倾向于直接使用init.lua。

init.lua内即可按照lua语法进行配置，为了模块化条理化，通常都会把配置分层。

### 基本插件及作用介绍 

跳转，补全，颜色主体，及按键映射这几个应该是必不可少。

- lazy.nvim

当前(2023年)neovim最推荐的插件管理工具，类似于vim-plug或者vundle, lazy.nvim之前是packer.nvim,
packer.nvim已经停更了，所以推荐packer的blog已经过时了。
安装方法参考[官方说明](https://github.com/folke/lazy.nvim):

```lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
```
想要使用lazy安装其他插件就再添加一行即可（替换yourplugin为你要添加的插件):

```lua
require("lazy").setup("yourplugin")
```

比如我安装了下面介绍的插件，可以使用:

```lua
  require("lazy").setup({    
      "neovim/nvim-lspconfig",    
      "williamboman/mason.nvim",    
      "williamboman/mason-lspconfig.nvim",    
      "hrsh7th/cmp-nvim-lsp",    
      "hrsh7th/cmp-buffer",    
      "hrsh7th/cmp-path",    
      "hrsh7th/cmp-cmdline",    
      "hrsh7th/nvim-cmp",    
      "hrsh7th/cmp-vsnip",    
      "hrsh7th/vim-vsnip"    
  })
```

之后保存退出，再在终端输入nvim启动，即可自动安装

- neovim/nvim-lspconfig

从名字可以看出来是neovim官方的lsp服务配置插件

- williamboman/mason.nvim

lsp server的管理插件，可以用来下载安装各种server

- williamboman/mason-lspconfig.nvim

连接mason.nvim与lspconfig的插件,与mason是一个作者

- hrsh7th/nvim-cmp

补全插件，根据作者的说明，还要几个辅助插件用于设置补全来源，
来源我只用了作者这一个，可以根据作者说明添加其他的.依赖的插件如下：

```bash
"hrsh7th/cmp-nvim-lsp",
"hrsh7th/cmp-buffer",
"hrsh7th/cmp-path",
"hrsh7th/cmp-cmdline",
"hrsh7th/cmp-vsnip",
"hrsh7th/vim-vsnip"
```

- 主题颜色

我没用插件，手动下载`molokai.vim`后放到.config/nvim/colors文件夹内，
然后在init.lua中添加`vim.cmd('colorscheme '..'molokai')`即可。

这样其实是使用的vim script。

- 按键映射

基本只设置了一些跟lsp跳转相关的映射:

```lua
map("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opt)    
map("n", "gh", "<cmd>lua vim.lsp.buf.hover()<CR>", opt)    
map("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opt)    
map("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opt)    
map("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opt)    
-- diagnostic           
map("n", "gp", "<cmd>lua vim.diagnostic.open_float()<CR>", opt)    
map("n", "gk", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opt)    
map("n", "gj", "<cmd>lua vim.diagnostic.goto_next()<CR>", opt)    
map("n", "<leader>f", "<cmd>lua vim.lsp.buf.format()<CR>", opt) 
```

至此基本配置已经完成，有几点需要注意，`require.("lazy").setup(...)`这步只是使用lazy下载了插件，
具体要加载插件也需要对具体的插件使用`require`，比如：

```
 require("mason").setup()    
  require("mason-lspconfig").setup({    
      ensure_installed = {    
      "lua_ls",           
      "bashls",           
      "clangd",           
      "pyright",          
      "gopls",            
      }                   
  })
```
至于具体require的名字及参数，可参考各自的插件主页。

我自己的配置主页非常简陋，也缺乏条理，不推荐，
不过从没接触过neovim,希望学习如何配置的话，倒是可以稍作参考[vim-config](https://github.com/leeyeel/vim-config)

### 其他插件补充

以下插件是我在使用中逐渐添加的插件，原则上还是以避免花里胡哨为主。

- nvim-tree

用于展示文件列表，方便查找文件,类似的插件有neo-tree及nvim-tree,
尽管实际上发现自动加载显示文件列表有些多余。
总之喜欢哪个都可以，初体验的话区别不大，我选用的是nvim-tree。

使用nvim-tree需要在lazy中添加对应名称:
```lua
  require("lazy").setup({
        ...
      "nvim-tree/nvim-tree.lua",
      {
          'akinsho/bufferline.nvim',
          version = "*",
          dependencies = 'nvim-tree/nvim-web-devicons'
      }
  })
```
还需要启用nvim-tree,使用默认配置即可:

```lua
require("nvim-tree").setup() 
```

到这里重启nvim后就可使用了，输入":NvimTreeOpen"即可显示文件，为了更方便，可定义个快捷键:
```lua
map("n", "<A-m>", ":NvimTreeToggle<CR>", opt) 
```
这样按键`alt + m`即可打开或关闭文件浏览，很方便。

- stevearc/aerial.nvim

类似于之前的taglist的功能，不再使用taglist的原因是taglist是基于静态扫描的，不是基于lsp的。

显示大纲的候选插件有[symbols-outline.nvim](https://github.com/simrat39/symbols-outline.nvim#configuration)
及[aerial.nvim](https://github.com/stevearc/aerial.nvim),但是前者没有内置选项可以在加载文件时自动显示大纲，
issues中有人提到这个问题，尽管有回复说是可以通过在lsp`on_attach`中调用`open_outline()`可实现自动显示，
但尝试过在多个时机调用`open_outline()`均无法在打开文件时自动显示大纲。

选择aerial.nvim插件，它的配置更丰富，使用也更简单，不过注意该插件依赖`nvim-treesitter/nvim-treesitter`,
及`nvim-tree/nvim-web-devicons`,因此需要先安装这两个，使用lazy管理插件可直接安装这三个:

```lua
  require("lazy").setup({
    ...
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
    "stevearc/aerial.nvim",
  })
```

需要注意的是，如果希望打开文件时自动显示大纲，需要开启`open_automatic`,即：

```lua
require("aerial").setup({
    open_automatic = true,
})
```

还有需要注意的是,aerial使用了很多特殊字符，在通常的字体中可能没有，会表现为乱码。
解决方法是安装个[nerd font](https://www.nerdfonts.com/font-downloads),我使用UbuntuMono nerd font,
下载安装后，在Terminal中设置为这个字体即可。

同时还希望可以方便的打开关闭，可添加个快捷键，我使用的是`alt + l`，方法如下:

```lua
map("n", "<A-l>", ":AerialToggle<CR>", opt)
```

- bufferline.nvim

主要作用是把buffer中的文件像Terminal中的tab一样显示,类似于SourceInsight从3.5进化到4.0，跳转时有标签页

使用layz安装:

```lua
require("lazy").setup({
        ...
      {
          'akinsho/bufferline.nvim',
          version = "*",
          dependencies = 'nvim-tree/nvim-web-devicons'
      } 
```
使用下面的选项跳过左侧nvimtree:

```lua
  require("bufferline").setup {
      options = {
          diagnostics = "nvim_lsp",
          offsets = {{
              filetype = "NvimTree",
              text = "File Explorer",
              highlight = "Directory",
              text_align = "left"
          }}
      }
  }
```

为了方便跳转Tab,可使用几个快捷键:

```lua
  map("n", "<C-h>", ":BufferLineCyclePrev<CR>", opt)
  map("n", "<C-l>", ":BufferLineCycleNext<CR>", opt)
```
这样按`ctl + h`可以向左查看tab,按`ctl + l`可以向右查看tab。

最终效果如图:

![]({{site.url}}assets/nvim/1.png)

