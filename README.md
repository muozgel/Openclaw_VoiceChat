# LouisVoice — private iPhone MVP

Private iPhone app for Murat to talk to Louis by voice.

## Current MVP

- Push-to-talk voice capture.
- Apple on-device/server Speech framework transcription.
- Sends final transcript to OpenClaw Gateway via WebSocket `chat.send`.
- Receives streamed `chat` events and shows Louis' reply.
- Optional iOS text-to-speech reply.
- No background/covert listening.

## Build requirement

This Mac currently has Command Line Tools but not full Xcode selected, so I scaffolded the project but cannot build it here yet.

Install/open full Xcode, then either:

```bash
brew install xcodegen
cd /Users/calyx/.openclaw/workspace/apps/LouisVoice
xcodegen generate
open LouisVoice.xcodeproj
```

Or open the folder and create an iOS SwiftUI project manually using these source files.

## App settings

In the app Settings screen:

- Gateway URL: `wss://murats-mac-mini.tail60faa0.ts.net`
- Gateway token: paste your OpenClaw Gateway token manually; do not commit it.
- Session key: `main` initially.

The iPhone must be on Tailscale and able to reach the Mac mini Gateway.

## Privacy design

Phase 1 intentionally sends only the transcript after you tap **Stop & Send**. Later phases can add visible active-listening, wake phrase, rolling transcript, and meeting summarization.
