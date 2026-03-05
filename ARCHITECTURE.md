# Echo 产品架构文档

> **一句话定义**：用最轻松的方式记录生活，然后看着 Echo 因为你的记录而成长冒险。

---

## 四大支柱

Echo 只做 4 件事。如果某个功能不属于这 4 个支柱，**不做**。

| # | 支柱          | 用户感知                         | 核心价值        |
| - | ------------- | -------------------------------- | --------------- |
| 1 | 📝 对话式日记 | 和 Echo 聊天就是写日记           | 零门槛记录      |
| 2 | 📊 复盘分析   | 心情趋势 · 日程提醒 · 习惯追踪 | 数据化自我认知  |
| 3 | 🌲 Echo 冒险  | Echo 基于日记去想象世界冒险      | 情感绑定 > 打卡 |
| 4 | 💾 记忆系统   | 用户不可见，后台运行             | 让 1-3 更智能   |

---

## 信息流

```
用户输入（文字/语音/拍照）
       │
       ▼
 ┌─ 对话式日记 ─┐
 │  和 Echo 聊天 │
 │  AI 追问细节   │
 └──────┬───────┘
        │ 点 Done
        ▼
   AI 整理为日记
        │
        ├──▶ 💾 记忆系统（自动）
        │     ├─ 事实提取
        │     ├─ 向量 embedding
        │     └─ 用户档案更新
        │
        ├──▶ 📊 复盘分析（自动）
        │     ├─ 心情打分
        │     ├─ 日程/习惯提取
        │     └─ 聚合为周报/月报
        │
        └──▶ 🌲 Echo 冒险（自动）
              └─ 日记内容 → AI 生成冒险故事
```

**关键原则：用户只需要做一件事 —— 和 Echo 聊天。其他一切自动发生。**

---

## Tab 结构

| Tab | 名称    | 视图                         | 支柱 |
| --- | ------- | ---------------------------- | ---- |
| 0   | Home    | 今日概览 · 心情 · 快捷入口 | 📊   |
| 1   | Echo    | 宠物主页 · 冒险入口         | 🌲   |
| 2   | Add     | 对话式日记编辑器             | 📝   |
| 3   | Review  | 复盘报告（替代 Explore）     | 📊   |
| 4   | History | 日记历史 · 时间线           | 📝📊 |

---

## 各支柱详细设计

### 支柱 1：📝 对话式日记

**入口**：Tab 2 (Add)

**流程**：

1. 选择模式：✨AI引导 / 📝自由写 / 🎤语音 / 📸拍照
2. AI引导模式：Echo 提问 → 用户回复 → Echo 追问 → 循环
3. 点 Done → AI 整理为日记文本 → 选心情 → 保存

**现有代码**：

- `ConversationalJournalView.swift` ✅
- `JournalSummaryService.swift` ✅
- `AIConversationService.swift` ✅
- `VoiceRecorderView.swift` ✅
- `JournalEditorView.swift` ✅（自由写模式复用）

**待完善**：

- [ ] 拍照模式：拍照后 AI 识别内容并引导对话
- [ ] 语音模式：直接在对话中录音，无需跳转 Sheet
- [ ] 对话中插入照片：类似 iMessage 发图

---

### 支柱 2：📊 复盘分析

**入口**：Tab 0 (Home) + Tab 3 (Review)

**功能**：

| 功能       | 数据来源          | 展示位置         |
| ---------- | ----------------- | ---------------- |
| 心情趋势图 | 每日日记心情标签  | Home + Review    |
| 日程提取   | AI 从日记提取待办 | Home（今日日程） |
| 习惯追踪   | AI 识别重复行为   | Review           |
| 周度复盘   | 聚合一周日记      | Review           |
| 月度复盘   | 聚合一月数据      | Review           |

**现有代码**：

- `AIScheduleHabitService.swift` ✅（日程 + 习惯提取）
- `AIInsightService.swift` ✅（AI 洞察）
- `MoodCheckInCard.swift` ✅
- `HomeView.swift` ✅（今日概览框架）

**待建设**：

- [ ] Review 页面（替代当前 ExploreView）
- [ ] 心情趋势可视化（折线图/热力图）
- [ ] 周度复盘报告生成
- [ ] 日程提醒集成

---

### 支柱 3：🌲 Echo 冒险

**入口**：Tab 1 (Echo) → 点击宠物 → 冒险

**核心机制**：

- 用户写日记 → AI 提取关键词/情绪
- AI 把关键词"翻译"为冒险元素（爬山→森林探险，聚餐→篝火晚会）
- 每天生成一段 Echo 的冒险日记
- 冒险中可以发现物品、解锁场景

**现有代码**：

- `AdventureView.swift` ✅（探险界面框架）
- `ForestSceneBackground.swift` ✅
- `PetStateManager.swift` ✅（能量/好感度系统）
- `PetHomeView.swift` ✅
- `PetView.swift` ✅

**待建设**：

- [ ] 冒险故事生成服务（日记 → 冒险叙事）
- [ ] 冒险日记展示 UI（Echo 的视角记录）
- [ ] 物品/场景收集系统
- [ ] 冒险与日记内容的关联可视化

---

### 支柱 4：💾 记忆系统（后台）

**用户不可见**，驱动其他三个支柱更智能。

**现有代码**（Phase 1 已完成）：

- `MemoryManager.swift` ✅ — 读写管线协调
- `VectorStore.swift` ✅ — NLEmbedding 向量存储
- `FactExtractor.swift` ✅ — LLM 事实提取
- `UserProfile.swift` ✅ — 用户核心档案
- `FactMemory.swift` + `JournalEmbedding` ✅ — 结构化 + 向量记忆

**应用场景**：

| 场景       | 如何使用记忆                             |
| ---------- | ---------------------------------------- |
| 对话式日记 | "上次你提到和老板有分歧，后来怎么样了？" |
| 复盘分析   | 聚合同类事实生成趋势                     |
| Echo 冒险  | 冒险故事引用真实日记细节                 |

---

## 技术约束

- **平台**：iOS 26+ (Liquid Glass), SwiftUI, SwiftData
- **AI**：ModelScope Kimi-K2.5 API
- **端侧 AI**：Apple NLEmbedding（向量化）
- **隐私**：日记数据全部本地存储，仅 AI 推理调 API
- **设计风格**：手帐/剪贴簿风（暖色调、纸质纹理、`scrapbookStyle()`）

---

## 开发优先级

```
Phase 1 ✅  记忆系统基础
Phase 2 ✅  对话式日记编辑器
Phase 3 ○   复盘分析（Review 页面 + 心情可视化）
Phase 4 ○   Echo 冒险故事生成
Phase 5 ○   多模态增强（拍照/语音内联）
```
