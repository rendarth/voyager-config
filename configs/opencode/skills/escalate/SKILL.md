---
name: escalate
description: Protocol and context generator for escalating complex or time-consuming tasks from local models (7B) to higher-reasoning frontier models (e.g. Gemini 3.1 Pro, Claude Sonnet/Opus 4.6 via agy, Big Pickle). Use when tasks exceed local capacity, run longer than 5 minutes, or loop without progress.
---

# Model Escalation Protocol

This skill guides local AI agents (e.g. Qwen 2.5 7B / Coder) on when and how to gracefully escalate tasks to frontier high-reasoning models. Every Escalation Package MUST name the recommended target model and the exact command to resume with it.

## 1. When to Escalate (Triggers)

Escalate immediately if **ANY** of the following occur:
1. **Time / Effort Bound:** Active troubleshooting, debugging, or research exceeds **~5 minutes** or **4 tool-call turns** without a working resolution.
2. **Repetition / Doom Loop:** You find yourself trying similar variations of failing commands, code edits, or regex fixes repeatedly.
3. **Deep Architectural Complexity:** Multi-file architectural refactors, complex distributed systems logic, deep concurrency/race conditions, or kernel/driver debugging that requires deep reasoning.
4. **High Ambiguity / Abstract Planning:** Large-scale feature planning requiring nuanced trade-offs and broad architectural foresight beyond a 7B model's sweet spot.

---

## 2. Escalation Output Format

When an escalation condition is met, stop running further trial commands. Instead, generate a structured **Escalation Package** with the following sections:

```markdown
### ⚠️ Model Escalation Recommendation

**Reason for Escalation:**
<Brief explanation: e.g., Task duration >5 min, repetitive error on X, architectural refactoring complexity>

**Recommended Target Model:**
- **Model:** <from the Model Recommendation Matrix below>
- **Tool / Command:** <exact launch command, e.g. `agy --model gemini-3.1-pro-high "..."` or `opencode --agent general "..."`>
- **Rationale:** <Why this specific model fits the task, e.g., superior multi-file refactoring, deep thinking/reasoning for race condition>

---

### 📦 Hand-off Context & Current State

1. **Goal:**
   <Exact user request and expected final state>

2. **Work Done & Findings:**
   - Files examined / modified: `path/to/file`
   - Key findings or confirmed facts: <Summary>
   - What failed / blocker: <Exact error message or barrier encountered>

3. **Current Code / Environment State:**
   ```<lang>
   <Relevant code snippet, diff, or diagnostic output>
   ```

---

### 🚀 Direct Next Prompt / Launch Command

Run this command to resume with the recommended model:

```bash
<agy / opencode / codex / claude command with optimized hand-off prompt>
```
```

---

## 3. Model Recommendation Matrix

All commands are verified against this machine (updated 2026-09-07). `agy` (Antigravity CLI) is the primary escalation path — it is already authenticated with the user's Google account and exposes 8 models from one command. `codex` and `claude` require login first (`codex login` / `claude` → `/login`).

| Task Type | Recommended Model | Tool / Command on this System | Rationale |
| :--- | :--- | :--- | :--- |
| **Complex Coding, Large Refactors, Deep Diffs** | Claude Sonnet 4.6 (Thinking) | `agy --model claude-sonnet-4-6` | Best-in-class multi-file editing, architectural reasoning, and agentic tool use. **PREFERRED for coding escalation.** |
| **Hardest Reasoning, Long-Horizon Agentic Tasks** | Claude Opus 4.6 (Thinking) | `agy --model claude-opus-4-6-thinking` | Top-tier reasoning depth; use for the most difficult problems. |
| **Deep Reasoning, System/Omarchy Debugging, Math & Algorithms** | Gemini 3.1 Pro (High) | `agy --model gemini-3.1-pro-high` | Highest Gemini reasoning depth, large context, Google Search grounding, sandboxed terminal tool use. |
| **Broad Research & Web Synthesis, Document Processing** | Gemini 3.8 Flash | `agy --model gemini-3.8-flash-medium` | Fast web-grounded synthesis and document processing; free tier via Google account. |
| **Open-Weight Coding, Balanced Free Tasks** | GPT-OSS 120B | `agy --model gpt-oss-120b-medium` | OpenAI open-weight model as a free alternative when other targets are cost-prohibitive. |
| **Quick Free Coding (non-sensitive repos only)** | Big Pickle (GLM-4.6 class) | `opencode --agent general` or `opencode --agent coder` | ~Sonnet 4.5/4.6-class coding at $0 (limited-time free), 200K context. **CAVEAT: free-period data may be used for training — never escalate confidential/client repos to it.** |
| **Math, Algorithms, Strict Correctness (OpenAI ecosystem)** | GPT-5.6-sol | `codex exec "..."` | High mathematical/algorithmic verification capabilities. Requires `codex login` first. |
| **Anthropic-native workflow (subscription/API)** | Claude Sonnet 4.6 / Opus 4.6 | `claude "..."` | Direct Claude Code access. Requires `/login` first. |
