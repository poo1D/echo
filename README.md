# Echo PKM

A voice-first personal knowledge management app for iOS, built with SwiftUI and SwiftData. Talk to an animated penguin companion that understands your context, remembers your history, and organizes your life — diary entries, schedules, habits, and mood tracking — all from natural conversation.

## Features

**Multimodal Input**
- Voice recording with real-time transcription (Speech framework)
- Text, photos (up to 5), video, and location attachments
- Bloom radial fan input — tap [+] for a spring-animated radial menu

**Multi-Agent AI Pipeline**
- 4-phase orchestration: RAG retrieval → parallel analysis (Emotion, Memory, Action agents) → action execution → streaming synthesis
- On-device semantic search via `NLEmbedding` + `vDSP` cosine similarity — no API call needed for context retrieval
- Rich response cards: mood trends, memory recall, schedule confirmations, habit streaks, pattern insights

**Unified Hub**
- Animated penguin companion (procedurally drawn, no image assets) that reacts to conversations and mood
- Floating proactive bubbles: schedule reminders, habit streaks, mood check-ins — tap to complete inline
- Diary timeline with day-grouped entries, tag filtering, and week navigation

**Auto-Save Diary**
- Conversations automatically saved as diary entries after 2 minutes of inactivity or on app background
- Each entry captures: summary, mood, topics, photos, videos, audio, location, full transcript, and AI insight

**Weekly Review**
- Mood bar chart (7-day), topic cloud, key moments, upcoming schedules, habit tracking
- LLM-generated weekly observation from your penguin companion

## Architecture

```
User Input → MultimodalInputBar (voice / text / photo / video / location)
                    ↓
              ConversationView.feedItems: [FeedItem]
                    ↓
              MultiAgentPipeline.process()
              ├→ RAGService.search()                    ← on-device semantic search
              ├→ EmotionAgent, MemoryAgent, ActionAgent  ← parallel, staggered
              ├→ executeActions()                        ← writes to SwiftData
              └→ SynthesisAgent                          ← streams response + rich cards
                    ↓
              AutoSaveService.saveFeedSession()
              ├→ DiaryEntry (SwiftData)
              ├→ RAGService.indexEntry()
              └→ InsightService + ScheduleHabitService
```

**Pure Apple stack** — zero external dependencies:

| Framework | Usage |
|-----------|-------|
| SwiftUI + SwiftData | UI and persistence |
| Charts | Mood visualization |
| Speech | Voice transcription + M4A recording |
| NaturalLanguage | On-device word embeddings (512-dim) |
| Accelerate (vDSP) | SIMD cosine similarity |
| AVFoundation | Video compression & frame extraction |
| CoreLocation | GPS + reverse geocoding |
| PhotosUI | Photo & video picker |

## Getting Started

**Requirements:** Xcode 16+, iOS 18+

1. Clone the repository:
   ```bash
   git clone https://github.com/poo1D/echo.git
   ```

2. Create `Config.xcconfig` in the project root with your API key:
   ```
   MODELSCOPE_API_KEY = your-api-key-here
   ```
   Get a free key from [ModelScope](https://www.modelscope.cn/).

3. Open `EchoPKM.xcodeproj` in Xcode and run on a simulator or device.

**Build from command line:**
```bash
xcodebuild -project EchoPKM.xcodeproj -scheme EchoPKM -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

> The app works without an API key — LLM features will use mock fallback responses, and on-device features (RAG search, proactive cards, diary, review) function normally.

## Project Structure

```
EchoPKM/
├── Models/          DiaryEntry, FeedItem, RichContent, ScheduleItem, HabitEntry, WeeklyReview
├── Services/        ChatService, MultiAgentPipeline, RAGService, AutoSaveService,
│                    ProactiveGreetingService, SpeechService, LocationService,
│                    PhotoPickerService, VideoPickerService, InsightService, ...
├── Views/
│   ├── Unified/     UnifiedView, ConversationView, EchoHubSection,
│   │                DiaryTimelineSection, MultimodalInputBar, TagFilterSheet
│   ├── Diary/       JournalDetailSheet, EditEntrySheet, PhotoGridView,
│   │                AudioWaveformPlayer, VideoPlayerSheet
│   ├── Review/      ReviewView (mood chart, topic cloud, habits, schedules)
│   ├── Pet/         PetView (procedural penguin with mood states & animations)
│   ├── Profile/     ProfileView (settings)
│   └── Shared/      DiaryCardView, WeekDateRowView
└── Helpers/         ColorExtension (Anthropic-inspired palette)
```

## License

[MIT](LICENSE) — Copyright (c) 2026 Dengye Li & AugustineQiu
