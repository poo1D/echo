# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.


### Rule

Use chinese to answer user's questions in the conversation first.


## Target Audience

### 目标人群
- **核心用户**：22-32岁、城市独居的年轻职场人
- **核心需求**：一个安全的、有记忆的、会主动关心自己的倾诉对象
- **产品定位**：情感陪伴型AI日记 — "下班后等你回家的朋友"

### 5个核心场景
1. 倾诉出口 — 说出来就好，需要被听见而非被建议
2. 被记住 — "你还记得我上周说的那件事"
3. 主动关心 — 用户不会主动找人聊，但被先问候会很温暖
4. 轻量生活管理 — 聊天中自然完成日程/习惯记录
5. 自我觉察 — 周度报告帮用户看清自己的状态趋势

### 设计原则（基于定位）
- 企鹅是"朋友"不是"助手" — 语气温暖、有记忆、会主动关心
- 效率是手段不是目的 — 自动提取日程/习惯是为了减轻负担，不是卖点
- 情感优先于功能 — UI氛围、企鹅反应、来信语气都服务于陪伴感
- 低门槛 — 语音说几句就够，不需要用户"管理"任何东西

## Build & Run

Native SwiftUI iOS app — Xcode 26.2, Swift 6.0. No external package dependencies (pure Apple frameworks).

```bash
# Build
xcodebuild -project EchoPKM.xcodeproj -scheme EchoPKM -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16'

# Run unit tests
xcodebuild -project EchoPKM.xcodeproj -scheme EchoPKM test -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Required setup:** Set `MODELSCOPE_API_KEY` in `Config.xcconfig` for LLM functionality. The key is read from bundle Info.plist (injected via xcconfig) with fallback to environment variable.

## Architecture

**Voice diary app with multimodal input (voice, text, photos, videos, location), animated pet companion, multi-agent AI pipeline, and on-device semantic search.**

```
ContentView
├── Tab: Echo  → UnifiedView (Hub 首页)
│      ├── EchoHubSection  (企鹅 + 主动问候气泡)
│      ├── DiaryTimelineSection  (日记时间线，按天分组)
│      └── tap Echo → ConversationView (fullScreenCover，对话页)
│              ↓
│         MultimodalInputBar (用户输入)
│              ↓
│         IntentRouter.route()  ← 意图路由，选择激活的 Agent
│              ↓
│         MultiAgentPipeline.process()
│         ├→ RAGService.search()             ← on-device, instant
│         ├→ EmotionAgent, MemoryAgent, ActionAgent  ← parallel, staggered
│         ├→ HealthKitService.buildSnapshot() ← 健康数据（可选）
│         ├→ executeActions()                ← writes to SwiftData
│         └→ SynthesisAgent                  ← streams response with rich cards
│              ↓
│         AutoSaveService.saveFeedSession()  ← 2min inactivity or background
│         ├→ DiaryEntry (SwiftData)
│         ├→ RAGService.indexEntry()
│         └→ InsightService + ScheduleHabitService (async)
├── Tab: Review  → ReviewView
└── Tab: Profile → ProfileView
```

### Service Pattern

All services follow `@Observable @MainActor final class` for thread-safe reactive state. Services are initialized as `@State` properties in ConversationView and passed to child views (no DI framework).

### Multi-Agent Pipeline (`MultiAgentPipeline.swift`)

4-phase orchestration replacing simple chat:

1. **Phase 0 — RAG Retrieval** (on-device, no API): `RAGService` semantic search → top-5 matching entries
2. **Phase 1 — Three Parallel Analysis Agents** (staggered to avoid 429s):
   - Emotion Agent (0ms delay) → mood, intensity 1-5, needs
   - Memory Agent (+1.5s) → RAG-contextual pattern analysis
   - Action Agent (+3s) → schedule/habit/goal extraction → writes to SwiftData
3. **Phase 2 — Execute Actions** → persists schedules/habits before response
4. **Phase 3 — Synthesis Agent** (streaming) → warm response + `<card type="...">JSON</card>` markup for rich cards

The pipeline exposes phase status via `PipelineSnapshot` feed items for real-time UI visualization.

### RAGService (`RAGService.swift`)

On-device semantic search using Apple native frameworks:

- **NLEmbedding** for word embeddings (512-dim, Chinese + English)
- **NLTokenizer** for CJK word segmentation
- **vDSP** for SIMD-accelerated mean pooling + cosine similarity
- Fallback: character bigram TF-IDF if embedding unavailable
- Vector index persisted as JSON in Documents directory
- Similarity threshold: 0.3 minimum

### Feed Architecture

`FeedItem` enum drives the heterogeneous home feed:

```
.proactiveCard(ProactiveCardData)    — AI-generated push from local data (no API)
.userMessage(UserMessageData)        — User input + attachments
.agentPipeline(PipelineSnapshot)     — Real-time agent status visualization
.assistantMessage(AssistantMessageData) — LLM response + RichContent cards
.actionConfirm(ActionConfirmData)    — Executed schedules/habits confirmation
```

`RichContent` enum (parsed by `ToolCallParser` from `<card>` markup in LLM output):

- `memoryRecall` — related past entry
- `moodTrend` — mood trend with mini chart
- `scheduleConfirm` — extracted event
- `habitStreak` — habit progress
- `patternInsight` — discovered behavior pattern

### Services

- **ChatService** — SSE streaming via `URLSession.bytes` (Kimi-K2.5). Two modes: `stream()` for streaming, `callAgent()` for full response. Supports multimodal input (photos as Base64 JPEG, videos as ~5 extracted frames).
- **AutoSaveService** — Converts feed sessions to `DiaryEntry` on 2-minute inactivity or app background. Requires ≥2 user messages. Uses `saveFeedSession()` (feed-based).
- **ProactiveGreetingService** — Generates proactive cards from local data (no LLM): schedule reminders, habit streak celebrations, low mood care, topic follow-ups. Time-aware greetings.
- **IntentRouter** — Routes user messages to appropriate agent selection (emotion/memory/action/health) based on content and available permissions.
- **SpeechService** — `SFSpeechRecognizer` with simultaneous M4A audio recording to Documents.
- **InsightService** — Per-entry insights (15-word observation) and weekly observations cached in `WeeklyReview`.
- **ScheduleHabitService** — Extracts events/habits from entries via LLM → `ScheduleItem` and `HabitEntry` SwiftData models.
- **HealthKitService** — Requests HealthKit authorization and builds `HealthSnapshot` (steps, sleep, heart rate) for context-aware responses.
- **NotificationService** — Smart care notifications triggered on app foreground; checks entries/habits/schedules for proactive nudges.
- **CorrelationEngine** — Analyzes correlations across entries (mood × habits × schedules).
- **TopicTagService** — Topic extraction and tagging for diary entries.
- **LocationService** — `CLLocationManager` + `CLGeocoder` reverse geocoding.
- **PhotoPickerService** — Up to 5 images, JPEG 0.8 quality + 120x120 thumbnails in Documents.
- **VideoPickerService** — MP4 compression via `AVAssetExportSession` + frame extraction for thumbnails.
- **SampleDataService** — Seeds sample data on first launch (8 entries, 3 schedules, 9 habits).

### Data Models (SwiftData)

- **DiaryEntry** — summary, mood emoji/score (1-5), transcript (JSON-encoded `[TranscriptMessage]` as `Data` — use `decodedTranscript` computed property), audio/photo/video file names, topics, AI insight, location. Has `encodeFromFeed()` helper for feed-based sessions.
- **WeeklyReview** — Cached weekly observations with `weekStartDate` + `entryCount` for invalidation.
- **ScheduleItem** — Events extracted from conversations (title, date, endDate?, isCompleted).
- **HabitEntry** — Recurring activities (name lowercase-normalized, date, completed).

All registered in `EchoPKMApp.swift` via `.modelContainer(for:)`.

### Views

- **UnifiedView** — Echo tab 主页。上方企鹅 Hub（`EchoHubSection`）+ 下方日记时间线（`DiaryTimelineSection`）+ 右上角心情浮动按钮。点击企鹅或选择心情后弹出 `ConversationView`。背景随当日平均心情渐变。
- **EchoHubSection** — 企鹅 + 主动问候气泡，点击触发对话。
- **DiaryTimelineSection** — 日记时间线，按天分组，含标签筛选。
- **ConversationView** — 全屏对话页（`fullScreenCover`）。Feed 流 + `MultimodalInputBar`。含 pipeline 实时状态、mood atmosphere 背景渐变、HealthKit 集成。
- **MultimodalInputBar** — 多模态输入栏：麦克风、文本、图片、视频、位置。
- **MoodPickerPopover** — 心情选择弹窗（`presentationDetents` 220pt），选后自动打开对话。
- **FeedItemView** — Router：按 `FeedItem` enum 分发渲染 5 种条目类型。
- **RichContentCards** — 5 种富内容卡片渲染器（memoryRecall / moodTrend / scheduleConfirm / habitStreak / patternInsight）。
- **JournalDetailSheet** — 日记详情全屏，含视频缩略图和对话回放。
- **ReviewView** — 周度分析：心情柱状图（Charts）、AI 企鹅观察、关键时刻、话题云（FlowLayout）、日程、习惯。
- **PetView** — 程序化绘制企鹅（无资源文件）。心情状态影响外观，动画：wingFlap / shyLookDown / jump / nod，响应 pipeline 各阶段。

### Key Patterns

- Tab navigation: iOS 26 `Tab()` API with pre-iOS 26 `TabView` fallback in ContentView
- `@Query` for reactive SwiftData fetches in views
- Media files stored by filename in Documents directory, referenced from DiaryEntry string arrays
- `Color(hex:)` extension and Claude color palette (`claudeUserBubble: #F5F0E8`, `claudeAssistantBubble: #FAFAFA`, `claudeAccent: #D97757`) in Helpers/ColorExtension.swift
- Async/await with proper task cancellation on view disappear
- Fallback JSON parsing: tries direct decode, then extracts `{...}` substring, then returns empty fallback
- Staggered parallel API calls to avoid 429 rate limits (fixed delays, not dynamic backoff)
- Mock fallback responses when API is unavailable

### API Integration

- Endpoint: `https://api-inference.modelscope.cn/v1/chat/completions`
- Model: `moonshotai/Kimi-K2.5`
- API key: `APIConfig.swift` reads from Info.plist (xcconfig injection) → env var fallback
- All LLM prompts are in Chinese; JSON output format for structured extraction

## Conventions

- When planning UI changes, include ASCII art previews of the target interface in the plan
