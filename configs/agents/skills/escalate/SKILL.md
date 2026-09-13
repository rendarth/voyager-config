---
name: escalate
description: Protocol and context generator for escalating complex or time-consuming tasks from local models (7B) to higher-reasoning frontier models (e.g. Claude 3.7 Sonnet, Gemini Pro, o3-mini). Use when tasks exceed local capacity, run longer than 5 minutes, or loop without progress.
---

# Model Escalation Protocol

This skill guides local AI agents (e.g. Qwen 2.5 7B / Coder) on when and how to gracefully escalate tasks to frontier high-reasoning models.

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
- **Model:** <e.g., Claude 3.7 Sonnet (Thinking), Gemini 3.7 Flash/Pro, or OpenAI o3-mini>
- **Tool / Command:** <e.g., `claude`, `agy`, or `codex`>
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
<claude / agy / opencode command with optimized hand-off prompt>
```
```

---

## 3. Model Recommendation Matrix

| Task Type | Recommended Model | Tool on this System | Rationale |
| :--- | :--- | :--- | :--- |
| **Complex Coding, Large Refactors, Deep Diffs** | Claude 3.7 Sonnet / Thinking | `claude` or `opencode` | Best-in-class multi-file editing, architectural reasoning, and bash tool use. |
| **System Debugging, Complex Omarchy/Arch Tasks** | Gemini 3.7 / 2.5 Pro (Thinking) | `agy` (`omarchy-agent`) | Integrated with Omarchy environment tools, high reasoning depth, large context. |
| **Math, Algorithms, Logic Puzzles, Strict Correctness** | OpenAI o3-mini / o1 | `codex` or `opencode` | High mathematical/algorithmic verification capabilities. |
| **Broad Research & Web Synthesis** | Gemini 2.5/3.0 Flash or Pro | `agy` or `opencode` | Fast web-grounded synthesis and document processing. |
