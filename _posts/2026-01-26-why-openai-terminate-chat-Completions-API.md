---
layout: post
title:  "OpenAI 为什么要亲手“废掉”已经成为行业标准的 Chat Completions API？"
date:   2026-01-26 23:22:00
categories: "AI与Agent"
tags:
  - "OpenAI"
  - "Codex"
  - "Responses"
  - "CLI-Agent"
  - "工程选型"
description: "分析 OpenAI 为什么放弃了已经Chat Completions API，转而使用Responses API"
keywords: "Codex, OpenAI, Chat Completions API, Responses API"
excerpt: "分析 OpenAI 为什么放弃了已经Chat Completions API 转而使用Responses API, 分析Responses API 的好处"
mathjax: true
---
* TOC
{:toc}

![]({{site.url}}assets/openai/codex3/1.png)

2026 年 1 月26日，通义千问终于支持了 OpenAI 的Responses API。
距离 OpenAI 在 2025 年 3 月首次发布这套 API已经过去了将近十个月。

这个时间差本身就很离谱。一套被 OpenAI 明确宣称“未来默认使用”的 API，
迟迟没有在国内模型生态里真正落地；而另一边，几乎所有大模型厂商的官方 Demo，
仍然清一色地在使用chat.completions。

今天我们就回到源头，重新捋一下这个问题：

Responses API 到底是什么？以及，OpenAI 为什么一定要推倒重来？

时间先拨回到 2025 年 3 月，OpenAI 正式推出了新的 /v1/responses 接口，并在官方博客中明确表示：
它的目标，是取代已经“事实性成为行业标准”的 Chat Completions API。

![]({{site.url}}assets/openai/codex3/2.png)

但实际上就。。

直到今天，如果你去看 DeepSeek、GLM、MiniMax 的官网示例代码，几乎无一例外，
仍然在使用传统的 Chat Completions。

![]({{site.url}}assets/openai/codex3/3.png)

![]({{site.url}}assets/openai/codex3/4.png)

![]({{site.url}}assets/openai/codex3/5.png)

这也很正常，因为重新推广一套 API，本身就是一件极其困难的事。
再加上这些厂商的德行就更容易理解了。重新推广一套API，不仅意味着生态迁移成本，还意味着商业风险，
比如当我们在改接口时，竞争对手（说的就是你: Anthropic）正盯着这个方向随时准备上位。

但是为什么OpenAI 为什么宁愿冒这种风险，也要亲手“放弃”Chat Completions？
这是因为，原来这套API实在太拉了，真的跟不上模型的进化速度了。

![]({{site.url}}assets/openai/codex3/6.png)

之前X上爆料了一个细节， OpenAI 内部员工发帖称，
Chat Completions 当年从设计到上线只花了不到一周时间。

当然这也算不上什么黑历史，反而是 ChatGPT 暴发年代的真实写照。
虽然模型能力确实遥遥领先，但API编写也是草台班子，也只能“先跑起来再说”。

Chat Completions 本来是为单模态文本补全设计的。后来模型开始对话了，
于是加了 system / user / assistant。再后来模型会调用函数了，
又打了 Function Call 的补丁；Function Call 不够用了，又改名成 Tool Call；
再往前一步，是定位尴尬、最终失败的 Assistants API。

这些看起来是功能升级，实际上是同一套底层抽象，被反复强行拉伸。
直到 GPT-5 这种以推理为核心能力的模型出现，问题彻底暴露。
Chat Completions 最大的结构性缺陷实际就是，这玩意：

`它不是为“执行模型”设计的。`

在2025 年 9 月的官方博客
[《Why we built the Responses API》](https://developers.openai.com/blog/responses-api)中，
OpenAI 给了一个非常形象的比喻：

`Chat Completions 就像一个侦探——每次离开房间，就会忘掉所有线索。`

原因很简单，Chat Completions 是无状态的。每一次请求，模型都会“重新来过”；
上一轮推理中付出巨大算力得到的中间结论，在下一轮请求中彻底消失。
如果你想保留，只能把它们重新塞回 prompt。而 GPT-5 这样的模型，恰恰依赖跨步骤、跨轮次的内部推理状态。
这不是工程细节问题，不是设计中不小心留下的小bug，是不断提升的模型性能与拉胯的API设计之间的矛盾。

Responses API 的改变，反而非常朴素。
它首先承认了一件事，模型在一次交互中，不只是在“说话”，而是在“做事”。
所以返回值不再是原来那样一条 message，反而采用一组有严格顺序的 Items：
有 reasoning，有 message，有 function_call，有 tool 输出，有搜索行为。
这样开发者第一次可以清楚地区分两件事，模型“说了什么”以及模型“做了什么”。

Responses API对 reasoning 的支持尤为关键。在 Responses API 中，推理状态被保存在服务端，
模型可以在多轮交互中持续思考；但这些原始推理过程又不会直接暴露给用户，
避免了原始思维链(CoT) 带来的安全与合规风险。模型终于不用再“每一轮都失忆”。
工具调用也是同样的逻辑。

在 Chat Completions 里，所谓 function calling，本质上是模型输出一段 JSON，
客户端再去猜它是不是想调用工具。而 Responses API 直接把工具调用建模成原生事件，
甚至支持服务端执行 hosted tools，避免每一步都要经你自己的后端中转。

模型可以在一次 response 里同时“想”和“做”，这才是 Agent 真正需要的执行语义。
多模态也是从一开始就被当成“一等公民”：文本、图像、音频、工具输出，
在协议层是同级结构，而不是 message 里的特殊分支。

除此之外，Responses API 还引入了一些看似不起眼、但对工程极其关键的能力：
比如 Custom Function Call；比如 previous_response_id，在服务端维护交互状态，
极大减少历史输入 token，不过Codex CLI却没有利用这一特性，
关于这一点，你也可以回看之前那篇文章：
[OpenAI/Codex CLI为什么不使用previous_response_id?](https://blog.whatsroot.xyz/2026/01/29/openai-codex-response_id/)

用一句话总结就是，Chat Completions 更适合“聊天”；Responses API 是为“会思考、会行动的 Agent”而生。
虽然看起来仅仅是一套接口升级，实际上隐含了开发模式，以及模型能力的发展方向。

作为Agent开发人员，如果你还在用 Chat Completions 搭 Agent，一定会遇到很多奇奇怪怪，
又绕又难维护的地方，大概不是因为写得不好，而是原来那套API不太行了，不妨试试Responses 这套API，
说不定问题自己就消失了。

最后最后，也希望其他模型厂家早点跟进支持Responses API，别光顾着打榜搞那些虚无缥缈的指标，这波我站千问。
