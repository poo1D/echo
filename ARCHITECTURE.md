# EchoPKM 架构设计文档

## 1. 项目概述

EchoPKM 是一款基于语音优先的个人知识管理iOS应用。用户通过自然对话与AI企鹅互动，系统自动提取并结构化存储日程、习惯、情绪等数据，同时将对话内容持久化为可检索的日记条目。

### 1.1 核心价值

| 能力       | 用户价值                   |
| ---------- | -------------------------- |
| 语音优先   | 降低输入门槛，自然记录     |
| AI自动提取 | 日程、习惯自动识别并持久化 |
| 端侧检索   | 零延迟上下文理解，隐私友好 |
| 周度洞察   | 数据驱动的自我认知         |

### 1.2 技术约束

- **零外部依赖**：纯Apple原生框架
- **iOS 18+**：利用最新SwiftData和SwiftUI特性
- **Swift 6**：采用并发安全语言特性

---

## 2. 系统架构

### 2.1 架构全景

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Presentation Layer                          │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐       │
│  │ UnifiedView │ │ DiaryView  │ │ ReviewView │ │ ProfileView│       │
││  (对话+日记)  │  (时间线)   │  (周度分析)  │  (设置)     │       │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘       │
├─────────────────────────────────────────────────────────────────────┤
│                          Business Layer                             │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐           │
│  │MultiAgentPipe  │ │  RAGService    │ │AutoSaveService │           │
│  │  (4阶段编排)    │ │  (端侧语义检索) │ │  (自动持久化)   │           │
│  └────────────────┘ └────────────────┘ └────────────────┘           │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐           │
│  │  ChatService   │ │InsightService  │ │ScheduleHabit   │           │
│  │  (LLM流式调用)  │ │  (智能洞察)     │ │  (习惯日程)    │           │
│  └────────────────┘ └────────────────┘ └────────────────┘           │
├─────────────────────────────────────────────────────────────────────┤
│                           Data Layer                                │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐        │
│  │ DiaryEntry │ │ScheduleItem│ │ HabitEntry │ │WeeklyReview│        │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘        │
│                    SwiftData (持久化)                                │
├─────────────────────────────────────────────────────────────────────┤
│                        Foundation Services                          │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐             │
│  │Speech│ │Photo │ │Video │ │Locat │ │Health│ │Proac │             │
│  │      │ │Picker│ │Picker│ │ion   │ │Kit   │ │tive  │             │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘             │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 分层职责

| 层级         | 职责                       | 技术选型      |
| ------------ | -------------------------- | ------------- |
| Presentation | UI渲染、用户交互、状态展示 | SwiftUI       |
| Business     | 业务逻辑、AI编排、数据处理 | Swift并发     |
| Data         | 数据持久化、查询、索引     | SwiftData     |
| Foundation   | 系统能力封装               | Apple原生框架 |

---

## 3. 核心模块设计

### 3.1 Feed流架构

**设计目标**：统一异构数据流，支持实时状态更新

```swift
enum FeedItem {
    case proactiveCard(ProactiveCardData)      // 系统主动推送
    case userMessage(UserMessageData)          // 用户输入
    case agentPipeline(PipelineSnapshot)       // AI处理状态
    case assistantMessage(AssistantMessageData)// AI响应
    case actionConfirm(ActionConfirmData)      // 动作确认
}
```

**设计考量**：

- **类型安全**：枚举关联值确保每种消息类型的数据完整性
- **可扩展性**：新增消息类型无需修改现有代码
- **流式友好**：支持AI处理过程的实时可视化

### 3.2 多智能体管道

**4阶段编排**：

```
阶段0: RAG检索 (端侧, ~50ms)
    │
    │ NLEmbedding向量化 + vDSP余弦相似度
    │
    ▼
阶段1: 并行分析 (错峰API调用, ~5-8s)
    │
    ├─ 0.0s → EmotionAgent (情绪分析)
    ├─ 1.5s → MemoryAgent (模式洞察)
    └─ 3.0s → ActionAgent (日程/习惯提取)
    │
    ▼
阶段2: 动作执行 (<100ms)
    │
    │ 解析JSON → 写入SwiftData → 生成确认卡片
    │
    ▼
阶段3: 合成响应 (流式, ~2-5s)
    │
    │ SSE流式输出 + <card>富内容解析
    │
    ▼
用户可见响应
```

**错峰策略**：固定延迟避免429错误（非动态退避，简化实现）

### 3.3 端侧RAG实现

**技术选型**：

| 组件        | Apple框架       | 用途               |
| ----------- | --------------- | ------------------ |
| NLEmbedding | NaturalLanguage | 512维中英文词向量  |
| NLTokenizer | NaturalLanguage | CJK分词            |
| vDSP        | Accelerate      | SIMD加速相似度计算 |

**检索流程**：

```
用户查询 → 分词 → 词向量 → 平均池化 → 归一化
                                              │
                        向量索引 (JSON持久化)  │
                                              │
                 余弦相似度 (Top-5, threshold≥0.3)
                                              │
                                    相关上下文返回
```

**降级策略**：NLEmbedding不可用时，使用字符二元组TF-IDF

### 3.4 数据模型

#### DiaryEntry（核心模型）

```swift
@Model final class DiaryEntry {
    var id: UUID
    var date: Date
    var summary: String           // AI摘要
    var moodEmoji: String
    var moodScore: Int (1-5)
    var topics: [String]
    var transcript: Data          // [TranscriptMessage]的JSON编码
    var audioFileName: String?
    var photoFileNames: [String]
    var videoFileNames: [String]
    var location: String?
    var insight: String?
}
```

**设计考量**：

- 媒体文件：Documents目录存储，文件名引用（避免大数据进DB）
- 对话记录：JSON编码压缩存储
- 自动索引：保存后触发RAG向量化

---

## 4. 关键技术实现

### 4.1 服务模式约定

```swift
@Observable @MainActor
final class SomeService {
    // 状态：自动驱动UI更新
    @Published var state: State

    // 初始化：接收ModelContext
    init(modelContext: ModelContext) {}

    // 方法：异步业务逻辑
    func doSomething() async {}
}
```

**设计优势**：

- `@Observable`：Swift 6原生响应式，无需Combine
- `@MainActor`：确保UI操作线程安全
- `async/await`：结构化并发，自动取消传播

### 4.2 多模态输入处理

| 模态 | 技术方案                           | 存储策略                      |
| ---- | ---------------------------------- | ----------------------------- |
| 语音 | SFSpeechRecognizer + 并行M4A录制   | Documents/{uuid}.m4a          |
| 照片 | PHPicker + JPEG 0.8质量压缩        | Documents/{uuid}.jpg + 缩略图 |
| 视频 | AVAssetExportSession压缩 + 5帧提取 | Documents/{uuid}.mp4 + 缩略图 |
| 位置 | CoreLocation + CLGeocoder          | 字符串存储                    |

### 4.3 LLM集成

**流式处理**：

```swift
URLSession.bytes(from: request).forEach { chunk in
    if let text = parseSSE(chunk) {
        await MainActor.run {
            responseText += text
        }
    }
}
```

**富内容解析**：

```
LLM输出: "...<card type="moodTrend">{"trend":"上升"}</card>..."
                                          │
                                    ToolCallParser
                                          │
                          ┌───────────────┴───────────────┐
                          ▼                               ▼
                  自然语言响应                      RichContent.moodTrend
```

---

## 5. 数据流

### 5.1 用户输入到持久化

```
MultimodalInputBar
        │
        ▼
  FeedItem.userMessage
        │
        ▼
MultiAgentPipeline.process()
        │
        ├─▶ RAGService.search() (端侧)
        ├─▶ EmotionAgent (API)
        ├─▶ MemoryAgent (API)
        ├─▶ ActionAgent (API)
        │       │
        │       ▼
        │  executeActions() → SwiftData写入
        │
        ▼
  SynthesisAgent (流式)
        │
        ▼
FeedItem.assistantMessage
        │
        ▼
  [条件: 2分钟无活动 OR 后台]
        │
        ▼
AutoSaveService.saveFeedSession()
        │
        ├─▶ DiaryEntry创建
        ├─▶ SwiftData保存
        └─▶ RAGService.indexEntry()
```

### 5.2 状态管理

```
┌─────────────────────────────────────────────────────────┐
│                    HomeView (Root)                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │ @State     │  │ @State     │  │ @State     │        │
│  │ feedItems  │  │ pipeline   │  │ services   │        │
│  └────────────┘  └────────────┘  └────────────┘        │
└─────────────────────────────────────────────────────────┘
                           │
               传递给子视图 (.binding)
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
  ConversationView                    DiaryTimelineSection
```

---

## 6. 非功能性考虑

### 6.1 性能

| 场景     | 优化措施                    |
| -------- | --------------------------- |
| RAG检索  | vDSP SIMD加速，索引持久化   |
| 照片加载 | 120x120缩略图，按需加载原图 |
| 流式响应 | 增量更新，避免全量重绘      |
| 列表滚动 | LazyVStack + 差分更新       |

### 6.2 隐私

| 数据     | 处理方式                         |
| -------- | -------------------------------- |
| 语音音频 | 本地存储，不上传服务器           |
| 媒体文件 | 本地Documents目录                |
| 向量索引 | 本地JSON，端侧检索               |
| LLM交互  | 仅文本内容上传（照片Base64可选） |

### 6.3 可用性

| 场景              | 降级策略               |
| ----------------- | ---------------------- |
| API不可用         | Mock响应，端侧功能正常 |
| 无网络            | 端侧RAG + 本地功能可用 |
| NLEmbedding不可用 | TF-IDF降级             |

### 6.4 可扩展性

```
新增消息类型:
    FeedItem新增case → FeedItemView新增分支

新增Agent:
    MultiAgentPipeline新增阶段 → 更新错峰时序

新增富内容卡片:
    RichContent新增case → RichContentCards新增渲染器
```

---

## 7. 技术风险与缓解

| 风险            | 影响       | 缓解措施                |
| --------------- | ---------- | ----------------------- |
| 429限流         | AI响应失败 | 固定错峰延迟 + Mock降级 |
| SwiftData迁移   | 数据丢失   | ModelContainer版本管理  |
| 大媒体文件      | 存储压力   | 压缩 + 缩略图策略       |
| NLEmbedding失效 | 检索降级   | TF-IDF备用方案          |

---

## 8. 待优化项

1. **动态退避**：API调用429时采用指数退避而非固定延迟
2. **向量索引**：考虑使用更高效的索引结构（如HNSW）
3. **缓存策略**：LLM响应缓存，减少重复调用
4. **测试覆盖**：单元测试覆盖率提升（当前<30%）

---

## 附录：文件结构

```
EchoPKM/
├── Models/              # 数据模型 (6个SwiftData模型)
├── Services/            # 业务服务 (16个服务类)
│   ├── MultiAgentPipeline.swift
│   ├── RAGService.swift
│   ├── ChatService.swift
│   └── ...
├── Views/
│   ├── Unified/         # 主界面 (6个视图)
│   ├── Diary/           # 日记模块 (7个视图)
│   ├── Review/          # 回顾模块 (2个视图)
│   ├── Pet/             # 企鹅角色 (1个视图)
│   ├── Profile/         # 个人中心 (1个视图)
│   └── Shared/          # 共享组件 (2个视图)
└── Helpers/             # 工具扩展 (4个文件)
```

---

*本文档面向技术评审，聚焦架构设计决策和技术实现路径。*
