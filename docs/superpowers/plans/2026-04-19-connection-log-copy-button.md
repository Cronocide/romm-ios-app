# Connection Log Copy Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Kopieren" button at the bottom of the expanded `ConnectionDebugPanel` that copies all connection log entries plus the app version to the clipboard.

**Architecture:** Extract the log-formatting logic as a static helper on `ConnectionDebugPanel` so it can be unit-tested independently. The button sets a transient `copied` state that resets after 2 seconds to show inline feedback.

**Tech Stack:** SwiftUI, `UIPasteboard`, Swift Testing (`@testable import romm`)

---

### Task 1: Failing test for log formatting

**Files:**
- Modify: `romm/rommTests/HeartbeatRepositoryTests.swift` — add new test struct for log formatting

- [ ] **Step 1: Write the failing test**

Add the following struct to `romm/rommTests/HeartbeatRepositoryTests.swift` after the existing `HeartbeatRepositoryTests` struct:

```swift
struct ConnectionLogFormatterTests {

    @Test func formattedLogContainsAppVersionHeader() {
        let entries: [ConnectionLogEntry] = [
            ConnectionLogEntry(message: "Checking URL", type: .info),
            ConnectionLogEntry(message: "Connection refused", type: .error, details: "ECONNREFUSED"),
        ]
        let result = ConnectionDebugPanel.formatLogsForClipboard(entries, appVersion: "1.2.3")
        #expect(result.hasPrefix("RomM iOS v1.2.3\n\n"))
    }

    @Test func formattedLogContainsEachEntryMessage() {
        let entries: [ConnectionLogEntry] = [
            ConnectionLogEntry(message: "Checking URL", type: .info),
            ConnectionLogEntry(message: "Connection refused", type: .error, details: "ECONNREFUSED"),
        ]
        let result = ConnectionDebugPanel.formatLogsForClipboard(entries, appVersion: "1.0.0")
        #expect(result.contains("Checking URL"))
        #expect(result.contains("Connection refused"))
        #expect(result.contains("ECONNREFUSED"))
    }

    @Test func formattedLogIncludesTimestamp() {
        let entries: [ConnectionLogEntry] = [
            ConnectionLogEntry(message: "Test", type: .info),
        ]
        let result = ConnectionDebugPanel.formatLogsForClipboard(entries, appVersion: "1.0.0")
        // Timestamp format HH:mm:ss — matches digits:digits:digits
        let hasTimestamp = result.range(of: #"\d{2}:\d{2}:\d{2}"#, options: .regularExpression) != nil
        #expect(hasTimestamp)
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -scheme romm \
  -destination 'platform=iOS Simulator,arch=arm64,id=6AEDBF66-BBFD-4292-9C50-6E14F511FD0C' \
  -only-testing:rommTests/ConnectionLogFormatterTests 2>&1 \
  | grep -E "error:|FAIL|PASS|ConnectionLogFormatter"
```

Expected: compile error — `type 'ConnectionDebugPanel' has no member 'formatLogsForClipboard'`

---

### Task 2: Implement `formatLogsForClipboard` + copy button

**Files:**
- Modify: `romm/romm/UI/App/SetupView.swift` lines 769-822 (`ConnectionDebugPanel`)

- [ ] **Step 1: Add `formatLogsForClipboard` static method and copy state to `ConnectionDebugPanel`**

Replace the struct definition (lines 769-822) with:

```swift
struct ConnectionDebugPanel: View {
    let logs: [ConnectionLogEntry]
    @Binding var isExpanded: Bool
    @State private var copied = false

    static func formatLogsForClipboard(_ logs: [ConnectionLogEntry], appVersion: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let header = "RomM iOS v\(appVersion)\n\n"
        let body = logs.map { entry in
            var line = "\(formatter.string(from: entry.timestamp)) [\(entry.type.label)] \(entry.message)"
            if let details = entry.details {
                line += "\n  \(details)"
            }
            return line
        }.joined(separator: "\n")
        return header + body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "ant.fill")
                        .foregroundColor(.secondary)
                    Text("Connection Details")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(logs) { log in
                                ConnectionLogRow(entry: log)
                                    .id(log.id)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: logs.count) { _, _ in
                        if let lastLog = logs.last {
                            withAnimation {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Button {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                    UIPasteboard.general.string = ConnectionDebugPanel.formatLogsForClipboard(logs, appVersion: version)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(copied ? "Kopiert ✓" : "Log kopieren")
                            .font(.caption)
                    }
                    .foregroundColor(copied ? .green : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Add `label` property to `ConnectionLogType`**

`ConnectionLogType` is in `romm/romm/Data/Services/ConnectionLogger.swift`. Add a `label` computed property after the `color` property (around line 34):

```swift
var label: String {
    switch self {
    case .info: return "info"
    case .success: return "ok"
    case .warning: return "warn"
    case .error: return "error"
    }
}
```

- [ ] **Step 3: Run the tests to confirm they pass**

```bash
xcodebuild test -scheme romm \
  -destination 'platform=iOS Simulator,arch=arm64,id=6AEDBF66-BBFD-4292-9C50-6E14F511FD0C' \
  -only-testing:rommTests/ConnectionLogFormatterTests 2>&1 \
  | grep -E "error:|FAIL|PASS|ConnectionLogFormatter"
```

Expected:
```
Test case 'ConnectionLogFormatterTests/formattedLogContainsAppVersionHeader()' passed
Test case 'ConnectionLogFormatterTests/formattedLogContainsEachEntryMessage()' passed
Test case 'ConnectionLogFormatterTests/formattedLogIncludesTimestamp()' passed
```

- [ ] **Step 4: Run all tests to confirm no regressions**

```bash
xcodebuild test -scheme romm \
  -destination 'platform=iOS Simulator,arch=arm64,id=6AEDBF66-BBFD-4292-9C50-6E14F511FD0C' \
  -only-testing:rommTests 2>&1 \
  | grep -E "FAIL|passed|failed" | tail -15
```

Expected: all tests passed, no failures.

- [ ] **Step 5: Commit**

```bash
git add romm/romm/UI/App/SetupView.swift \
        romm/romm/Data/Services/ConnectionLogger.swift \
        romm/rommTests/HeartbeatRepositoryTests.swift
git commit -m "feat: add copy button to connection debug panel"
```
