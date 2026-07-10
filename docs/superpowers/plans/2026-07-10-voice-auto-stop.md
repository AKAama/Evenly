# Voice Auto-stop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically stop voice recording after 1.8 seconds of post-speech silence.

**Architecture:** A pure Swift detector owns RMS/timing state. The audio tap calculates level and forwards observations to the main-actor voice session, which reuses its existing `stop()` flow.

**Tech Stack:** Swift, AVFoundation, SwiftUI, XCTest.

- [ ] Add failing detector unit tests.
- [ ] Verify RED with focused XCTest.
- [ ] Implement `VoiceSilenceDetector` and RMS calculation.
- [ ] Verify focused tests GREEN.
- [ ] Connect detector to `VoiceExpenseStreamingSession`, reset per recording, and update status before automatic stop.
- [ ] Replace `.allowBluetooth` with `.allowBluetoothHFP`.
- [ ] Run full Debug tests and `git diff --check`.
- [ ] Commit and push `main`.
