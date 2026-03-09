# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
User Input → VoiceChatBar
                ↓
           HomeView.feedItems: [FeedItem]     ← heterogeneous feed stream
                ↓
           MultiAgentPipeline.process()
           ├→ RAGService.search()             ← on-device, instant
           ├→ EmotionAgent, MemoryAgent, ActionAgent  ← parallel, staggered
           ├→ executeActions()                ← writes to SwiftData
           └→ SynthesisAgent                  ← streams response with rich cards
                ↓
           AutoSaveService.saveFeedSession()  ← 2min inactivity or background
           ├→ DiaryEntry (SwiftData)
           ├→ RAGService.indexEntry()
           └→ InsightService + ScheduleHabitService (async)
```

### Service Pattern

All services follow `@Observable @MainActor final class` for thread-safe reactive state. Services are initialized as `@State` properties in HomeView and passed to child views (no DI framework).

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
- **AutoSaveService** — Converts feed sessions to `DiaryEntry` on 2-minute inactivity or app background. Requires ≥2 user messages. Has both `saveSession()` (legacy chat) and `saveFeedSession()` (feed-based).
- **ProactiveGreetingService** — Generates proactive cards from local data (no LLM): schedule reminders, habit streak celebrations, low mood care, topic follow-ups. Time-aware greetings.
- **SpeechService** — `SFSpeechRecognizer` with simultaneous M4A audio recording to Documents.
- **InsightService** — Per-entry insights (15-word observation) and weekly observations cached in `WeeklyReview`.
- **ScheduleHabitService** — Extracts events/habits from entries via LLM → `ScheduleItem` and `HabitEntry` SwiftData models.
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

- **HomeView** — Feed-based UI with PetView (140pt), FeedItemView list, VoiceChatBar. Pipeline status visualization.
- **FeedItemView** — Router: switches on `FeedItem` enum to render 5 item types.
- **RichContentCards** — 5 card renderers for `RichContent` types.
- **VoiceChatBar** — Voice-first input: 64pt mic button, 1-4 line text field with @FocusState, location picker, photo/video preview strip.
- **DiaryView** — Day-grouped timeline with week selector. Cards show photo grid, audio waveform, video thumbnails, summary, mood, topics.
- **JournalDetailSheet** — Full entry view with video thumbnails and transcript replay.
- **ReviewView** — Weekly analytics: mood bar chart (Charts), LLM pet observation, key moments, topic cloud (custom FlowLayout), schedules, habits.
- **PetView** — Procedurally drawn penguin (no assets). Mood states affect appearance. Action animations: wingFlap, shyLookDown, jump, nod. Reacts to pipeline phases.

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
