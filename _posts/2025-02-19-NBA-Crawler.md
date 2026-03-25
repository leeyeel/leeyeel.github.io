---
layout: post
title:  "使用 Node.js 抓取 ESPN NBA 比赛与球员数据：爬虫项目实践"
date:   2025-02-19 18:40:00
categories: "个人项目"
tags:
  - "NBA"
  - "爬虫"
  - "Node.js"
  - "ESPN"
  - "数据采集"
description: "介绍一个使用 Node.js 抓取 ESPN NBA 比赛、球队与球员数据的爬虫项目实践。"
keywords: "NBA 数据爬虫, ESPN 爬虫, Node.js 爬虫, 球员数据抓取"
excerpt: "介绍一个使用 Node.js 抓取 ESPN NBA 比赛、球队与球员数据的爬虫项目实践。"
mathjax: true
---

### 应用场景

侧重点并不在爬取历史数据做分析，侧重点在爬取当天的数据。

由于国内篮球氛围很极端，当然这里面原因很复杂，既有球迷的原因，
又有我们教育的原因，也有媒体为了利益故意带节奏的原因，最后是这些因素相互影响，
相互叠加，相互影响，最终形成了目前的状态。

我想做的是使用chatgpt自动完成篮球评论，从某些奇怪的角度黑或着吹某个球员，
然后获取流量。chatgpt plus可以自定义角色，这一步很简单。
为了让chatgpt的评论更真实，除了给他一些风格的要求外，
我需要给chatgpt当天比赛的数据，然后根据比赛数据发挥，所以需要爬取比赛数据。


### 代码仓库

源码在这里，很简单，就不多说了。

[github仓库地址](https://github.com/leeyeel/NBAStatsCrawler).

### 使用方式

```
node espn_scraper.js [team or teamId]    
```
The parameter can be the team name, supporting fuzzy search, or the team ID. For example, all of the following refer to the Lakers:

参数可以为队名，支持模糊搜索，也可以是球队id,比如以下都指向湖人：
```
node yourscript.js "Lakers" 

//or
node yourscript.js "Los Angeles Lakers"    

//or
node yourscript.js 13 //13为湖人队teamId     
```
### 使用示例

##### 🏀 比赛信息

**比赛 ID:** 401705297

**主队:** Los Angeles Lakers  **得分:** 120

**客队:** Golden State Warriors  **得分:** 112

##### 📊 球队统计

| 球队 | 得分 | 命中-出手数 | 投篮命中率 | 三分命中率 | 罚球命中率 | 篮板 | 助攻 | 失误 |
|------|------|------------|-------------|-----------|------------|------|------|------|
| Golden State Warriors | 112 | 41-101 | 40.6 | 30.2 | 70.0 | 40 | 29 | 12 |
| Los Angeles Lakers | 120 | 39-78 | 50.0 | 37.1 | 80.6 | 47 | 26 | 13 |

##### 🏀 球员统计 🏀

| team | name | short_name | position | jersey | MIN | FG | 3PT | FT | OREB | DREB | REB | AST | STL | BLK | TO | PF | +/- | PTS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Golden State Warriors | Draymond Green | D. Green | Power Forward | 23 | 33 | 5-7 | 2-2 | 1-3 | 0 | 5 | 5 | 4 | 2 | 1 | 0 | 5 | -1 | 13 |
| Golden State Warriors | Quinten Post | Q. Post | Center | 21 | 11 | 2-5 | 2-5 | 0-0 | 0 | 2 | 2 | 2 | 0 | 0 | 0 | 2 | -17 | 6 |
| Golden State Warriors | Stephen Curry | S. Curry | Point Guard | 30 | 37 | 13-35 | 6-20 | 5-5 | 2 | 5 | 7 | 4 | 1 | 1 | 4 | 3 | -3 | 37 |
| Golden State Warriors | …… | …… | …… | …… | …… | …… | …… |…… | …… | …… | …… | …… | …… | …… | …… | …… | …… | …… |
| Los Angeles Lakers | Dorian Finney-Smith | D. Finney-Smith | Power Forward | 17 | 33 | 3-6 | 1-4 | 0-0 | 0 | 1 | 1 | 3 | 2 | 0 | 2 | 2 | +8 | 7 |
| Los Angeles Lakers | Rui Hachimura | R. Hachimura | Power Forward | 28 | 39 | 4-9 | 1-5 | 2-4 | 0 | 4 | 4 | 3 | 0 | 0 | 0 | 3 | +12 | 11 |
| Los Angeles Lakers | LeBron James | L. James | Small Forward | 23 | 38 | 14-25 | 6-9 | 8-10 | 1 | 16 | 17 | 8 | 1 | 1 | 3 | 1 | +7 | 42 |
| Los Angeles Lakers | …… | …… | …… | …… | …… | …… | …… |…… | …… | …… | …… | …… | …… | …… | …… | …… | …… | …… |


##### 📜 recap 比赛概述 

LOS ANGELES -- — <a href="http://www.espn.com/nba/player/_/id/1966/lebron-james">LeBron James</a> had 42 points, 17 rebounds and eight assists, and the <a href="http://www.espn.com/nba/team/_/name/lal/los-angeles-lakers">Los Angeles Lakers</a> blew most of a 26-point lead before hanging on to beat the <a href="http://www.espn.com/nba/team/_/name/gs/golden-state-warriors">Golden State Warriors</a> 120-112 on Thursday night.

……

##### 🎭 Play-by-Play  完整比赛 

- **[1st Quarter - 12:00]** Quinten Post vs. Jaxson Hayes (LeBron James gains possession)
- **[1st Quarter - 11:41]** LeBron James bad pass (Stephen Curry steals)
- **[1st Quarter - 11:37]** Jaxson Hayes blocks Stephen Curry 's 4-foot two point shot
- **[1st Quarter - 11:37]** Warriors offensive team rebound
- **[1st Quarter - 11:27]** Buddy Hield bad pass (Austin Reaves steals)
- **[1st Quarter - 11:25]** Austin Reaves makes two point shot
- **[1st Quarter - 11:25]** Quinten Post shooting foul
- **[1st Quarter - 11:25]** Austin Reaves makes free throw 1 of 1
- **[1st Quarter - 11:09]** Quinten Post makes 25-foot three point jumper (Brandin Podziemski assists)
- **[1st Quarter - 10:50]** LeBron James makes 26-foot three point jumper (Jaxson Hayes assists)
- **[1st Quarter - 10:38]** Stephen Curry misses 25-foot three point jumper
- **[1st Quarter - 10:35]** Rui Hachimura defensive rebound
- **[1st Quarter - 10:30]** Austin Reaves misses 18-foot step back jumpshot
- **[1st Quarter - 10:27]** Buddy Hield defensive rebound
- **[1st Quarter - 10:18]** Stephen Curry bad pass (Dorian Finney-Smith steals)
- **[1st Quarter - 10:07]** Quinten Post personal foul

- ……

### 开发感想

设定chatgpt角色时，让chatgpt语言粗俗，枉顾事实，极端争议。在知乎上尝试，效果很好。
当然NBA在知乎热度已经不太行了，这个原因也很复杂，有机会再讲讲。

刚开始爬取ESPN时是使用Puppeteer，虽然可以用，但是确实不太方便。后来发现ESPN竟然有
公开的，免费的API可以调用,各种参数，各种比赛，非常丰富,仅从数据结构上看就能看出是花了很多精力在上面。
很震惊，很震惊，很震惊，对开发者太有好了，相比较国内的话。。。

ESPN的公开免费API是没有公开文档的，可能要购买？chatgpt 4o给我写完代码后调试不通过，提示404。
又google了好久,始终没有找到任何具体的说明。chatgpt 4o大概带我尝试了七八次，全部以失败告终。
最后用chatgpt o1重新回答，一次搞定。

人类啊，还能苟活多久?
