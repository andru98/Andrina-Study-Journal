# Storytelling with Data — Chapter 1: The Importance of Context

> **Weekly Revision Note:** Read this every Sunday during your weekly review. These are not just theory notes — every concept here applies directly to how you present your DE portfolio projects and trading analysis to recruiters and interviewers.

---

## 1. The Presentation ↔ Document Continuum

### What it means
There is a spectrum between two extremes of communication:

```
LIVE PRESENTATION  ←————————————→  STANDALONE DOCUMENT
(you are there)                      (you are NOT there)
```

**Live Presentation (sparse):**
You are in the room explaining. Your slides only need key points or a chart — *you* are the context. The audience can ask questions anytime.

**Standalone Document (dense):**
You send a report and walk away. The reader is alone. Everything — labels, context, explanation — must be written inside the document itself because nobody is there to clarify.

### Why this matters for you
When you present your **Spotify Pipeline** or **Airline Revenue project** to a hiring panel, you are in live presentation mode. But when you send your GitHub README or portfolio PDF to a recruiter who reads it alone at midnight — that is standalone document mode. They are completely different design decisions.

---

## 2. The Slideument Problem

### What it means
**Slideument = Slide + Document** — one product trying to do both jobs at once.

This happens in real life all the time:
- You build a chart for your team meeting → your manager asks you to email it to 5 people who weren't there
- Now the same slide must work as a presentation AND a standalone explanation

### Why it fails
| What the audience needs | Live Presentation | Standalone Doc |
|------------------------|------------------|----------------|
| Labels and context | Minimal — you explain verbally | Detailed — written into the slide |
| Explanatory text | Little | A lot |
| Chart annotations | Optional | Required |

One product cannot perfectly satisfy both. It is always a compromise.

### Real example
You analyze your **trading journal** and build a chart showing emotion vs. R:R. You present it to your trading mentor — he asks questions, you explain the FOMO pattern verbally. He then says *"send this to our team."* Now those people stare at the same chart with no context. That single chart trying to do both jobs = a slideument.

---

## 3. The WHO / WHAT / HOW Framework

> **Core rule:** Answer these three questions BEFORE touching any chart, slide, or dashboard. The visualization comes last, not first.

### WHO — Who is your audience?

The same data tells a completely different story depending on who is in the room. Always identify ONE specific audience and design only for them.

**Example — same trading data, different audiences:**

| Audience | What they care about |
|----------|---------------------|
| Trading mentor | Setup quality, entry discipline |
| SMB Capital prop desk | R:R consistency, emotional control, drawdown recovery |
| Your trading buddy | Specific entry/exit setups |
| Risk manager | Max loss, position sizing, exposure |

If you design for everyone → you resonate with no one.

### WHAT — What do you need them to know or do?

Once WHO is clear, WHAT becomes obvious. One clear message + one specific ask.

**Example for SMB Capital:**
> *"My VWAP reclaim strategy has a 68% win rate with 2.1 average R:R across 90+ journaled trades. I am requesting formal evaluation."*

### HOW — What data proves your point?

Pick only the evidence that supports your WHAT for your specific WHO. Cut everything else.

**For SMB Capital, show:**
- Win rate trend over time
- Average R:R distribution
- Emotion vs. outcome correlation
- Plan adherence improving over time

**Do NOT show:**
- Raw timestamp logs
- Your biochemistry background
- Python backtest code

### Quick Reference Card

```
WHO  → One specific audience. Not everyone.
WHAT → One clear message + one specific ask.
HOW  → Only data that proves WHAT to WHO.
```

---

## 4. The 3-Minute Story

### What it means
If someone gave you only 3 minutes — your boss in a hallway, a recruiter in an elevator, a panel that just cut your 30-minute slot to 10 — what would you say?

The goal: know your story so well that you do not need your slides to carry you.

### Structure to follow
```
1. Here is the PROBLEM or QUESTION we started with
2. Here is what we DID
3. Here is what we FOUND
4. Here is what we RECOMMEND
```

### Example — Trading journal analysis presented to SMB Capital

> *"I have been journaling every trade for 6+ months — 90+ entries with 24 data points each, including emotion, setup type, R:R, and plan adherence. I noticed I kept having losing weeks despite having winning setups, so I analyzed the journal data in Python. I grouped trades by the Emotion field I log before every entry. Trades where I logged Calm or Confident had an average R:R of +1.8. Trades where I logged Revenge or FOMO had an average R:R of -0.6. Emotional state before entry turned out to be my single biggest performance driver — bigger than setup type or time of day. Based on this, I implemented a hard rule: if I log Revenge or FOMO, I do not trade that day. I am also building an ML model to predict trade outcome using emotion, setup type, and market condition as features."*

That is your 3-minute story. No slides needed. Any person in any context can follow it.

### Example — Spotify Pipeline presented to a recruiter

> *"Spotify's public API has rich listening data but it has never been structured for analytics. I built an end-to-end pipeline that pulls raw track, artist, and listening data, lands it in a Bronze layer, cleans and deduplicates it in Silver, and aggregates business-ready tables in Gold. I used Airflow for orchestration and dbt for transformations. The result is a reliable, query-ready dataset that powers recommendation analysis and listening trend dashboards. This project demonstrates my ability to independently architect and build a production-grade pipeline."*

---

## 5. The Big Idea

### What it means
Boil your entire story down to **one single sentence**. This is the hardest part — being concise takes more thinking, not less.

> *"I would have written a shorter letter, but I did not have the time."* — Blaise Pascal

### Three requirements (all three must be met)

| Requirement | What it means |
|-------------|--------------|
| Your unique point of view | What YOU believe — a position, not just a fact |
| What is at stake | Why should they care? What happens if ignored? |
| Complete sentence | Not a title. Not a bullet. A full sentence. |

### Examples

**Trading journal → SMB Capital:**
> *"My trading journal data proves I have a documented, improving edge with measurable emotional discipline — and I am ready to begin formal prop trader evaluation at SMB Capital."*

**Spotify Pipeline → recruiter:**
> *"This end-to-end Spotify pipeline demonstrates that I can independently architect, build, and orchestrate a production-ready data pipeline — making me a strong candidate for senior data engineering roles."*

**Airline Revenue project → Tempus or Flatiron recruiter:**
> *"By combining 2+ years of airline revenue management domain expertise with a modern lakehouse pipeline stack, this project proves I can translate deep business context into production-quality data engineering — exactly the differentiator healthcare analytics companies need."*

### How to check your Big Idea

```
✅ Does it state YOUR position clearly (not just a neutral fact)?
✅ Does it say what is at stake (career, funding, decision, outcome)?
✅ Is it a complete sentence (subject + verb + consequence)?

If all three → your Big Idea is ready.
If not       → rewrite until it passes all three.
```

---

## 6. The 7 Context Questions

> Run through all 7 of these BEFORE building any chart or slide. This is your pre-work checklist.

### Question 1: What background information is relevant or essential?

What context does your audience need before they can understand your point? What is the setup?

**Example — presenting trading analysis to SMB:**
- You have been trading 0DTE options for 6+ months
- You journal every trade with 24 columns of structured data
- You had a recurring revenge trading problem that you identified and fixed
- You are now in drawdown recovery with strict rules active

Without this context, a win rate percentage means nothing to them.

---

### Question 2: Who is the audience? What do we know about them?

Be specific. What do they value? What do they NOT care about?

**Example — SMB Capital prop desk:**
- They evaluate hundreds of traders per year
- They care deeply about: risk discipline, R:R consistency, emotional control, self-awareness
- They do NOT care about: your Python skills, your biochem degree, your backtest code
- They are specifically looking for traders who identify and fix their own weaknesses

Design everything around what THEY value, not what you think is impressive.

---

### Question 3: What biases might make them supportive OR resistant?

Every audience walks in with existing assumptions. Identify them in advance.

**Example — SMB Capital:**

| Supportive biases | Resistant biases |
|------------------|-----------------|
| They love structured journaling | They may doubt 90 trades is enough sample size |
| They respect data-driven self-analysis | They may see your drawdown weeks as a red flag |
| They reward traders who identify their own weaknesses | They may be skeptical of part-time traders |

**Your move:** Surface the resistance proactively. Do not hide the drawdown weeks — show them you identified the pattern AND fixed it. This flips the bias in your favor.

---

### Question 4: What data is available to strengthen your case? Is it familiar or new?

**Example — trading journal presentation:**

| Data point | Familiar to SMB? | How to handle |
|-----------|-----------------|---------------|
| Win rate % | Yes | Lead with it — builds credibility |
| Average R:R | Yes | Show trend improving over time |
| Emotion vs. R:R correlation | Possibly new | Walk them through it with your chart |
| Plan adherence % over time | New | Explain the column and what it measures |
| Drawdown recovery behavior | Yes | They care deeply — highlight it |

Lead with familiar metrics. Introduce your unique journal insights as your differentiator.

---

### Question 5: Where are the risks? What could weaken your case?

Find the holes before they do. Address them proactively.

**Example — trading journal presentation:**

| Risk | How to address it proactively |
|------|------------------------------|
| Only 90 trades — small sample | Show the improving trend line, not just the total |
| Had bad drawdown weeks | Here is exactly what caused it and the rules I built afterward |
| Still part-time | My DE study schedule sharpened my analytical discipline |
| No live prop trading experience | TradingView replay + structured journaling is my simulation environment |

If you surface the risk yourself → you control the narrative.
If they find it first → it looks like you were hiding it.

---

### Question 6: What would a successful outcome look like?

Define exactly what winning means BEFORE you build anything. Your entire presentation should be designed to get that specific outcome.

**Example:**
- Vague goal: "I want to impress them"
- Specific goal: "They invite me for formal evaluation or enroll me in SMB training"

Your closing line should not be: *"I hope this was interesting."*

It should be: *"I am targeting your formal evaluation process in Q1 — I would love to understand what readiness benchmarks matter most to you."*

One specific ask. One specific outcome.

---

### Question 7: If you had one sentence — what would you say?

This is your Big Idea test. If you cannot say it in one sentence, you do not know your point clearly enough yet.

**Example:**
> *"My trading journal data proves I have a documented, improving edge with measurable emotional discipline — and I am ready for formal prop trader evaluation at SMB Capital."*

---

## 7. The Master Checklist — Use Before Every Presentation

```
BEFORE BUILDING ANYTHING:
□ WHO    → Have I identified ONE specific audience?
□ WHAT   → Do I have one clear message + one specific ask?
□ HOW    → Have I selected only the data that proves WHAT to WHO?

BEFORE PRESENTING:
□ 3-MIN  → Can I say this out loud in 3 minutes without slides?
□ BIG IDEA → Does my one sentence have a POV + stakes + complete sentence?
□ 7 Qs   → Have I run through all 7 context questions?

IF ALL BOXES ARE CHECKED → start building your charts.
IF NOT → go back and clarify first.
```

---

## 8. How This Applies to Your Portfolio Projects

| Project | WHO | WHAT | Big Idea |
|---------|-----|------|----------|
| Spotify Pipeline | DE recruiter at Tempus/Flatiron | Prove pipeline-building ability | *"This pipeline proves I can independently architect and ship a production-ready data engineering solution."* |
| Airline Revenue Platform | Hiring manager who values domain + tech | Prove domain + engineering combo | *"My airline RM domain expertise combined with a modern lakehouse stack makes me a uniquely differentiated DE candidate."* |
| Healthcare Pipeline | Clinical data or biotech company | Prove biochemistry + engineering intersection | *"My biochemistry background plus agentic AI pipeline architecture positions me to solve problems most data engineers cannot even formulate."* |
| Trading Journal ML | SMB Capital or any DS/ML role | Prove real, personal, data-driven project | *"I built an ML model on 1 year of my own live trading data — the most real-world predictive modeling project any candidate in this room has done."* |

---

*Source: Storytelling with Data by Cole Nussbaumer Knaflic — Chapter 1*
*Notes by Anna Shrestha | Started May 2026*
*Next chapter: Choosing the Right Type of Visual*
