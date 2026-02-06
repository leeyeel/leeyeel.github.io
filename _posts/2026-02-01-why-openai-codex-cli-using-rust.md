---
layout: post
title:  "OpenAI/Codex CLI 为什么选择了Rust作为开发语言"
date:   2026-02-1 13:22:00
categories: Agent
tags: OpenAI Codex Agent 
excerpt: OpenAI/Codex CLI为什么选择Rust作为他们的开发语言
mathjax: true
---
* TOC
{:toc}

![]({{site.url}}assets/openai/codex2/codex1.webp)

尽管当今主流编程语言多达数十种，甚至上百种，但真正适合Codex这类工程级 CLI Agent 的选择其实并不多。
在我看来，现实可行的候选语言其实只有两种：Golang与Rust。
本文最后会专门分析 Codex 为什么最终选择了 Rust 而不是 Golang，
在此之前，我们先采用排除法，介绍下为什么其他语言并不合适。

2025 年 2 月份，Anthropic首次发布Claude Code时选择的语言就是 TypeScript。
此后陆续出现的多款 Agent 几乎无一例外延续了这一技术路线，例如Codex CLI与Gemini CLI。
TypeScript 为什么会成为当时主流Agent 的默认选择呢？本质原因只有一个：快。

作为 Agent 赛道的鼻祖，Anthropic 需要迅速验证用户是否真正接受“代码级 AI 助手”这一形态。
因此，语言选择必须满足几个条件：性能足够、语法成熟、工程生态完善、开发周期短。
从现实角度看，真正符合这些条件的“胶水语言”只有 Python 与 JavaScript / TypeScript。
至于 Shell、Perl、Ruby、Lua 等语言，要么老（如 Perl），要么挫（如 Shell），
要么并不适合构建复杂交互界面（如 Lua、Shell），要么在分发和环境管理上存在明显劣势（如 Ruby）。
在 TypeScript 已经存在的情况下，JavaScript 这种Debug复杂项目自己就头晕的语言，自然被边缘化。

因此，2025 年年初那个时间点，真正问题其实只有一个：为什么选择 TypeScript，而不是 Python？

在我看来，原因主要有两点。
第一是要与 IDE 集成的现实需求。尤其是在需要深度集成VS Code的场景下，TypeScript 与 VS Code 本身同根同源，
可以直接复用其插件体系与前端能力；
如果使用 Python，除了本身作为服务端运行，
则几乎不可避免地需要额外构建一个 TypeScript/JavaScript 前端外壳，增加系统复杂度。

第二是交互体验问题，直白地说就是，
目前所有Python 构建出来的 TUI（终端用户界面）都丑，
在视觉和交互细节上处于劣势，这一点在 Linux 终端下尤为明显。
无论是当时还是现在，Python CLI 在“好看”这件事上确实很难与 TypeScript 生态抗衡，
不信可以去Linux下安装Trae-Agent CLI体验下。

![]({{site.url}}assets/openai/codex2/codex2.webp)

那么问题就来了：既然 TypeScript 在如此合适，Codex 为什么又在 2025 年 6 月宣布使用 Rust 重写？

![]({{site.url}}assets/openai/codex2/codex3.webp)

这是因为，所有脚本语言都难以回避的一个工程级问题：运行时依赖冲突。
以 Claude Code 为例，它要求 Node.js ≥ 20，
但用户本地项目很可能被强绑定在 Node 18 上。
当用户为了使用 Claude Code 升级 Node 时，原有项目可能无法运行；
而一旦为了兼容项目而降级 Node，Claude Code 又无法使用。
这种冲突在真实开发环境中几乎不可调和，也直接导致 Agent 无法顺利参与项目调试。

有没有解决方案呢？有。一种解决思路是，在分发 Agent 时直接捆绑运行时(Runtime)。
事实上Claude Code 目前(2025年11月份开始)就是这么做的。
早期 Claude Code 的安装包体积只有几十 MB，安装后的文件是一个单独的JS文件，
而在 2025 年 11 月引入“原生安装模式”后，
安装体积迅速膨胀到 1GB 以上，其核心原因正是：
在安装 Agent 的同时一并分发运行时（Runtime），以换取环境一致性。

![]({{site.url}}assets/openai/codex2/codex4.webp)

但这显然是一种“用空间换兼容性”的折中方案。

那么有没有一种方案，既不显著牺牲分发体积，
又能彻底避免与用户环境产生冲突？答案依然肯定的，
即直接使用编译型语言，例如 C / C++、Rust、Golang。这类语言的编译产物是原生可执行文件，
不依赖外部解释器或虚拟机，用户无需额外安装特定语言运行环境，
既能保持体积可控，又能彻底规避运行时冲突。

但是代价是什么呢，代价是开发成本更高了，
实际上不光是开发成本更高，还可能面临开发周期更长的问题。
像OpenAI这样直接使用Rust重写，
本身不差钱不在乎这些开发成本，考虑可能更多是开发周期问题，
即便起步已经落后了，
但是依然敢于换语言重写，确实很OpenAI，永远在开疆拓土。

接下来就回到了最后一个问题：Codex 为什么选择 Rust，而不是 Golang？

主流编译型语言中,C/C++首先被排除。先看 C 语言，C 足够简单，但也过于“原始”，
缺乏现代工程所需的官方级基础设施，例如成熟的 UI / TUI 支持。
这意味着 Codex 连基本交互界面都需要从零实现，几乎不现实。
C++ 的情况稍好一些，但仍然存在同样的问题：开发成本高，但是又高的没有性价比，
工程复杂度大、UI 生态割裂，虽然语言本身仍然在不断更新保持了足够的现代化，
但是这种转变同样意味着新特性缺少足够的成熟库支持。
选择这样一种稍显老态龙钟的语言有些不符合OpenAI激进的风格。

相比之下Rust 年轻，也更符合当代系统工程的价值取向：无需手动内存管理、
性能接近 C/C++、安全性强、工具链完善，
同时兼具工程界与学院界的认可。
从技术审美的角度看，它几乎是“品学兼优”的好学生，受到 Codex 开发者青睐并不意外。

但是Golang说: "等等，你说的这些我也有啊"。
是的，从工程成熟度来看，Golang 并不逊色，甚至在生态和工程效率上更胜一筹。
Go 同样支持单文件分发，语言更简单，也完全能够兼顾性能与开发效率。
然而，技术决策从来不只由技术决定。
Golang 错就错在Golang的爹是Google，而 Google 恰恰是OpenAI的直接竞争对手。
在这种背景下OpenAI 选择 Rust而非 Golang，几乎是一种顺理成章理所当然的决策，
无关Golang是否更合适 ——就像阿里内部也不会选择企业微信作为官方协作工具一样。

