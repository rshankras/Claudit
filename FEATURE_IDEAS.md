# Claudit Feature Ideas

## Phase 1: Cost & Efficiency Tracking (Completed)
- [x] Real-time quota tracking via Anthropic API
- [x] Cost tracking (today/week/month/all-time)
- [x] Model breakdown
- [x] JSONL parsing for accurate token counts
- [x] Cache efficiency score
- [x] Quota pacing indicator
- [x] Alerts/notifications
- [x] Project cost breakdown
- [x] Model usage recommendations

---

## Phase 2: Advanced Tracking Features

### 2.1 Session Cost Tracker
**Priority:** High | **Complexity:** Medium

Show cost for the *current active session* in real-time.

**What it shows:**
- "This session: $12.45 (2.3 hours)"
- Menubar indicator: `$12.45 ↑` (arrow indicates active session)

**Why it's useful:**
- Know when a single task is getting expensive
- Set mental budgets per task
- Decide when to stop and rethink approach

**Implementation:**
- Track session ID from JSONL files
- Group entries by `sessionId` field
- Calculate running cost for most recent session
- Update in real-time as new entries appear

---

### 2.2 Daily/Hourly Usage Heatmap
**Priority:** Medium | **Complexity:** Medium

Visual calendar showing usage intensity by hour/day.

**What it shows:**
- GitHub-style contribution graph
- Color intensity = cost/tokens used
- Hover for details: "Monday 2pm: $45.23"

**Why it's useful:**
- Identify patterns: "I blow through quota every Monday morning"
- Plan heavy work for when quota resets
- See productivity patterns

**Implementation:**
- Aggregate JSONL timestamps by hour/day
- Use Swift Charts for heatmap visualization
- Store aggregated data in SwiftData for fast rendering

---

### 2.3 Cost Per Conversation/Task
**Priority:** High | **Complexity:** Medium

Break down costs by conversation/session ID.

**What it shows:**
```
Recent Tasks:
├── Refactoring auth system    $45.23  (3.2 hrs)
├── Bug fix in parser          $2.10   (15 min)
├── Add unit tests             $8.45   (45 min)
└── Code review assistance     $1.20   (10 min)
```

**Why it's useful:**
- Understand which *types* of tasks cost most
- Identify expensive patterns
- Budget for future similar tasks

**Implementation:**
- Group JSONL entries by `sessionId`
- Extract task description from first user message
- Sum costs per session
- Display in dashboard view

---

### 2.4 Quota Forecast (Prominent)
**Priority:** High | **Complexity:** Low

Prominent warning when pace is unsustainable.

**What it shows:**
- "At current pace: **18 hours** until quota exhausted"
- "Quota resets in: **3 days 4 hours**"
- Color-coded: Green (safe) → Yellow (warning) → Red (critical)

**Why it's useful:**
- Prevents surprise rate limiting
- Allows pacing decisions
- Plan heavy work appropriately

**Implementation:**
- Already have pacing logic in `StatsManager`
- Make it more prominent in UI
- Add to menubar as optional display

---

### 2.5 Model Auto-Switch Suggestion
**Priority:** Medium | **Complexity:** Low

Suggest switching models based on quota status.

**What it shows:**
- Notification: "Opus at 85%. Consider: `claude --model sonnet`"
- "Haiku available - sufficient for simple tasks"

**Why it's useful:**
- Prevents hitting limits
- Saves money on simple tasks
- Educates about model differences

**Implementation:**
- Monitor quota percentages
- Trigger notification at thresholds (75%, 85%, 95%)
- Include actionable command in notification

---

### 2.6 Cost Comparison Widget
**Priority:** Low | **Complexity:** Low

Week-over-week spending comparison.

**What it shows:**
- "This week vs last week: +$45 (+23%)"
- Trend arrow: ↑ ↓ →
- Sparkline chart of daily costs

**Why it's useful:**
- Catch spending spikes early
- Track efficiency improvements
- Set and monitor budgets

**Implementation:**
- Compare current week totals with previous week
- Calculate percentage change
- Display in dashboard summary

---

## Phase 3: Learning & Improvement Features

### 3.1 Iteration Counter
**Priority:** High | **Complexity:** Medium

Track back-and-forth count per task.

**What it shows:**
```
Recent Tasks:
├── Auth refactor      3 iterations ✓ (efficient)
├── Parser bug        12 iterations ⚠️ (high)
└── API endpoint       5 iterations (normal)
```

**Why it's useful:**
- High iterations = prompt could be clearer
- Learn which task types need better prompts
- Track improvement over time

**Implementation:**
- Count user messages per session
- Categorize: 1-3 (efficient), 4-7 (normal), 8+ (high)
- Store in SwiftData for trending

**Learning insight:** "What made this task need 12 tries? How could the initial prompt be better?"

---

### 3.2 Prompt Length vs Success Analysis
**Priority:** Medium | **Complexity:** Medium

Correlate prompt length with task success.

**What it shows:**
- "Most efficient tasks: 50-150 word prompts"
- "500+ word prompts took 3x more iterations"
- Scatter plot: prompt length vs iterations

**Why it's useful:**
- Concise, specific prompts often work better
- Identify over-explaining tendencies
- Find your optimal prompt length

**Implementation:**
- Calculate token count of user messages
- Correlate with iteration count
- Generate recommendations

**Learning insight:** "Longer ≠ better. Be specific, not verbose."

---

### 3.3 Tool Usage Insights
**Priority:** High | **Complexity:** Low

Show which Claude tools get used most.

**What it shows:**
```
Your Tool Usage:
Read    ████████████████░░░░  45%
Edit    ██████████░░░░░░░░░░  30%
Bash    ██████░░░░░░░░░░░░░░  15%
Grep    ████░░░░░░░░░░░░░░░░  10%
```

**Why it's useful:**
- Low Grep/Glob = might be searching inefficiently
- High Bash = might be doing things Claude has tools for
- Understand your workflow patterns

**Implementation:**
- Parse tool calls from JSONL entries
- Aggregate by tool type
- Compare with "efficient" baselines

**Learning insight:** "Use search tools before asking Claude to find things manually."

---

### 3.4 Context Efficiency Score
**Priority:** Medium | **Complexity:** Medium

Measure how efficiently you use context.

**What it shows:**
```
Context Efficiency: 27%
Avg context sent:    45,000 tokens
Avg useful context:  12,000 tokens
Cache hit rate:      85%
```

**Why it's useful:**
- High input, low output = inefficient prompts
- High cache write + low cache read = repeating context
- Learn to use `/compact` and file references

**Implementation:**
- Calculate input/output ratio
- Track cache patterns
- Generate efficiency score

**Learning insight:** "Reference files instead of pasting. Use /compact regularly."

---

### 3.5 Prompt Pattern Library
**Priority:** Low | **Complexity:** High

Save successful prompts as templates.

**What it shows:**
- Library of your best prompts by category
- "This style worked well for refactoring"
- Auto-suggest similar successful patterns

**Why it's useful:**
- Learn from your own success
- Reuse effective patterns
- Build personal prompt cookbook

**Implementation:**
- Allow marking prompts as "successful"
- Categorize by task type
- Search and suggest similar patterns

**Learning insight:** "What worked before? Use it again."

---

### 3.6 Clarification Request Tracker
**Priority:** Medium | **Complexity:** Medium

Count how often Claude asks for clarification.

**What it shows:**
- "Claude asked 45 clarifying questions this week"
- "Down from 62 last week (-27%)"
- Examples of prompts that needed clarification

**Why it's useful:**
- High count = prompts lack specificity
- Track improvement in prompt clarity
- Learn what information to include upfront

**Implementation:**
- Detect clarifying questions in Claude responses
- Pattern match: "Could you clarify...", "What do you mean by...", etc.
- Track trend over time

**Learning insight:** "Include requirements, constraints, and examples upfront."

---

### 3.7 Before/After Improvement Tracking
**Priority:** Medium | **Complexity:** Low

Show skill improvement over time.

**What it shows:**
```
Your Progress:
              Week 1    Week 4    Change
Iterations:   8.2/task  3.1/task  -62%
Cost/task:    $5.20     $2.10     -60%
Clarifications: 12/day  4/day     -67%
```

**Why it's useful:**
- Motivation: see yourself improving
- Identify what's working
- Set improvement goals

**Implementation:**
- Store weekly aggregates in SwiftData
- Calculate week-over-week changes
- Display progress dashboard

**Learning insight:** "You're getting better! Keep using specific prompts."

---

### 3.8 Best Practices Nudges
**Priority:** Low | **Complexity:** High

Contextual tips based on your patterns.

**What it shows:**
- "You often edit the same file 5+ times. Try describing all changes in one prompt."
- "High token usage on tests. Try: 'write tests for X' instead of showing structure."
- "Consider using /compact - your context is growing large."

**Why it's useful:**
- Personalized learning
- Actionable improvement suggestions
- Catches inefficient patterns

**Implementation:**
- Define rules for detecting patterns
- Match user behavior against rules
- Display relevant tips

**Learning insight:** "Here's how to do this more efficiently."

---

## Quick Reference: Prompting Best Practices

| Technique | Example | Why It Helps |
|-----------|---------|--------------|
| **Be specific upfront** | "Add OAuth2 login using existing AuthService" | Reduces clarification loops |
| **Use `/compact`** | Run periodically in long sessions | Reduces context, saves tokens |
| **Reference don't paste** | "Read src/auth.ts and update it" | Claude reads what it needs |
| **One task per prompt** | Separate "add feature" from "write tests" | Clearer scope, better results |
| **State constraints** | "No new dependencies", "Keep backward compatible" | Prevents unwanted changes |
| **Give examples** | "Like the existing UserController pattern" | Ensures consistency |
| **Explain the why** | "We need this for GDPR compliance" | Better decision making |

---

## Implementation Priority

### Quick Wins (Low effort, high value)
1. Quota Forecast (prominent) - mostly done, enhance UI
2. Model Auto-Switch Suggestion - notification triggers
3. Cost Comparison Widget - simple calculation

### High Impact (Medium effort, high value)
1. Session Cost Tracker - real-time feedback
2. Iteration Counter - learning insights
3. Tool Usage Insights - workflow optimization
4. Cost Per Conversation - spending awareness

### Advanced (High effort, high value)
1. Prompt Pattern Library - personal knowledge base
2. Best Practices Nudges - AI-powered suggestions
3. Context Efficiency Score - deep analysis
