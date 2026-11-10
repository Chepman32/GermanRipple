# Ripple — Product Design Specification (PDS)

> **Working title:** Ripple (final name TBD — see §20 Open Questions)
> **Platform:** iOS (iPhone first, iPad compatible)
> **Backend:** Firebase, no-cost **Spark** plan only
> **Document version:** 1.0 (draft)
> **Date:** 7 November 2026
> **Status:** Ready for prototype & technical design review

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem & Opportunity](#2-problem--opportunity)
3. [Product Principles](#3-product-principles)
4. [Target Users](#4-target-users)
5. [Core Mechanic: The Ripple](#5-core-mechanic-the-ripple)
6. [Interaction Specification](#6-interaction-specification)
7. [Learning Model](#7-learning-model)
8. [Progress & Motivation](#8-progress--motivation)
9. [Information Architecture & Screens](#9-information-architecture--screens)
10. [Visual, Motion, Haptics & Audio](#10-visual-motion-haptics--audio)
11. [Accessibility](#11-accessibility)
12. [Content System](#12-content-system)
13. [Technical Architecture](#13-technical-architecture)
14. [Firebase (Spark) Design & Capacity Budget](#14-firebase-spark-design--capacity-budget)
15. [Monetization](#15-monetization)
16. [Privacy, Security & Compliance](#16-privacy-security--compliance)
17. [Analytics & Success Metrics](#17-analytics--success-metrics)
18. [Quality Assurance](#18-quality-assurance)
19. [Roadmap & MVP Scope](#19-roadmap--mvp-scope)
20. [Risks, Open Questions & Decisions Log](#20-risks-open-questions--decisions-log)
21. [Appendices](#21-appendices)

---

## 1. Executive Summary

**Ripple** is an iOS language-learning app built around one new interaction: **you change one thing in a correct sentence, and the sentence "ripples" — every word that must change as a consequence has to be fixed by you.** A chain of 5–8 such changes grows a three-word sentence into a long, natural one that the learner built, understands and can say aloud.

Flashcards train words in isolation. Translation exercises test whole sentences at once. Neither trains the thing learners actually get wrong in real speech: **dependencies** — tense dragging the auxiliary and participle along, a preposition forcing a case, a conjunction pushing the verb to the end. Ripple isolates exactly those dependencies and makes them tangible, one gesture at a time.

**Key properties**

| Property | Decision |
|---|---|
| Core loop | Drag a change card into a sentence → fix what rippled → hear the new sentence |
| Step duration | 5–15 seconds |
| Session | 3 chains ≈ 5 minutes |
| Felt progress | Every chain ends with a "Was → Now" screen: 3 words → 15+ words |
| Intelligence | 100% deterministic, authored content; **no AI at runtime** |
| Network | Offline-first; network only for content updates and optional sync |
| Backend | Firebase Spark: Hosting (content), Remote Config, Firestore (optional sync), Auth (Sign in with Apple), Analytics, Crashlytics, App Check |
| MVP language pair | English speakers learning German (A1–B1) |
| Monetization | Freemium, StoreKit 2 with on-device verification (no server) |

---

## 2. Problem & Opportunity

### 2.1 The market

The App Store holds thousands of language apps. Their interaction mechanics fall into a few families:

| Family | Typical form | What it trains well | What it misses |
|---|---|---|---|
| Flashcards / SRS | Word → meaning, spaced repetition | Vocabulary recognition | Words in context, grammar |
| Gamified exercises | Match pairs, tap the word bank, translate | Recognition, basic sentences | Why a form changes; transfer to new sentences |
| Grammar quizzes | Fill-in-the-blank, choose the tense | Isolated rules | Rules interacting inside one sentence |
| Conversation / voice | Speak with a tutor or bot | Fluency, confidence | Accuracy; expensive (humans or AI) |
| Reading / input | Graded readers, subtitles | Comprehension | Production, accuracy |

### 2.2 The gap

Learners at A2–B1 typically *know* individual rules ("mit takes dative", "weil sends the verb to the end") but fail when several rules must be applied at once in a sentence they are producing. That interaction of rules is where errors live, and no mainstream app makes it the core loop.

### 2.3 Pedagogical grounding (why this is not a gimmick)

Ripple is an interface for a technique that has been used in language classrooms for decades: the **transformation / substitution drill** ("Change the subject to *we*", "Put it in the past"). Its known weaknesses on paper are that it is slow, boring and gives delayed feedback. Ripple removes those weaknesses:

- **Speed:** one drag + one or two taps per step instead of rewriting a sentence.
- **Meaning stays intact:** the learner always works with a whole, sensible sentence and its translation (form is learned *inside* meaning, not as a table).
- **Noticing:** the before/after contrast of each step makes the changed forms visible.
- **Retrieval:** at higher levels the learner must decide *which* words change without being shown — active recall, not recognition.
- **Immediate, specific feedback:** every error is explained by the exact rule involved.
- **Spaced practice per rule:** the scheduler brings weak dependencies back in new sentences, which trains transfer rather than memorizing one sentence.

### 2.4 Differentiation

What exists today: isolated tense-selection items, word-bank sentence building, error spotting.
What does not exist as a core mechanic (based on a market scan, to be re-verified before launch — see §20): **a chained, cumulative sequence of mutations applied to one living sentence, where the learner resolves the consequences ("the ripple") of each change.**

---

## 3. Product Principles

1. **One gesture, one consequence.** Each step introduces exactly one change. The learner always knows what caused the ripple.
2. **Always a whole, meaningful sentence.** No orphan words, no blanks without context.
3. **Progress you can read.** The sentence visibly grows; the learner can read and say the result.
4. **Never blocked.** Every chain can be finished. After two failed attempts the step is revealed and explained, and the chain continues.
5. **Deterministic and offline.** No runtime AI, no network required to learn. Every answer is authored and verified by a native speaker.
6. **Fast by default.** Target 5–15 s per step; no typing anywhere in the core loop.
7. **Honest motivation.** No guilt notifications, no fake urgency, no hearts/lives that block learning.

---

## 4. Target Users

### 4.1 Personas

**P1 — "The stuck intermediate" (primary)**
Anna, 29, product designer, learned German for 1 year with apps and a course. Knows ~1,500 words, understands rules when explained, but freezes and makes case/word-order errors when speaking. Has 5–10 minutes several times a day (commute, queue). Wants to *feel* her grammar improve.

**P2 — "The structured beginner" (secondary)**
Mark, 41, moving to Germany for work in 6 months. A1, uses a flashcard app for vocabulary. Wants a short daily habit that builds correct sentences, not just words.

**P3 — "The returner" (tertiary)**
Olga, 35, studied German at school 15 years ago. Has passive knowledge, lost accuracy. Wants a quick refresher that shows her what she still knows.

### 4.2 Jobs to be done

- "When I have a few minutes, I want a short task that clearly improves my grammar, so I feel my time was useful."
- "When I make the same mistakes when speaking, I want to practice exactly those dependencies until they become automatic."
- "When I finish practicing, I want to see concrete proof of progress, so I keep going."

### 4.3 Non-target (explicitly)

- Absolute zero beginners who don't yet read the script (they need an alphabet/pronunciation primer first).
- Exam-prep learners needing full skill coverage (listening comprehension, essays).
- Children under 13 (the app is not designed for or directed at children).

---

## 5. Core Mechanic: The Ripple

### 5.1 Glossary

| Term | Definition |
|---|---|
| **Chain** | A sequence of 5–8 steps applied to one sentence, from a short base sentence to a long final sentence. One chain ≈ 1.5–2 minutes. |
| **Step** | One mutation plus its consequences. |
| **Card** | The mutation the learner applies (e.g. `ich → wir`, `+ gestern`, `+ weil …`). |
| **Token** | One word (or punctuation mark) in the sentence. Tokens have stable IDs across all steps of a chain. |
| **Ripple** | The set of consequences of a card: tokens that must change form, tokens that must move, tokens that must appear. |
| **Stale token** | A token whose current form is no longer correct after the card was applied. |
| **Spawned token** | A token that must newly appear as a consequence (e.g. a past participle). |
| **Fix** | The learner choosing the correct form for a token. |
| **Move** | The learner dragging a token to a new position. |
| **Rule tag** | Identifier of the grammatical dependency being trained (e.g. `prep.dative`). Every fix, move and card carries rule tags. |
| **Hint level** | How much help a step shows (L1 Guided, L2 Counted, L3 Free). |
| **Peel** | Reverse mode: start from the final sentence and undo the chain step by step. |

### 5.2 The loop

```
┌─────────────────────────────────────────────────────────────┐
│ 1. SEE      A correct sentence + translation                │
│ 2. APPLY    Drag the change card into the sentence          │
│ 3. RIPPLE   The sentence shakes; consequences appear        │
│ 4. FIX      Tap words → pick forms; drag words → reorder    │
│ 5. CHECK    Correct → audio + updated translation           │
│             Wrong   → specific explanation, retry           │
│ 6. NEXT     The new sentence is the base for the next card  │
└─────────────────────────────────────────────────────────────┘
      after the last step → "Was → Now" summary screen
```

### 5.3 Worked example (German, A2)

| # | Card | Sentence after the step | What rippled | Rule tags |
|---|---|---|---|---|
| 0 | — | Ich trinke Kaffee. | — | — |
| 1 | `ich → wir` | Wir trinke**n** Kaffee. | verb ending | `verb.present.regular` |
| 2 | `+ ein · groß` (before *Kaffee*) | Wir trinken **einen großen** Kaffee. | article + adjective inflect (masc. accusative) | `article.indef.acc`, `adj.decl.mixed` |
| 3 | `Kaffee → Tee` | Wir trinken einen großen Tee. | **nothing** (both masculine) | `noun.gender` |
| 4 | `+ jeden Morgen` (at start) | Jeden Morgen **trinken wir** einen großen Tee. | verb-second inversion | `order.v2-inversion` |
| 5 | `jeden → gestern` | Gestern Morgen **haben** wir einen großen Tee **getrunken**. | Perfekt: auxiliary + participle at the end | `verb.perfekt.haben`, `verb.participle.irregular`, `order.bracket.perfekt` |
| 6 | `+ mit · meine Schwester` (after *wir*) | … haben wir mit **meiner** Schwester einen großen Tee getrunken. | dative after *mit* | `prep.dative`, `possessive.dat` |
| 7 | `+ , weil · wir · sein · müde` (at end) | …, weil wir müde **waren**. | past tense of *sein* + verb-final | `conj.weil`, `order.verb-final.subordinate`, `verb.praeteritum.sein-haben` |

**Final screen:**
*Ich trinke Kaffee.* → *Gestern Morgen haben wir mit meiner Schwester einen großen Tee getrunken, weil wir müde waren.*
("Yesterday morning we had a big tea with my sister because we were tired.")

Step 3 is deliberate: **some cards change nothing**, and the learner must recognize that and tap **"Nothing changes"**. This prevents the learned shortcut "just tap what's highlighted / something always changes".

### 5.4 Card types (mutation catalog)

| Type | Icon | Description | Typical ripples (German) |
|---|---|---|---|
| `SUBSTITUTE` | ⇄ | Replace one token or phrase with another | Agreement (person, number, gender, case) |
| `INSERT` | ＋ | Add a word, phrase or clause at a slot | Case (prepositions), inflection, word order (adverbials, subordinate clauses) |
| `DELETE` | − | Remove a word or phrase | Reverse ripple (e.g. removing a modal returns the verb to finite form) |
| `TRANSFORM` | ◐ | Meta-change of the whole sentence: tense, negation, question, imperative, plural | Auxiliaries, participles, word order, *kein/nicht* |
| `MERGE` *(v2)* | ⧉ | Join with a second short sentence via a conjunction | Verb-final, comma, pronoun replacement |

Inserted material arrives either in **final form** (no choice needed, e.g. *jeden Morgen*) or in **lemma form** (dictionary form, e.g. *ein · groß*) that the learner must inflect. Lemma-form insertion is how vocabulary and inflection are combined in one step.

### 5.5 Peel mode (reverse)

Peel replays a completed chain backwards: the learner starts from the final sentence and receives inverse cards (`wir → ich`, `− mit meiner Schwester`, `gestern → jeden`). The engine derives each reverse step automatically from the stored snapshots; only an `inverseLabel` per step is authored. Peel is ideal for review: it revisits the same rules from the opposite direction.

---

## 6. Interaction Specification

### 6.1 Chain player layout (iPhone portrait)

```
┌───────────────────────────────────────┐
│ ✕     ● ● ● ○ ○ ○ ○         L2 ·  ⓘ   │  ← top bar: close, step dots, hint badge
│                                       │
│                                       │
│   Jeden Morgen trinken wir einen      │  ← sentence canvas (flow layout,
│   großen Tee.                         │     tokens are chips, ~55% height)
│                                       │
│   Every morning we drink a big tea.   │  ← translation (gloss) line
│                                    🔊 │
│                                       │
├───────────────────────────────────────┤
│   ┌────────────────────────┐          │
│   │ ⇄  jeden → gestern     │          │  ← card (draggable)
│   │    every → yesterday   │          │
│   └────────────────────────┘          │
│                                       │
│  [ Nothing changes ]   [ ↺ ]  [Check] │  ← action row
└───────────────────────────────────────┘
```

### 6.2 Step state machine

```
             ┌─────────────┐
             │  CardReady  │  card in tray, sentence correct
             └──────┬──────┘
         drop card  │  (on valid slot / on target token)
                    ▼
             ┌─────────────┐
             │   Rippled   │  animation; stale/spawned per hint level
             └──────┬──────┘
                    ▼
             ┌─────────────┐  tap token → picker → choose form
             │   Fixing    │  drag token → reorder
             └──────┬──────┘  place spawned chip
        Check /     │  "Nothing changes"
        auto-check  ▼
             ┌─────────────┐
       ┌─────│  Checking   │─────┐
   all │     └─────────────┘     │ errors
correct▼                          ▼
┌─────────────┐          ┌─────────────────┐
│   Correct   │          │  Incorrect(n)   │
└──────┬──────┘          └───────┬─────────┘
       │                n = 1    │  mark wrong tokens + short reason → Fixing
       │                n = 2    │  reveal correct answer + explanation
       ▼                         ▼
 audio + gloss update      ┌─────────────┐
       │                   │  Revealed   │  "Got it" → next
       ▼                   └──────┬──────┘
   NextStep / ChainSummary ◄──────┘
```

### 6.3 Gestures and controls

| Action | Primary gesture | Alternative (accessibility / one-handed) |
|---|---|---|
| Apply card (`SUBSTITUTE`) | Drag card onto target token | Tap card → target token pulses → tap it |
| Apply card (`INSERT`) | Drag card; drop zones appear between tokens; drop | Tap card → tap a drop zone |
| Apply card (`TRANSFORM`) | Drag anywhere onto the sentence | Tap card → "Apply" |
| Choose a form | Tap token → bottom picker → tap form | VoiceOver: token action "Change form" |
| Move a token | Long-press (0.25 s) + drag | Select token → "Move left / Move right" actions |
| Place a spawned token | Drag the `?` chip from the tray into the sentence | Tap chip → tap drop zone |
| Declare no change | "Nothing changes" button | — |
| Check | "Check" button (auto-check at L1 once all stale tokens are resolved) | — |
| Reset step | ↺ (restores the state right after the card was applied) | — |
| Hear sentence / word | 🔊 for sentence; double-tap token for the word | VoiceOver reads tokens normally |
| Reveal translation | Tap the gloss line if "Hide translation" is enabled | — |

**Drop rules**

- Dropping a card on an invalid slot: the card springs back, the slot flashes neutral; this counts as an error for the card's rule tags only if the slot choice is itself being trained (`card.slotIsTrained = true`, e.g. adverb placement). Otherwise it is free.
- At L1 the valid slot glows while dragging. At L2/L3 all slots between tokens are shown equally.

### 6.4 The picker

- Bottom sheet, compact height, 3–4 large pill buttons, current form marked with a dot.
- Options = correct form + distractors (see §12.5). Option order is shuffled deterministically per step (seeded by chain ID + step index) so it is stable on retries.
- **L1:** each pill shows a tiny grammatical label (`wir · Präsens`, `Dativ · fem.`).
- **L2/L3:** no labels.
- Tokens with a single possible form (e.g. *mit*) show: "This word doesn't change."

### 6.5 Hint levels

| Level | Name | What is shown |
|---|---|---|
| **L1** | Guided | Stale tokens highlighted (amber + dashed underline); spawned slot glows; valid card slot glows; picker labels; auto-check |
| **L2** | Counted | A banner: "2 words change · 1 moves" (or "Nothing changes here?" is *not* shown); no highlights; no picker labels |
| **L3** | Free | No information at all. Any token can be tapped or moved. The learner decides whether anything changes. |

The step's hint level = the level of its **weakest** rule tag (§7.3), so the learner gets help exactly where they need it. Users can force "Always guided" in Settings.

### 6.6 Validation

The engine compares the learner's state with the authored target. A step is correct when:

1. Every token's current text equals the target text for that step (after automatic capitalization of the first token), **and**
2. The token order equals one of the step's `acceptedOrders`, **and**
3. All spawned tokens are placed.

```swift
// Simplified, deterministic validation
func validate(state: StepState, target: StepTarget) -> ValidationResult {
    var errors: [TokenError] = []

    for token in target.tokens {
        guard let current = state.token(id: token.id) else {
            errors.append(.missing(token.id, rules: target.rules(for: token.id)))
            continue
        }
        if current.text.normalized != token.text.normalized {
            let kind: TokenError.Kind = target.isStale(token.id) ? .wrongForm : .unnecessaryChange
            errors.append(TokenError(id: token.id, kind: kind, rules: target.rules(for: token.id)))
        }
    }

    let order = state.tokenOrder
    if !target.acceptedOrders.contains(order) {
        let misplaced = target.closestOrder(to: order).misplacedTokens(comparedTo: order)
        errors += misplaced.map { TokenError(id: $0, kind: .wrongPosition, rules: target.moveRules(for: $0)) }
    }

    return errors.isEmpty ? .correct : .incorrect(errors)
}
```

Normalization: Unicode NFC, trimmed. Case is compared exactly except for the sentence-initial capital, which the engine applies automatically (German nouns are stored capitalized).

### 6.7 Feedback copy rules

- Never "Wrong!". Use: **"Not quite."** + one specific reason, generated from the rule tag's explainer template.
  - Wrong form: *"After **mit**, use the dative: **meiner** Schwester."*
  - Unnecessary change: *"This one was fine — **Tee** is masculine like **Kaffee**."*
  - Wrong position: *"In a **weil**-clause, the verb goes to the end."*
- "Why?" link expands the rule explainer (2–3 lines + a mini-table, authored per rule).
- After a reveal: the correct answer animates into place, then the explanation; the step is logged as failed for the involved rule tags.

### 6.8 Session flow

- **Today** = a set of 3 chains (≈ 5 min) chosen by the scheduler (§7.5).
- After each chain: Chain Summary (§9.7). "Next chain" is the primary button; "Done for now" secondary.
- After the 3rd chain: Session Summary with rule-map changes; option to continue (Pro: unlimited; Free: see §15).

---

## 7. Learning Model

All logic runs on-device and is deterministic.

### 7.1 Units of knowledge

The unit of mastery is the **rule tag**, not the sentence and not the word. A German A1–B1 MVP uses ~50 rule tags (Appendix A). Vocabulary (lemmas) is tracked as exposure counts only (secondary).

### 7.2 Rule state

```swift
struct RuleState: Codable {
    let ruleId: String
    var strength: Double        // 0.0 ... 1.0
    var intervalDays: Double    // spacing interval
    var dueDate: Date
    var attempts: Int
    var firstTryCorrect: Int
    var lastSeen: Date?
    var unlocked: Bool
}
```

### 7.3 Update rule (per rule tag per step)

A rule tag is **correct** in a step if every fix/move/decision carrying that tag was correct on the **first** check.

```swift
mutating func update(correct: Bool, now: Date) {
    attempts += 1
    lastSeen = now
    if correct {
        firstTryCorrect += 1
        strength += 0.25 * (1 - strength)            // asymptotic growth
        intervalDays = min(60, max(1, intervalDays * 2.2))
    } else {
        strength *= 0.6                              // noticeable drop, not reset
        intervalDays = 1
    }
    dueDate = now.addingTimeInterval(intervalDays * 86_400)
}
```

**Hint level mapping**

| Strength | Hint level |
|---|---|
| < 0.40 | L1 Guided |
| 0.40 – 0.75 | L2 Counted |
| > 0.75 | L3 Free |

**Mastery tiles** (Rule Map): 0–5 filled segments = `floor(strength * 5)`; a rule counts as **mastered** when strength > 0.85 and it was correct at L3 at least 3 times in different chains.

### 7.4 Unlocking

Rules form a prerequisite graph (e.g. `order.bracket.perfekt` requires `verb.present.regular`; `adj.decl.mixed` requires `article.indef.acc`). A rule unlocks when all prerequisites reach strength ≥ 0.40. A chain is **eligible** if all its rule tags are unlocked, or exactly one is newly unlockable (that chain then introduces the new rule).

**First encounter of a rule:** forced L1, the explainer opens automatically after the ripple animation, and the step is not scored as a failure if wrong (only as an exposure).

### 7.5 Chain selection (Today's set)

```
candidates = eligible chains not played in the last 14 days
score(chain) =
    3.0 × Σ over rule tags: overdue(rule)          // overdue = max(0, days past due) capped at 7, normalized
  + 2.0 × weakness(chain)                           // mean (1 − strength) of its tags
  + 1.5 × [chain introduces exactly one new rule]   // only for slot 3
  − 2.0 × overlap(chain, other chains in the set)   // avoid 3 chains drilling the same thing
  + 0.5 × themeVariety
Today's set:
  slot 1 = best "review" chain (highest overdue component)
  slot 2 = best "mixed" chain
  slot 3 = best "new" chain if a new rule is unlockable, otherwise best remaining
```

If all eligible chains were played in the last 14 days, allow replays, preferring the least recently played; replays use fresh shuffling of picker options.

### 7.6 Placement (optional, during onboarding)

Three short chains (4 steps each) at forced L3, covering A1, A2 and B1 rule tags. For each tag seen: correct → strength 0.6, due in 3 days; incorrect → strength 0.1, due today. The starting CEFR band is the highest band with ≥ 70% first-try accuracy. "Skip" → A1 with default strengths of 0.

### 7.7 Vocabulary

- Each chain lists its lemmas; new lemmas (exposure count 0) always show their gloss on the card.
- The CEFR vocabulary level of a chain must not exceed the learner's band (enforced at authoring time by the compiler, §12.6).
- Vocabulary is not tested separately in the MVP.

---

## 8. Progress & Motivation

The user must feel progress **within the first minute** and **after every chain**.

| Moment | Progress signal |
|---|---|
| Every step | The sentence visibly grows or transforms; audio plays the improved sentence |
| End of chain | **Was → Now** screen: base sentence vs final sentence, word count (e.g. "3 → 16 words"), steps solved first try |
| End of session | Rule Map tiles fill with animation; list of rules that leveled up (e.g. "Dative after *mit*: Guided → Counted") |
| Over days | **Longest sentence** record; **Gallery** of all final sentences built (replay audio, open Peel) |
| Over weeks | Rule Map coverage per CEFR band ("A2: 14/22 rules mastered") |
| Habit | Streak with 1 free "freeze" per week, earned automatically; streak is shown but never used as a threat |

**Explicitly excluded:** hearts/lives, energy timers, leaderboards (MVP), loss-framed notifications ("You'll lose your streak!").

**Notifications:** local only (`UNUserNotificationCenter`), max 1/day at a user-chosen time, content example: *"Today's 3 chains are ready — about 5 minutes."* Permission is requested **after** the first completed session, not at launch.

---

## 9. Information Architecture & Screens

### 9.1 Navigation map

```
Launch
 └─ Onboarding (first run only)
     ├─ O1 Languages
     ├─ O2 Interactive demo chain
     ├─ O3 Placement (optional)
     └─ O4 Daily goal
Main (tab bar)
 ├─ Today         → Chain Player → Chain Summary → (next chain) → Session Summary
 ├─ Rules (Rule Map) → Rule Detail → Practice this rule (chain player)
 ├─ Gallery       → Sentence Detail → Replay audio / Peel
 └─ Settings      → Account & Sync, Learning, Audio, Notifications, Subscription, Privacy, About
```

### 9.2 O1 — Languages
- "I speak": English (MVP); Russian (v1.1).
- "I'm learning": German (MVP). Other languages shown as "Coming soon" with an optional local "notify me" toggle (no data sent).

### 9.3 O2 — Interactive demo (the "aha" moment)
- A 3-step chain at L1 with coach marks: *"Drag the card into the sentence"* → *"Something broke — tap the glowing word"* → *"Pick the right form"*.
- Ends with a mini Was → Now: *Ich trinke Kaffee → Wir trinken einen großen Kaffee.*
- Target: completed by ≥ 85% of new users in < 60 s.

### 9.4 O3 — Placement
- "Already know some German?" → [Find my level (2 min)] / [Start from the beginning].

### 9.5 O4 — Daily goal
- 3 chains (~5 min) · 6 chains (~10 min) · 9 chains (~15 min). Changeable later. No account prompt.

### 9.6 Today (home)
- Header: streak, today's progress ring (chains done / goal).
- Card stack of today's 3 chains: theme icon + title (e.g. "☕ Morning coffee"), CEFR badge, rule chips (max 3), estimated duration.
- Primary button "Start" (continues the next unfinished chain).
- After goal completion: "Goal done ✓" + "One more chain" + longest-sentence teaser.
- **States:** first day; goal done; free limit reached (Pro upsell, dismissible); content update available (silent background download, never blocking).

### 9.7 Chain Summary
- Was → Now (both sentences, final with play button, translation).
- Stats: "6 of 7 steps first try", "+13 words".
- Rule chips with up/down indicators.
- Buttons: [Next chain] (primary), [Peel it] (Pro badge if Free), [Done].
- Share: export an image card of Was → Now (rendered locally with `ImageRenderer`, no server).

### 9.8 Session Summary
- Rule Map excerpt with animated fills, rules that changed hint level, streak update.

### 9.9 Rules (Rule Map)
- Grid grouped by category: Verbs · Word order · Articles & adjectives · Cases & prepositions · Pronouns · Clauses.
- Each tile: short name ("*mit* + Dative"), 5-segment fill, lock icon if locked, due dot if overdue.
- Filter by CEFR band.

### 9.10 Rule Detail
- Explainer (same text as in feedback), 2–3 example pairs from chains the user completed (before/after), accuracy history (sparkline of first-try results), button "Practice this rule" (builds an ad-hoc set of 2 chains weighted to this rule).

### 9.11 Gallery
- Chronological list of final sentences (with theme icon and date); search by German word; tap → Sentence Detail (play, show translation, view all layers as a vertical timeline, Peel).

### 9.12 Settings
- **Learning:** always guided; hide translation until step is solved; daily goal.
- **Audio:** autoplay after correct step; speech rate (0.8× / 1×); voice selection (system voices available for German) + hint how to download enhanced voices in iOS Settings.
- **Feedback:** haptics on/off; sounds on/off.
- **Notifications:** reminder time / off.
- **Account & Sync:** Sign in with Apple to sync progress (optional); sign out; delete account.
- **Subscription:** status, restore purchases, manage.
- **Privacy:** analytics on/off; link to privacy policy; "Report a content problem" history (local).
- **About:** content pack version, app version, licenses/attributions.

### 9.13 Paywall
- Shown only: when the free daily limit is reached and the user taps "One more chain"; when tapping Peel; from Settings. Never during the first session.
- Content: 3 benefit lines, plan selector, "Restore", terms & privacy links, clear trial terms.

### 9.14 Content problem report (sheet)
- Reachable from the "ⓘ" in the chain player and on reveal screens.
- Reasons: "My answer should also be correct", "The correct answer is wrong", "Bad translation", "Audio problem", "Other" + optional note (≤ 500 chars).

---

## 10. Visual, Motion, Haptics & Audio

### 10.1 Visual language
- Calm, typographic. The sentence is the hero: large serif or humanist sans for target-language tokens (28 pt default, scaling down to 22 pt for sentences > 14 tokens; Dynamic Type respected).
- Token chips: no visible border in rest state (reads as normal text); subtle background on press.
- **Semantic colors** (each paired with a non-color cue):

| Meaning | Color | Non-color cue |
|---|---|---|
| Stale (L1) | Amber | Dashed underline |
| Spawned slot | Amber outline | `?` glyph |
| Correct | Green flash (300 ms), then neutral | ✓ haptic |
| Wrong | Red tint | Wavy underline + shake |
| Just changed (after correct) | Accent tint fading over 1.2 s | Bold for 1.2 s |

- Light and dark themes; all pairs ≥ 4.5:1 contrast.

### 10.2 Motion
| Event | Animation | Duration |
|---|---|---|
| Card drop | Card shrinks into slot | 180 ms ease-out |
| Ripple | Wave from the drop point outward; each token scales 1.00 → 1.06 → 1.00, staggered 40 ms per token distance | ~250 ms per token, total ≤ 700 ms |
| Stale reveal (L1) | Amber underline draws left → right | 200 ms |
| Reorder | Tokens reflow with spring | response 0.35, damping 0.8 |
| Wrong | Horizontal shake 3× 6 pt | 300 ms |
| Reveal | Correct tokens morph into place (text cross-fade) | 400 ms |
| Was → Now | Base sentence slides up, final sentence types in token by token | ~1.2 s |

**Reduce Motion:** ripple wave and shakes replaced by cross-fades and static highlights.

### 10.3 Haptics
- Card drop: `.medium` impact. Correct step: `.success` notification. Wrong: `.error` notification. Picker selection: `.selection`.

### 10.4 Audio
- **Engine:** `AVSpeechSynthesizer` on-device (free, offline, no backend). Prefer enhanced/premium German voices if installed; otherwise default.
- Plays the full sentence after each correct step (toggle), on 🔊 tap, and single words on double-tap.
- Content QA includes listening to every final sentence with the default voice; known mispronunciations are fixed via an optional per-token `ipa` / phonetic override field (uses `AVSpeechSynthesisIPANotationAttribute`).
- Pre-recorded native audio is a v2 option (§19), not MVP.

---

## 11. Accessibility

- **Every drag has a tap alternative** (§6.3). The whole chain can be completed without dragging.
- **VoiceOver:** each token is an element with label = text, hint = "Double-tap to change form. Actions available: move left, move right." Custom rotor "Changed words" lists stale tokens at L1. The ripple is announced: *"The sentence changed. 2 words need attention."* (L1) / *"The sentence changed."* (L2/L3).
- **Dynamic Type** up to AX5: the sentence canvas becomes scrollable; the tray collapses into a bottom bar.
- **Color independence:** every state has a shape cue (§10.1).
- **Minimum touch target** 44 × 44 pt for all tokens (chips pad short words like "in").
- **Reduce Motion, Reduce Transparency, Bold Text** honored.
- **Switch Control / Voice Control:** all actions are buttons with visible names ("Check", "Nothing changes").

---

## 12. Content System

Content is the product. The code is comparatively small; quality depends on well-authored, native-verified chains.

### 12.1 Content volume (MVP, German for English speakers)

| Item | Target |
|---|---|
| Rule tags | ~50 (Appendix A) |
| Chains | 240 (A1: 70, A2: 100, B1: 70) |
| Steps | ~1,450 (avg. 6 per chain) |
| Lemmas | ~900 |
| Themes | 12 (café, home, travel, work, shopping, health, weather, family, city, food, free time, plans) |
| Days of fresh content at 3 chains/day | 80 (plus unlimited spaced replays) |

Each rule tag must appear in ≥ 12 chains at varying positions and with varying vocabulary (to train transfer, not memorization).

### 12.2 Pack structure

A **pack** = one target language + one gloss (UI) language, e.g. `de-en`. A pack is split into **units** of ~20 chains so that updates download only changed units.

```
/content/
  manifest.json                         (short cache)
  de-en/
    v12/
      index.json                        (chain metadata, rules, lexicon refs, unit list + hashes)
      rules.json                        (rule tags, prerequisites, explainers)
      lexicon.json                      (paradigms of all lemmas used)
      units/
        u01.<sha256-prefix>.json        (immutable, long cache)
        u02.<sha256-prefix>.json
        ...
```

A full baseline pack is **bundled in the app binary**, so the first launch works fully offline.

### 12.3 Manifest

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-11-07T12:00:00Z",
  "packs": [
    {
      "packId": "de-en",
      "version": 12,
      "minAppVersion": "1.0.0",
      "index": { "path": "/content/de-en/v12/index.json", "sha256": "9f2c...e1" },
      "rules": { "path": "/content/de-en/v12/rules.json", "sha256": "a17b...04" },
      "lexicon": { "path": "/content/de-en/v12/lexicon.json", "sha256": "c4d0...9a" }
    }
  ]
}
```

### 12.4 Chain schema (unit file excerpt — the worked example)

Conventions:
- `tokens` in each step is the **full target snapshot** after that step (order = canonical accepted order).
- `initial` = the text a token shows when it first appears (lemma form for inserted words); omitted if equal to `text`.
- Stale tokens are derived by the compiler (token text differs from the previous snapshot) and listed explicitly in `fixes` for rule tagging and optional authored distractors.
- Sentence-initial capitalization and the terminal punctuation mark are applied by the engine.

```json
{
  "chainId": "de.a2.cafe.003",
  "cefr": "A2",
  "theme": "cafe",
  "title": { "en": "Morning tea" },
  "terminal": ".",
  "base": {
    "tokens": [
      { "id": "t1", "text": "ich", "lemma": "ich", "pos": "PRON" },
      { "id": "t2", "text": "trinke", "lemma": "trinken", "pos": "VERB" },
      { "id": "t3", "text": "Kaffee", "lemma": "Kaffee", "pos": "NOUN" }
    ],
    "gloss": { "en": "I drink coffee." }
  },
  "steps": [
    {
      "card": { "type": "SUBSTITUTE", "target": "t1", "label": "ich → wir", "cardGloss": { "en": "I → we" }, "rules": [] },
      "inverseLabel": "wir → ich",
      "tokens": [
        { "id": "t1", "text": "wir", "lemma": "wir", "pos": "PRON" },
        { "id": "t2", "text": "trinken", "lemma": "trinken", "pos": "VERB" },
        { "id": "t3", "text": "Kaffee", "lemma": "Kaffee", "pos": "NOUN" }
      ],
      "fixes": [ { "token": "t2", "rules": ["verb.present.regular"] } ],
      "moves": [],
      "acceptedOrders": [["t1", "t2", "t3"]],
      "gloss": { "en": "We drink coffee." }
    },
    {
      "card": {
        "type": "INSERT", "label": "+ ein · groß", "cardGloss": { "en": "+ a · big" },
        "slots": ["before:t3"], "slotIsTrained": false, "rules": []
      },
      "inverseLabel": "− einen großen",
      "tokens": [
        { "id": "t1", "text": "wir", "lemma": "wir", "pos": "PRON" },
        { "id": "t2", "text": "trinken", "lemma": "trinken", "pos": "VERB" },
        { "id": "t5", "text": "einen", "initial": "ein", "lemma": "ein", "pos": "DET" },
        { "id": "t6", "text": "großen", "initial": "groß", "lemma": "groß", "pos": "ADJ" },
        { "id": "t3", "text": "Kaffee", "lemma": "Kaffee", "pos": "NOUN" }
      ],
      "fixes": [
        { "token": "t5", "rules": ["article.indef.acc"], "distractors": ["ein", "einem", "eine"] },
        { "token": "t6", "rules": ["adj.decl.mixed"], "distractors": ["großer", "großem", "große"] }
      ],
      "moves": [],
      "acceptedOrders": [["t1", "t2", "t5", "t6", "t3"]],
      "gloss": { "en": "We drink a big coffee." }
    },
    {
      "card": { "type": "SUBSTITUTE", "target": "t3", "label": "Kaffee → Tee", "cardGloss": { "en": "coffee → tea" }, "rules": ["noun.gender"] },
      "inverseLabel": "Tee → Kaffee",
      "tokens": [
        { "id": "t1", "text": "wir", "lemma": "wir", "pos": "PRON" },
        { "id": "t2", "text": "trinken", "lemma": "trinken", "pos": "VERB" },
        { "id": "t5", "text": "einen", "lemma": "ein", "pos": "DET" },
        { "id": "t6", "text": "großen", "lemma": "groß", "pos": "ADJ" },
        { "id": "t3", "text": "Tee", "lemma": "Tee", "pos": "NOUN" }
      ],
      "fixes": [],
      "moves": [],
      "acceptedOrders": [["t1", "t2", "t5", "t6", "t3"]],
      "noChangeNote": { "en": "Tee is masculine, just like Kaffee — nothing else changes." },
      "gloss": { "en": "We drink a big tea." }
    },
    {
      "card": {
        "type": "INSERT", "label": "+ jeden Morgen", "cardGloss": { "en": "+ every morning" },
        "slots": ["start"], "slotIsTrained": false, "rules": []
      },
      "inverseLabel": "− jeden Morgen",
      "tokens": [
        { "id": "t7", "text": "jeden", "lemma": "jeder", "pos": "DET" },
        { "id": "t8", "text": "Morgen", "lemma": "Morgen", "pos": "NOUN" },
        { "id": "t2", "text": "trinken", "lemma": "trinken", "pos": "VERB" },
        { "id": "t1", "text": "wir", "lemma": "wir", "pos": "PRON" },
        { "id": "t5", "text": "einen", "lemma": "ein", "pos": "DET" },
        { "id": "t6", "text": "großen", "lemma": "groß", "pos": "ADJ" },
        { "id": "t3", "text": "Tee", "lemma": "Tee", "pos": "NOUN" }
      ],
      "fixes": [],
      "moves": [ { "token": "t2", "rules": ["order.v2-inversion"] } ],
      "acceptedOrders": [["t7", "t8", "t2", "t1", "t5", "t6", "t3"]],
      "gloss": { "en": "Every morning we drink a big tea." }
    },
    {
      "card": { "type": "SUBSTITUTE", "target": "t7", "label": "jeden → gestern", "cardGloss": { "en": "every → yesterday" }, "rules": [] },
      "inverseLabel": "gestern → jeden",
      "tokens": [
        { "id": "t7", "text": "gestern", "lemma": "gestern", "pos": "ADV" },
        { "id": "t8", "text": "Morgen", "lemma": "Morgen", "pos": "NOUN" },
        { "id": "t2", "text": "haben", "lemma": "haben", "pos": "AUX" },
        { "id": "t1", "text": "wir", "lemma": "wir", "pos": "PRON" },
        { "id": "t5", "text": "einen", "lemma": "ein", "pos": "DET" },
        { "id": "t6", "text": "großen", "lemma": "groß", "pos": "ADJ" },
        { "id": "t3", "text": "Tee", "lemma": "Tee", "pos": "NOUN" },
        { "id": "t9", "text": "getrunken", "lemma": "trinken", "pos": "VERB", "spawned": true }
      ],
      "fixes": [
        { "token": "t2", "rules": ["verb.perfekt.haben"], "distractors": ["trinken", "sind", "hatten"] },
        { "token": "t9", "rules": ["verb.participle.irregular"], "distractors": ["trinken", "trank", "tranken"] }
      ],
      "moves": [ { "token": "t9", "rules": ["order.bracket.perfekt"] } ],
      "acceptedOrders": [["t7", "t8", "t2", "t1", "t5", "t6", "t3", "t9"]],
      "gloss": { "en": "Yesterday morning we had a big tea." }
    },
    {
      "card": {
        "type": "INSERT", "label": "+ mit · meine Schwester", "cardGloss": { "en": "+ with · my sister" },
        "slots": ["after:t1"], "slotIsTrained": false, "rules": []
      },
      "inverseLabel": "− mit meiner Schwester",
      "tokens": [
        { "id": "t7", "text": "gestern", "lemma": "gestern", "pos": "ADV" },
        { "id": "t8", "text": "Morgen", "lemma": "Morgen", "pos": "NOUN" },
        { "id": "t2", "text": "haben", "lemma": "haben", "pos": "AUX" },
        { "id": "t1", "text": "wir", "lemma": "wir", "pos": "PRON" },
        { "id": "t10", "text": "mit", "lemma": "mit", "pos": "ADP" },
        { "id": "t11", "text": "meiner", "initial": "meine", "lemma": "mein", "pos": "DET" },
        { "id": "t12", "text": "Schwester", "lemma": "Schwester", "pos": "NOUN" },
        { "id": "t5", "text": "einen", "lemma": "ein", "pos": "DET" },
        { "id": "t6", "text": "großen", "lemma": "groß", "pos": "ADJ" },
        { "id": "t3", "text": "Tee", "lemma": "Tee", "pos": "NOUN" },
        { "id": "t9", "text": "getrunken", "lemma": "trinken", "pos": "VERB" }
      ],
      "fixes": [ { "token": "t11", "rules": ["prep.dative", "possessive.dat"], "distractors": ["meine", "meinen", "meinem"] } ],
      "moves": [],
      "acceptedOrders": [["t7", "t8", "t2", "t1", "t10", "t11", "t12", "t5", "t6", "t3", "t9"]],
      "gloss": { "en": "Yesterday morning we had a big tea with my sister." }
    },
    {
      "card": {
        "type": "INSERT", "label": "+ , weil · wir · sein · müde", "cardGloss": { "en": "+ because · we · be · tired" },
        "slots": ["end"], "slotIsTrained": false, "rules": ["conj.weil"]
      },
      "inverseLabel": "− , weil wir müde waren",
      "tokens": [
        { "id": "t7", "text": "gestern", "lemma": "gestern", "pos": "ADV" },
        { "id": "t8", "text": "Morgen", "lemma": "Morgen", "pos": "NOUN" },
        { "id": "t2", "text": "haben", "lemma": "haben", "pos": "AUX" },
        { "id": "t1", "text": "wir", "lemma": "wir", "pos": "PRON" },
        { "id": "t10", "text": "mit", "lemma": "mit", "pos": "ADP" },
        { "id": "t11", "text": "meiner", "lemma": "mein", "pos": "DET" },
        { "id": "t12", "text": "Schwester", "lemma": "Schwester", "pos": "NOUN" },
        { "id": "t5", "text": "einen", "lemma": "ein", "pos": "DET" },
        { "id": "t6", "text": "großen", "lemma": "groß", "pos": "ADJ" },
        { "id": "t3", "text": "Tee", "lemma": "Tee", "pos": "NOUN" },
        { "id": "t9", "text": "getrunken", "lemma": "trinken", "pos": "VERB" },
        { "id": "t17", "text": ",", "pos": "PUNCT" },
        { "id": "t13", "text": "weil", "lemma": "weil", "pos": "SCONJ" },
        { "id": "t14", "text": "wir", "lemma": "wir", "pos": "PRON" },
        { "id": "t16", "text": "müde", "lemma": "müde", "pos": "ADJ" },
        { "id": "t15", "text": "waren", "initial": "sein", "lemma": "sein", "pos": "AUX" }
      ],
      "initialOrderOfInserted": ["t17", "t13", "t14", "t15", "t16"],
      "fixes": [ { "token": "t15", "rules": ["verb.praeteritum.sein-haben"], "distractors": ["sind", "war", "sein"] } ],
      "moves": [ { "token": "t15", "rules": ["order.verb-final.subordinate"] } ],
      "acceptedOrders": [["t7", "t8", "t2", "t1", "t10", "t11", "t12", "t5", "t6", "t3", "t9", "t17", "t13", "t14", "t16", "t15"]],
      "gloss": { "en": "Yesterday morning we had a big tea with my sister because we were tired." }
    }
  ]
}
```

### 12.5 Distractors and the lexicon

- `lexicon.json` holds the full paradigm for every lemma used in the pack (e.g. all forms of *mein*, *trinken*, *groß*).
- **Authored distractors** (`fixes[].distractors`) take precedence. If absent, the engine picks up to 3 forms from the lemma's paradigm, preferring forms that differ in exactly one feature (case / number / person / tense) from the correct one.
- For **L2/L3**, any token can be tapped; the picker for a non-stale token shows its current form + up to 3 paradigm forms (so tapping does not leak whether the token is stale).
- **Distractor validity rule:** a distractor must be a real form of the same lemma or of a paradigm-relevant alternative (e.g. *haben*/*sein* for auxiliaries) and must be **ungrammatical in this exact position**. The compiler rejects distractors equal to any accepted answer.

### 12.6 Authoring pipeline

```
1. Draft       Author writes chains in a YAML/spreadsheet source (any drafting aids allowed offline)
2. Compile     `ripplec` CLI (Swift or Python) → builds snapshots, derives stale tokens, validates
3. Lint        Automated checks (below); build fails on any error
4. Native QA   Native speaker reviews every step + final sentence + glosses; signs off per unit
5. Listen      TTS pass on final sentences; add phonetic overrides where needed
6. Playtest    Internal TestFlight build with the new unit
7. Publish     Upload versioned files to Firebase Hosting; bump Remote Config version key
```

**Compiler lint checks**

| Check | Failure condition |
|---|---|
| Token continuity | Token ID reused for a different lemma; ID disappears without a `DELETE` card |
| Fix coverage | A token's text changed but no `fixes` entry exists (or vice versa) |
| Order coverage | `acceptedOrders` arrays don't contain exactly the step's token IDs |
| Distractor validity | Distractor equals the correct form or is missing from the lexicon |
| Rule tags | Unknown rule ID; step with ripple but zero rule tags |
| No-change steps | Between 10% and 20% of steps per pack are no-change steps (warning outside range) |
| Step size | More than 3 fixes + moves in one step (warning: too much at once) |
| Vocabulary level | Lemma CEFR above the chain's band (warning) |
| Gloss coverage | Missing gloss for any step in the pack's gloss language |
| Length | Final sentence > 22 tokens (warning, phone layout) |
| Ambiguity flag | Step marked `reviewAmbiguity: true` not yet resolved by a reviewer |

**Native QA checklist (per step):** grammatical; natural (would a native say it?); single correct form per stale token given the card; all natural word orders for the slot listed in `acceptedOrders`; gloss accurate; explainer applies.

### 12.7 Handling multiple correct answers

- **Form ambiguity:** forbidden — the author must make the card specific enough (e.g. specify the slot) that each token has exactly one correct form.
- **Order ambiguity:** allowed — list all natural orders in `acceptedOrders`. If one is stylistically marked, accept it and show an info line: *"Also natural: …"*.
- **User reports** of "my answer should also be correct" are reviewed weekly; accepted variants ship in the next pack version.

### 12.8 Rule explainers (`rules.json` excerpt)

```json
{
  "rules": [
    {
      "id": "prep.dative",
      "category": "cases",
      "cefr": "A2",
      "name": { "en": "Dative after mit, bei, von, zu, nach, aus" },
      "prerequisites": ["article.def.nom"],
      "explainer": {
        "en": "These prepositions always take the dative case. The article or possessive changes: meine → meiner (fem.), mein → meinem (masc./neut.)."
      },
      "feedbackTemplate": { "en": "After **{prep}**, use the dative: **{correct}**." },
      "table": [["", "masc.", "fem.", "neut.", "plural"], ["mein", "meinem", "meiner", "meinem", "meinen"]]
    }
  ]
}
```

---

## 13. Technical Architecture

### 13.1 Stack

| Layer | Choice |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI, Observation (`@Observable`) |
| Persistence | SwiftData (local, source of truth) |
| Minimum iOS | iOS 17 |
| Audio | AVFoundation (`AVSpeechSynthesizer`) |
| Purchases | StoreKit 2 |
| Notifications | UserNotifications (local only) |
| Backend SDKs | Firebase Apple SDK via SPM: Auth, Firestore, Remote Config, Analytics, Crashlytics, App Check |
| Tooling | Xcode, SPM, `ripplec` content compiler (CLI), Firebase CLI for Hosting deploys |

### 13.2 Module structure (SPM packages)

```
RippleApp (app target)
├── RippleEngine        Pure Swift. Chain/step model, state machine, validation,
│                       distractor selection, Peel derivation. No UI, no I/O.
│                       Target: 100% unit-test coverage of validation paths.
├── LearningModel       RuleState updates, unlock graph, chain scheduler, placement.
│                       Pure, deterministic, injectable clock.
├── ContentKit          Pack decoding, manifest/unit download, SHA-256 verification,
│                       atomic pack swap, bundled baseline pack.
├── PersistenceKit      SwiftData models + repositories.
├── SyncKit             `ProgressSyncing` protocol; FirestoreProgressSync implementation;
│                       no-op implementation when signed out.
├── AudioKit            TTS wrapper, voice selection, IPA overrides.
├── StoreKitKit         Products, entitlements, on-device transaction verification.
├── AnalyticsKit        Event protocol; Firebase implementation; respects opt-out.
└── DesignSystem        Tokens, chip/card components, animations, haptics.
```

Firebase is hidden behind protocols so the app works, and tests run, without Firebase.

### 13.3 Local data model (SwiftData)

```swift
@Model final class RuleStateRecord {
    @Attribute(.unique) var key: String      // "\(packId)|\(ruleId)"
    var packId: String
    var ruleId: String
    var strength: Double
    var intervalDays: Double
    var dueDate: Date
    var attempts: Int
    var firstTryCorrect: Int
    var lastSeen: Date?
    var unlocked: Bool
}

@Model final class ChainRecord {
    var packId: String
    var chainId: String
    var mode: String                  // "forward" | "peel"
    var completedAt: Date
    var firstTryRate: Double
    var durationSeconds: Int
}

@Model final class StepAttemptRecord {   // kept 90 days, for Rule Detail history
    var chainId: String
    var stepIndex: Int
    var hintLevel: Int
    var firstTryCorrect: Bool
    var attempts: Int
    var ruleIds: [String]
    var at: Date
}

@Model final class StreakDay {
    @Attribute(.unique) var day: String   // "yyyy-MM-dd" in user's calendar
    var chainsCompleted: Int
    var usedFreeze: Bool
}

@Model final class PackState {
    @Attribute(.unique) var packId: String
    var installedVersion: Int
    var installedUnits: [String: String]  // unitId → sha256
    var lastManifestCheck: Date?
}
```

User settings live in `UserDefaults` (small, synchronous).

### 13.4 Content update flow

```
App launch / foreground (max once per 12 h):
 1. Remote Config fetch (cached; minimumFetchInterval = 12 h)
 2. If rc.content_version_<pack> > PackState.installedVersion:
      a. GET /content/manifest.json
      b. GET index.json (+ rules.json, lexicon.json if hashes changed)
      c. For each unit whose hash changed: GET units/<unit>.<hash>.json
      d. Verify SHA-256 of every file
      e. Write to a staging directory → atomic rename to active
      f. Keep previous version for one rollback
 3. On any failure: keep current pack; retry next window. Never blocks the UI.
```

Units are immutable (hash in filename) → `Cache-Control: immutable`, and URLSession's cache prevents re-downloads.

### 13.5 Sync design (optional, signed-in users only)

- **Local-first:** SwiftData is the source of truth. Sync is a background merge.
- **When:** at session end, on app background (debounced, ≥ 10 min apart), and on sign-in.
- **How:** Firestore transaction on `users/{uid}/progress/{packId}`: read remote → merge → write. 1 read + 1 write per sync.
- **Merge rules (deterministic, conflict-free):**
  - Rule states: per rule, keep the record with the later `lastSeen`.
  - Completed chains: union (keyed by `chainId` + `completedAt`).
  - Streak days: union; `chainsCompleted` = max per day.
- Step attempts are **not** synced (local history only) to keep documents small and writes low.

### 13.6 Performance budgets

| Metric | Budget |
|---|---|
| Cold start to Today screen | < 1.5 s (iPhone 12) |
| Chain load | < 50 ms (from local pack) |
| Ripple animation | 60/120 fps, no dropped frames on iPhone 11+ |
| App binary (incl. baseline pack) | < 40 MB |
| Pack (de-en, all units, compressed transfer) | < 400 KB |
| Memory in chain player | < 120 MB |

---

## 14. Firebase (Spark) Design & Capacity Budget

### 14.1 Service usage

| Firebase service | Used for | Spark status (verified Nov 2026) |
|---|---|---|
| **Hosting** | Static content packs (manifest, index, units) via CDN | Included: 10 GB storage, 360 MB/day transfer |
| **Remote Config** | Content version keys, feature flags, free-tier limits, kill switches | Included: up to 100,000 fetch requests/day on Spark (new pricing from 1 Sep 2026) |
| **Cloud Firestore** | Optional progress sync; content reports | Included: 1 GiB stored, ~50K reads, 20K writes, 20K deletes per day (verify on pricing page) |
| **Authentication** | Sign in with Apple (sync users), anonymous auth (reports only) | Included (verify whether the project uses legacy Auth or Identity Platform, which has its own Spark limits) |
| **Analytics** | Product & learning analytics | Free |
| **Crashlytics** | Crash reporting | Free |
| **App Check** (App Attest) | Protect Firestore and Hosting-adjacent APIs from abuse | Free |
| ~~Cloud Storage~~ | **Not used** | Since 3 Feb 2026 Cloud Storage requires the Blaze plan → content is served from Hosting instead |
| ~~Cloud Functions~~ | **Not used** | Requires Blaze; all logic is client-side |

### 14.2 Why content lives on Hosting (not Firestore or Remote Config)

- **Firestore** would bill every chain as a document read: 240 chains × N users quickly exhausts 50K reads/day.
- **Remote Config** is designed for small key–value parameters, not megabytes of content.
- **Cloud Storage** is unavailable on Spark (see above).
- **Hosting** serves static, cacheable, compressed files from a CDN — exactly what content packs are.

### 14.3 `firebase.json` (Hosting)

```json
{
  "hosting": {
    "public": "public",
    "ignore": ["firebase.json", "**/.*"],
    "headers": [
      {
        "source": "/content/**/units/**",
        "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }]
      },
      {
        "source": "/content/*/v*/*.json",
        "headers": [{ "key": "Cache-Control", "value": "public, max-age=86400" }]
      },
      {
        "source": "/content/manifest.json",
        "headers": [{ "key": "Cache-Control", "value": "public, max-age=300" }]
      }
    ]
  }
}
```

Versioned paths (`/v12/`) are never overwritten, so long caching is safe.

### 14.4 Remote Config parameters

| Key | Type | Default | Purpose |
|---|---|---|---|
| `content_version_de_en` | Number | 1 | Triggers manifest check when greater than installed |
| `min_supported_app_version` | String | "1.0.0" | Soft/hard update prompt |
| `free_daily_chains` | Number | 3 | Free-tier daily chain limit |
| `paywall_enabled` | Boolean | true | Kill switch for paywall experiments |
| `peel_free` | Boolean | false | Whether Peel is free (experiment) |
| `scheduler_weights` | JSON | see §7.5 | Tune scheduler without app update |
| `maintenance_message` | String | "" | Optional banner text |
| `sync_enabled` | Boolean | true | Kill switch for sync if quotas are threatened |

`minimumFetchInterval` = 12 h. In-app defaults are bundled (`RemoteConfigDefaults.plist`), so the app works if fetching fails.

### 14.5 Firestore data model

```
users/{uid}
  createdAt: timestamp
  updatedAt: timestamp
  uiLanguage: "en"
  schemaVersion: 1

users/{uid}/progress/{packId}          // e.g. "de-en", one doc per pack
  schemaVersion: 1
  updatedAt: timestamp
  rules:  { "<ruleId>": { s: 0.62, i: 4.8, due: timestamp, a: 17, c: 12, ls: timestamp, u: true }, ... }
  chains: { "<chainId>": { last: timestamp, n: 2, r: 0.86 }, ... }
  streak: { days: { "2026-11-07": 3, ... }, freezes: ["2026-11-02"] }

reports/{autoId}
  uid, chainId, step, packVersion, reason, note, createdAt
```

Document size estimate (heavy user, 1 year): 50 rules × ~90 B + 240 chains × ~60 B + 365 days × ~20 B ≈ 27 KB — far below Firestore's 1 MiB document limit. Streak days older than 400 days are compacted into a count.

### 14.6 Security rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }
    function isOwner(uid) { return signedIn() && request.auth.uid == uid; }

    match /users/{uid} {
      allow read, delete: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && request.resource.data.keys().hasOnly(['createdAt', 'updatedAt', 'uiLanguage', 'schemaVersion'])
        && request.resource.data.uiLanguage is string
        && request.resource.data.uiLanguage.size() <= 8;

      match /progress/{packId} {
        allow read, delete: if isOwner(uid);
        allow create, update: if isOwner(uid)
          && packId.matches('^[a-z]{2}-[a-z]{2}$')
          && request.resource.data.keys().hasOnly(['schemaVersion', 'updatedAt', 'rules', 'chains', 'streak'])
          && request.resource.data.rules is map
          && request.resource.data.chains is map
          && request.resource.data.streak is map;
      }
    }

    match /reports/{reportId} {
      allow create: if signedIn()
        && request.resource.data.keys().hasOnly(['uid', 'chainId', 'step', 'packVersion', 'reason', 'note', 'createdAt'])
        && request.resource.data.uid == request.auth.uid
        && request.resource.data.createdAt == request.time
        && request.resource.data.chainId is string && request.resource.data.chainId.size() <= 64
        && request.resource.data.step is int
        && request.resource.data.reason in ['other_answer_ok', 'answer_wrong', 'bad_translation', 'audio', 'other']
        && request.resource.data.note is string && request.resource.data.note.size() <= 500;
      allow read, update, delete: if false;   // reviewed only in the Firebase console
    }
  }
}
```

App Check enforcement is enabled for Firestore. Reports use lazily created **anonymous auth** (only when the user actually sends a report) for users who are not signed in with Apple.

**Firestore location:** `eur3` (Europe multi-region) or a single EU region, chosen once at project creation, to keep EU user data in the EU.

### 14.7 Capacity budget (what Spark supports)

Assumptions: average daily active user (DAU) opens the app 1.5×/day; 25% of DAU have sync enabled; content updates every 2 weeks.

| Resource | Spark limit | Usage per DAU per day | Supported DAU |
|---|---|---|---|
| Remote Config fetches | 100,000/day | ≤ 2 (12 h interval) | ~50,000 |
| Hosting transfer | 360 MB/day | Update day: index + rules + lexicon + ~2 changed units ≈ 60 KB, spread over 14 days ≈ 4.5 KB/day avg; manifest checks ≈ 1 KB | ~60,000 on average; **peak risk on release day** (see mitigation) |
| Firestore writes | 20,000/day | 25% × 2 syncs = 0.5 | ~40,000 |
| Firestore reads | 50,000/day | 25% × 2 syncs = 0.5 | ~100,000 |
| Firestore storage | 1 GiB | ~30 KB per sync user | ~35,000 sync users |

**Release-day peak:** if 20,000 users all fetch a 60 KB update on the same day, that is ~1.2 GB — over the 360 MB daily limit. Mitigations, all built in:
1. **Staggered rollout:** the client only acts on a new `content_version` when `hash(installId) % 7 == dayOfWeek` or after 7 days — spreads downloads over a week.
2. **Unit granularity:** only changed units are downloaded.
3. **Graceful failure:** if Hosting quota is exhausted, downloads fail silently and retry the next day; the bundled/installed pack keeps working.
4. **Upgrade path:** at ~10,000 DAU, move to Blaze with a budget alert (Blaze keeps the same free quotas; overage is pennies at this scale).

---

## 15. Monetization

### 15.1 Model: freemium

| | Free | Pro |
|---|---|---|
| Daily chains | 3 (one full "Today" set) | Unlimited |
| Rule Map, Rule Detail, Gallery | ✓ | ✓ |
| Practice a specific rule | 1 per day | Unlimited |
| Peel mode | — | ✓ |
| All CEFR bands | ✓ (content gating by level only) | ✓ |
| Future target languages | Preview chains | Full |
| Ads | None | None |

### 15.2 Products (StoreKit 2)

| Product ID | Type | Price hypothesis |
|---|---|---|
| `app.ripple.pro.monthly` | Auto-renewable | $5.99 |
| `app.ripple.pro.yearly` | Auto-renewable, 7-day free trial | $39.99 |
| `app.ripple.pro.lifetime` | Non-consumable | $79.99 |

Prices are hypotheses to test; regional pricing via App Store Connect.

### 15.3 Entitlement handling (no server)

- StoreKit 2 transactions are JWS-signed and verified on-device (`VerificationResult.verified`).
- Entitlement = any verified, non-revoked, non-expired Pro transaction in `Transaction.currentEntitlements`.
- Listen to `Transaction.updates` at launch; cache entitlement in `UserDefaults` for offline UI, re-validated on each launch.
- "Restore purchases" calls `AppStore.sync()`.
- No receipt server, no Firebase involvement.

### 15.4 Paywall rules
- Never in the first session; never interrupting a chain in progress.
- Soft, dismissible, shown at natural stopping points (§9.13).
- Clear trial terms and cancellation info (App Review guideline compliance).

---

## 16. Privacy, Security & Compliance

### 16.1 Data inventory

| Data | Where | Purpose | Linked to user? |
|---|---|---|---|
| Learning progress | Device (always); Firestore (if sync on) | Core function, sync | Yes, if sync on |
| Apple ID identifier (via Sign in with Apple) | Firebase Auth | Sync | Yes |
| Email (Apple relay or real, if shared) | Firebase Auth | Account identification only; no marketing | Yes |
| Content reports + note | Firestore | Content quality | Yes (uid) |
| Analytics events | Google Analytics for Firebase | Product improvement | No IDFA; app-instance ID |
| Crash logs | Crashlytics | Stability | No |
| Purchases | Apple | Entitlement | Handled by Apple |

**Not collected:** contacts, location, microphone, photos, IDFA (no App Tracking Transparency prompt needed because no cross-app tracking occurs).

### 16.2 User controls
- **No account required.** The full app works without signing in.
- **Analytics opt-out** in Settings (`Analytics.setAnalyticsCollectionEnabled(false)`); in the EU, analytics consent is asked once on first launch (consent mode).
- **Account deletion in-app** (App Store requirement): deletes `users/{uid}/progress/*`, `users/{uid}`, then the Firebase Auth user; revokes the Sign in with Apple token via Firebase (`Auth.auth().revokeToken(withAuthorizationCode:)`, which requires the Apple provider to be fully configured in the Firebase console). Local data deletion offered separately ("Reset progress on this device").
- **Data export:** Settings → "Export my progress" produces a JSON file via the share sheet (local, no server).

### 16.3 Compliance checklist
- GDPR: lawful basis = contract (core function) / consent (analytics); EU data location for Firestore; Firebase data processing terms accepted; privacy policy lists Google as processor.
- Privacy policy and support page: added to the developer's existing shared privacy-policy website.
- App Store privacy "nutrition label" filled per §16.1.
- Age rating 4+; not in the Kids category; not directed at children.
- Licenses: if paradigm data is derived from open datasets (e.g. Wiktionary-based morphology), verify the license (some are CC BY-SA) and include attribution in About.

### 16.4 Security
- Firestore rules (§14.6) + App Check (App Attest; DeviceCheck fallback).
- Content integrity via SHA-256 in the manifest; HTTPS only.
- No secrets in the app beyond the standard Firebase config (which is not secret; protection is rules + App Check).

---

## 17. Analytics & Success Metrics

### 17.1 North-star metric
**Weekly first-try steps at L3** per active learner: counts correct, unaided production of dependencies — directly measures what the app is for.

### 17.2 Funnel & retention targets (hypotheses for launch)

| Metric | Target |
|---|---|
| Demo chain completion (onboarding) | ≥ 85% |
| First full chain completed in session 1 | ≥ 70% |
| D1 retention | ≥ 40% |
| D7 retention | ≥ 20% |
| D30 retention | ≥ 10% |
| Median session length | 4–7 min |
| Free → Pro conversion (30 days) | ≥ 3% |

### 17.3 Learning-efficacy metrics
- **Transfer accuracy:** first-try accuracy on a rule the *first* time it appears in a new chain, tracked across exposures (should rise).
- **Hint-level progression:** median exposures for a rule to move L1 → L2 → L3.
- **Retention of mastery:** first-try accuracy on mastered rules after ≥ 14 days without practice.

### 17.4 Content-health metrics
- Per-step first-try error rate; steps with > 70% errors at their intended level are flagged for review.
- Report rate per step; any step with ≥ 3 "my answer should also be correct" reports → review.

### 17.5 Event schema (Google Analytics for Firebase)

| Event | Parameters |
|---|---|
| `onboarding_step` | `step` |
| `demo_completed` | `duration_s` |
| `placement_completed` | `band`, `accuracy` |
| `session_start` | `chains_planned` |
| `chain_start` | `chain_id`, `mode` (forward/peel), `pack_version` |
| `step_result` | `chain_id`, `step`, `hint_level`, `first_try` (0/1), `attempts`, `duration_ms`, `no_change` (0/1) |
| `chain_complete` | `chain_id`, `first_try_rate`, `duration_s`, `words_gained` |
| `rule_level_up` | `rule_id`, `new_level` |
| `paywall_view` | `trigger` |
| `purchase_complete` | `product_id` |
| `content_report` | `chain_id`, `step`, `reason` |
| `sync_enabled` | — |

Register `chain_id`, `rule_id`, `hint_level`, `step` as custom dimensions. Deeper per-step analysis can use the BigQuery sandbox (available on Spark) if needed.

---

## 18. Quality Assurance

| Layer | Approach |
|---|---|
| RippleEngine | Unit tests: every validation branch, every card type, Peel derivation, capitalization, accepted-order matching, distractor selection determinism |
| LearningModel | Unit tests with an injected clock: update math, unlocking, scheduler determinism (golden tests for "Today" sets) |
| Content | `ripplec` lint in CI; snapshot test that every chain in the pack plays from base to final using its own target answers (auto-solve test) |
| UI | Snapshot tests (light/dark, Dynamic Type sizes), UI tests for the tap-only path through a chain |
| Accessibility | Manual VoiceOver run of a full chain each release; Accessibility Inspector audit |
| Sync | Tests for merge rules with conflicting fixtures; offline/online transitions |
| Purchases | StoreKit configuration file + StoreKit Test in Xcode; sandbox testing |
| Beta | TestFlight: internal (content authors) → external (50–200 learners) with in-app report button |

**Release checklist:** content pack version bumped; Remote Config defaults updated; Firestore rules deployed and tested in the emulator; privacy label unchanged or updated; crash-free sessions ≥ 99.5% in beta.

---

## 19. Roadmap & MVP Scope

### 19.1 MVP (v1.0) — in scope
- German for English speakers, A1–B1, 240 chains, ~50 rules.
- Card types: SUBSTITUTE, INSERT, DELETE, TRANSFORM.
- Hint levels L1–L3, scheduler, placement, Rule Map, Rule Detail, Gallery, Chain/Session summaries.
- On-device TTS audio.
- Offline-first; Hosting content updates; Remote Config.
- Optional Sign in with Apple + Firestore sync.
- Freemium with StoreKit 2 (Peel = Pro).
- Full accessibility path (tap-only, VoiceOver).
- UI languages: English.

### 19.2 Out of scope for MVP
- MERGE cards, listening-only mode, speaking/recording, leaderboards, social features, Android, iPad-optimized layout (iPad runs the iPhone layout scaled), Apple Watch, widgets, pre-recorded audio, additional languages.

### 19.3 Phases (solo developer + part-time native reviewer)

| Phase | Duration | Deliverables | Exit criteria |
|---|---|---|---|
| **0. Validate** | 2 weeks | Clickable prototype (SwiftUI, hard-coded) with 10 chains; 5–8 hallway tests | ≥ 4 of 5 testers understand the mechanic within 30 s unaided; testers say they'd use it again |
| **1. Engine & player** | 5–6 weeks | RippleEngine, chain player, `ripplec` compiler + lint, 40 chains | Auto-solve test passes; internal TestFlight |
| **2. Learning layer** | 4 weeks | LearningModel, onboarding, placement, Rule Map, Gallery, summaries; 120 chains | 2-week internal use shows rules leveling up |
| **3. Backend & polish** | 4 weeks | Hosting delivery, Remote Config, sync, StoreKit, accessibility, analytics; 240 chains | External beta; crash-free ≥ 99.5%; D7 ≥ 15% in beta |
| **Launch** | — | App Store release | — |

### 19.4 After launch
- **v1.1:** Russian UI + Russian glosses (pack `de-ru`); Home Screen widget ("Today's chains", "Longest sentence"); more themes.
- **v1.2:** Spanish pack (`es-en`), then French.
- **v2.0:** MERGE cards; **Listening Ripple** (hear the changed sentence and identify what rippled — same content, new skill); optional pre-recorded native audio; story chains (several chains forming one narrative).

---

## 20. Risks, Open Questions & Decisions Log

### 20.1 Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Content production is slower/costlier than planned | High | High | Start with 240 chains; unit-based publishing; strong compiler lint reduces review time; prioritize rules with highest learner error rates |
| Content errors damage trust | Medium | High | Native sign-off per unit; report button; weekly review; fast pack updates without app release |
| Mechanic feels repetitive after weeks | Medium | High | Varied card types, themes, no-change steps, Peel, rule-targeted practice; v2 Listening Ripple |
| Too hard for beginners | Medium | Medium | Demo chain, L1 guidance, first-encounter explainers, A1 chains with 1 ripple per step |
| Ambiguous answers / "my answer is also right" | Medium | Medium | `acceptedOrders`, strict single-form rule, reports → next pack |
| Low-morphology languages (e.g. English as target) have weak ripples | High (if chosen) | Medium | Launch with morphology-rich targets (German, Spanish, French, Polish) |
| TTS mispronunciation | Medium | Low | Per-token phonetic overrides; QA listening pass; v2 recorded audio |
| Spark quota exhaustion on growth | Low (early) | Medium | Staggered content rollout, kill switches, Blaze with budget alerts at ~10K DAU |
| Large competitor copies the mechanic | Medium | Medium | Move fast; depth of content and rule model; brand around "grammar you can feel" |
| Name/trademark conflict | Medium | Medium | Trademark & App Store name search before branding work |

### 20.2 Open questions
1. **Final name.** "Ripple" is a working title and conflicts with well-known brands; candidates to evaluate: *Ripple Grammar*, *Wavelet*, *Knock-on*, *Domino Sentences*.
2. **Standalone or combined?** Ship as its own app, or as the core mode of the Обход / Detour language-learning concept?
3. **First pair:** English → German (bigger market) vs. Russian → German (developer's native language eases content QA).
4. **Free limit:** 3 chains/day vs. 5; test via Remote Config.
5. **Peel as Pro vs. free** (it's cheap to produce and good for retention).
6. **Native reviewer sourcing:** freelance per unit vs. revenue share.

### 20.3 Decisions log

| # | Decision | Rationale | Alternatives rejected |
|---|---|---|---|
| D1 | No runtime AI | Cost, reliability, offline, trust | LLM grading (cost, nondeterminism) |
| D2 | Content on Firebase Hosting | Spark-compatible, CDN, cacheable | Cloud Storage (Blaze-only since Feb 2026), Firestore (read costs), Remote Config (not for payloads) |
| D3 | Local-first with optional sync | Zero-friction start; low Firestore usage | Mandatory account |
| D4 | StoreKit 2 on-device verification | No server needed | Server receipt validation (needs Functions/Blaze) |
| D5 | On-device TTS | Free, offline | Recorded audio (cost, size) — deferred to v2 |
| D6 | Rule tag as unit of mastery | Trains transfer across sentences | Sentence-level SRS (memorizes sentences) |
| D7 | Firestore over CloudKit for sync | Developer's chosen stack; cross-platform later | CloudKit (viable fallback if Firebase limits become an issue) |

---

## 21. Appendices

### Appendix A — German rule taxonomy (MVP, A1–B1)

**Verbs**
| Rule ID | Name | CEFR |
|---|---|---|
| `verb.present.regular` | Present tense endings | A1 |
| `verb.present.stem-change` | Stem-changing verbs (e→i, a→ä) | A1 |
| `verb.present.sein-haben` | *sein* / *haben* present | A1 |
| `verb.modal.present` | Modal verbs present | A1 |
| `verb.separable.present` | Separable verbs | A1 |
| `verb.imperative` | Imperative (du/ihr/Sie) | A1 |
| `verb.perfekt.haben` | Perfekt with *haben* | A1 |
| `verb.perfekt.sein` | Perfekt with *sein* | A2 |
| `verb.participle.regular` | Regular participles (ge-…-t) | A1 |
| `verb.participle.irregular` | Irregular participles (ge-…-en) | A2 |
| `verb.praeteritum.sein-haben` | Präteritum of *sein* / *haben* | A2 |
| `verb.praeteritum.modal` | Präteritum of modals | A2 |
| `verb.future.werden` | Future with *werden* | B1 |
| `verb.reflexive` | Reflexive verbs | A2 |
| `verb.konjunktiv2.wuerde` | *würde* + infinitive | B1 |

**Word order**
| Rule ID | Name | CEFR |
|---|---|---|
| `order.v2-inversion` | Verb second after a fronted element | A1 |
| `order.question.yes-no` | Yes/no questions | A1 |
| `order.question.w` | W-questions | A1 |
| `order.bracket.modal` | Modal + infinitive at the end | A1 |
| `order.bracket.perfekt` | Auxiliary + participle at the end | A1 |
| `order.separable-prefix-end` | Separable prefix at the end | A1 |
| `order.verb-final.subordinate` | Verb-final in subordinate clauses | A2 |
| `order.negation.nicht` | Position of *nicht* | A2 |
| `order.time-manner-place` | TeKaMoLo order | B1 |

**Articles, nouns & adjectives**
| Rule ID | Name | CEFR |
|---|---|---|
| `noun.gender` | Gender awareness (incl. no-change steps) | A1 |
| `noun.plural` | Plural forms | A1 |
| `article.def.nom` | Definite article nominative | A1 |
| `article.def.acc` | Definite article accusative | A1 |
| `article.def.dat` | Definite article dative | A2 |
| `article.indef.acc` | Indefinite article accusative | A1 |
| `article.kein` | *kein* forms | A1 |
| `noun.dative-plural-n` | Dative plural *-n* | A2 |
| `adj.decl.weak` | Adjective endings after definite article | A2 |
| `adj.decl.mixed` | Adjective endings after *ein*-words | A2 |
| `adj.decl.strong` | Adjective endings without article | B1 |
| `adj.comparative` | Comparative / superlative | A2 |

**Cases, prepositions & pronouns**
| Rule ID | Name | CEFR |
|---|---|---|
| `prep.dative` | *mit, bei, von, zu, nach, aus* + dative | A2 |
| `prep.accusative` | *für, ohne, durch, gegen, um* + accusative | A2 |
| `prep.two-way` | *in, auf, an …* location vs. direction | A2 |
| `prep.contraction` | *im, am, zum, zur, ins* | A2 |
| `possessive.acc` | Possessives accusative | A1 |
| `possessive.dat` | Possessives dative | A2 |
| `pronoun.personal.acc` | Personal pronouns accusative | A1 |
| `pronoun.personal.dat` | Personal pronouns dative | A2 |

**Clauses & negation**
| Rule ID | Name | CEFR |
|---|---|---|
| `conj.coordinating` | *und, aber, oder, denn* (no word-order change) | A1 |
| `conj.weil` | *weil* | A2 |
| `conj.dass` | *dass* | A2 |
| `conj.wenn` | *wenn* | A2 |
| `conj.obwohl` | *obwohl* | B1 |
| `relative.clause` | Relative clauses | B1 |
| `neg.kein-vs-nicht` | *kein* vs. *nicht* | A1 |

### Appendix B — Engine state types (sketch)

```swift
enum CardType: String, Codable { case substitute = "SUBSTITUTE", insert = "INSERT", delete = "DELETE", transform = "TRANSFORM", merge = "MERGE" }

enum HintLevel: Int, Codable { case guided = 1, counted = 2, free = 3 }

struct TokenState: Identifiable, Equatable {
    let id: String
    var text: String
    var isSpawnedUnplaced: Bool
    var markedWrong: Bool
}

enum StepPhase: Equatable {
    case cardReady
    case rippled
    case fixing
    case checking
    case correct
    case incorrect(attempt: Int, errors: [TokenError])
    case revealed
}

struct StepState {
    var phase: StepPhase
    var tokens: [TokenState]          // current order
    var hintLevel: HintLevel
    var attempts: Int
    var tokenOrder: [String] { tokens.filter { !$0.isSpawnedUnplaced }.map(\.id) }
    func token(id: String) -> TokenState? { tokens.first { $0.id == id } }
}
```

### Appendix C — Content source format (author-facing YAML, compiles to §12.4)

```yaml
chain: de.a2.cafe.003
cefr: A2
theme: cafe
title: { en: Morning tea }
base: "ich trinke Kaffee"            # tokenized by spaces; lemmas from lexicon
gloss: { en: I drink coffee. }
steps:
  - card: { type: SUBSTITUTE, target: ich, to: wir, gloss: { en: I → we } }
    result: "wir trinken Kaffee"
    rules: { trinken: [verb.present.regular] }
    gloss: { en: We drink coffee. }
  - card: { type: INSERT, words: "ein groß", slot: "before Kaffee", gloss: { en: + a · big } }
    result: "wir trinken einen großen Kaffee"
    rules: { einen: [article.indef.acc], großen: [adj.decl.mixed] }
    gloss: { en: We drink a big coffee. }
  - card: { type: SUBSTITUTE, target: Kaffee, to: Tee, gloss: { en: coffee → tea } }
    result: "wir trinken einen großen Tee"
    nochange_note: { en: "Tee is masculine, just like Kaffee — nothing else changes." }
    rules: { _step: [noun.gender] }
    gloss: { en: We drink a big tea. }
```

The compiler assigns token IDs by aligning lemmas between consecutive results, derives fixes and moves, and fails if alignment is ambiguous (author then pins IDs manually).

### Appendix D — Spark limits reference (verify before launch)

| Item | Value used in this document | Source |
|---|---|---|
| Hosting storage / transfer | 10 GB / 360 MB per day | firebase.google.com/pricing |
| Remote Config | 100,000 fetch requests/day on Spark (from 1 Sep 2026) | firebase.google.com/docs/remote-config/pricing |
| Cloud Storage | Requires Blaze since 3 Feb 2026 | firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024 |
| Cloud Firestore | 1 GiB; ~50K reads, 20K writes, 20K deletes/day | firebase.google.com/pricing (re-check) |
| Cloud Functions | Not available on Spark | firebase.google.com/pricing |

---

*End of document.*
