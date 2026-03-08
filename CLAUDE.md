# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a native SwiftUI iOS app built with Xcode (26.2, Swift 6.0). No external package dependencies.

```bash
# Build
xcodebuild -project EchoPKM.xcodeproj -scheme EchoPKM -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16'

# Run unit tests
xcodebuild -project EchoPKM.xcodeproj -scheme EchoPKM test -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Required setup:** Set `MODELSCOPE_API_KEY` in `Config.xcconfig` for LLM functionality.

## Architecture

**Layered SwiftUI voice diary app with multimodal input (voice, text, photos, location), an animated pet companion, and AI-powered insights.**

```
Views (SwiftUI)  →  Services (@Observable @MainActor)  →  SwiftData (DiaryEntry, WeeklyReview, ScheduleItem, HabitEntry)
```

### Services

All services follow the `@Observable @MainActor final class` pattern for thread-safe reactive state:

- **ChatService** — SSE streaming chat with ModelScope API (Kimi-K2.5). Three-layer context building: (1) recent 7 entries, (2) long-term patterns from 23 older entries, (3) topic-matched relevant entries. Session summarization extracts mood, topics, summary as JSON. System prompt includes schedule/habit awareness.
- **SpeechService** — Live speech-to-text via `SFSpeechRecognizer` with simultaneous M4A audio recording to Documents directory.
- **AutoSaveService** — Converts chat sessions to `DiaryEntry` on 2-minute inactivity or app background. Requires ≥2 user messages. Triggers async insight generation and schedule/habit extraction after save.
- **InsightService** — Generates per-entry insights (15-word warm observation) and weekly observations. Weekly observations are cached in `WeeklyReview` model, invalidated when entry count changes.
- **ScheduleHabitService** — Extracts scheduled events and recurring habits from diary entries via LLM. Parses JSON response into `ScheduleItem` and `HabitEntry` SwiftData models.
- **LocationService** — `CLLocationManager` with reverse geocoding via `CLGeocoder`. Returns `PendingLocation` struct (name + coordinates).
- **PhotoPickerService** — PhotosUI integration (up to 5 images). Stores JPEG (0.8 quality) + thumbnails (120x120) in Documents directory.
- **SampleDataService** — Seeds 8 sample diary entries, 3 sample schedules, and 9 sample habit records on first launch (checks entry count).

### Data Models

- **DiaryEntry** (SwiftData `@Model`) — Stores: summary, mood emoji, mood score (1-5), transcript (JSON-encoded `[TranscriptMessage]` as `Data`), audio file names, photo file names, topics, AI insight, location name, latitude/longitude. Use `decodedTranscript` computed property to read transcript.
- **WeeklyReview** (SwiftData `@Model`) — Caches weekly LLM observations with `weekStartDate` and `entryCount` for invalidation.
- **ScheduleItem** (SwiftData `@Model`) — Stores: title, date, endDate?, notes?, isCompleted, sourceEntryID?, createdAt. Used for upcoming events extracted from conversations.
- **HabitEntry** (SwiftData `@Model`) — Stores: name (lowercase normalized), date, completed, sourceEntryID?, createdAt. Used for tracking recurring activities.

All models registered in SwiftData container in `EchoPKMApp.swift`.

### Views

- **HomeView** — Main chat interface with PetView (140pt), message list with Claude-styled bubbles (warm beige user, near-white AI with sparkle avatar), VoiceChatBar. Auto-saves on 2-minute inactivity timer or scene phase change to background. Keyboard dismisses interactively on scroll.
- **VoiceChatBar** — Voice-first input: large mic button (64pt), text field (1-4 line expansion) with @FocusState for keyboard dismissal, location picker sheet, photo preview strip, send button. Auto-sends on mic stop if text present.
- **LocationPickerSheet** — MapKit map with pin at current location, reverse geocoded place name, Add Location / Cancel buttons. Presented as `.sheet` with `.medium` and `.large` detents.
- **DiaryView** — Timeline grouped by day with week date selector. DiaryCard shows photo grid (1-4 layout with "+N" overflow), audio waveform player, summary, mood, location, topic tags (max 4), AI insight. TranscriptSheet modal for full conversation replay with Claude-styled bubbles.
- **AudioWaveformPlayer** — Loads M4A from Documents, downsamples to 50 bars, renders waveform via Canvas with played/remaining coloring.
- **ReviewView** — Weekly analytics: mood bar chart (Charts framework, 5-color gradient), LLM pet observation (async with cache), key moments (top 5 by mood), topic frequency cloud (custom FlowLayout, up to 10 tags), upcoming schedules (next 5 events with completion toggle), habits this week (grouped by name with emoji + count).
- **PetView** — Procedurally drawn penguin (no image assets). Mood states (happy/neutral/tired/worried) affect cheek opacity. Action animations: wingFlap, shyLookDown, jump, nod. Idle loop: breathing, bouncing, blinking.

### Key Patterns

- Tab navigation with iOS 26 `Tab()` API and pre-iOS 26 `TabView` fallback in ContentView
- `@Query` for reactive SwiftData fetches in views
- SSE streaming via `URLSession.bytes` with line-by-line JSON delta parsing in ChatService
- Audio and photo files stored by filename in Documents directory, referenced from DiaryEntry arrays
- `Color(hex:)` extension and Claude color palette (`claudeUserBubble`, `claudeAssistantBubble`, `claudeAccent`) in Helpers/ColorExtension.swift
- Async/await throughout with proper task cancellation on view disappear

### API Integration

- Endpoint: `https://api-inference.modelscope.cn/v1/chat/completions`
- Model: `moonshotai/Kimi-K2.5`
- API key read from bundle Info.plist (injected from Config.xcconfig) with fallback to `MODELSCOPE_API_KEY` environment variable
- Streaming (ChatService) and non-streaming (InsightService, ScheduleHabitService) modes
- Mock fallback responses when API is unavailable

## Conventions

- When planning UI changes, include ASCII art previews of the target interface in the plan
