# Git & GitHub — Fundamentals

> Date: 28 Feb 2026 | Topics: What is Git · GitHub · First workflow · Branches · Common errors

---

## Table of Contents
1. [What is Git and Why It Exists](#1-what-is-git-and-why-it-exists)
2. [Git vs GitHub](#2-git-vs-github)
3. [Core Concepts](#3-core-concepts)
4. [First Time Workflow](#4-first-time-workflow)
5. [Day-to-Day Workflow](#5-day-to-day-workflow)
6. [Branches](#6-branches)
7. [Common Errors and Fixes](#7-common-errors-and-fixes)
8. [Commands Quick Reference](#8-commands-quick-reference)

---

## 1. What is Git and Why It Exists

Imagine you're writing 10,000 lines of code. Day 11, you add 10 more lines and everything breaks. Without Git, you're stuck — you don't know what changed. With Git, you can look at the exact difference, roll back, and fix it.

Git solves this by creating **checkpoints** (commits) of your code at different points in time. Each commit captures the full state of your project so you can always go back.

```
Day 1 → 10,000 lines → working → save → commit (checkpoint 1)
Day 11 → +10 lines → error → diff → found the bug → fix → commit (checkpoint 2)
```

Git also lets you work on separate **branches** — think of it like making a copy of your project to try something new without touching the working version.

---

## 2. Git vs GitHub

These are two different things that work together:

| | Git | GitHub |
|--|-----|--------|
| What it is | A tool installed on your computer | A website (cloud storage for code) |
| What it does | Tracks changes locally | Stores your code online so others can see it |
| Analogy | The camera that takes photos | The photo album everyone can look at |

```
Your computer
  └── Git (local tool)
        └── tracks changes
              └── push to GitHub (online)
                    └── anyone can clone/view/collaborate
```

---

## 3. Core Concepts

**Repository (repo)** — the project folder that Git is tracking. Everything inside it is versioned.

**Commit** — a saved checkpoint. Every commit has a message describing what changed and a unique hash ID.

**Branch** — a parallel version of the code. The main branch is the stable version. You create new branches for features or experiments.

**Origin** — the nickname Git gives to your remote GitHub repository URL. When you push or pull, you're pushing to/pulling from origin.

**Clone** — download an entire GitHub repo to your local machine including all history.

---

## 4. First Time Workflow

This is the sequence you run once when setting up a new project for the first time.

```bash
# step 1 — initialise git in your project folder
git init

# step 2 — stage all files (the dot means "everything")
git add .

# step 3 — create your first commit
git commit -m "first commit"

# if you get "Author identity unknown" error, run these first:
git config user.email "your@email.com"
git config user.name "YourName"
# note: no --global flag → these settings stay inside this folder only
# this avoids conflicts if you have multiple GitHub accounts

# step 4 — rename branch to main (GitHub expects main not master)
git branch -M main

# step 5 — connect to your GitHub repo
git remote add origin https://github.com/YourUsername/your-repo.git

# step 6 — push your code up for the first time
git push -u origin main
# -u sets upstream so future pushes just need: git push
```

---

## 5. Day-to-Day Workflow

After the first setup, this is what you do every time you make changes:

```bash
# check what changed
git status

# stage specific file
git add filename.py

# or stage everything
git add .

# commit with a meaningful message
git commit -m "add feature X / fix bug Y"

# push to GitHub
git push
```

### Two ways to get a repo onto your computer

**Option 1 — You created it locally (covered above)**
Run `git init`, add files, push up.

**Option 2 — It already exists on GitHub**
```bash
git clone https://github.com/Username/repo-name.git
# downloads everything including full history
```

### Pulling changes from GitHub

If someone else pushed changes (or you uploaded files via GitHub UI), your local repo is out of date. Sync it with:

```bash
git pull origin main
```

---

## 6. Branches

The main branch holds the working, production-ready code. You never experiment directly on main — you create a branch.

```
main branch → pandas v0.0.2 (stable, working)
   └── feature branch → trying pandas v0.0.3 upgrade
         └── test it → works → merge back to main
```

### Creating and using branches

```bash
# create a new branch and switch to it
git checkout -b feature-branch-name

# see all branches (current branch has *)
git branch

# switch between branches
git checkout main
git checkout feature-branch-name

# merge feature branch into main (after testing)
git checkout main
git merge feature-branch-name
```

### Real world example

Say your project uses pandas 0.0.2. You want to test if upgrading to 0.0.3 breaks anything:

```bash
git checkout -b pandas-upgrade    # new branch, safe to experiment
# make changes, test everything
git checkout main                 # back to stable version
git merge pandas-upgrade          # only merge if tests passed
```

If the upgrade broke things, you just delete the branch — main is untouched.

---

## 7. Common Errors and Fixes

**Error: "Author identity unknown"**
```
Author identity unknown
*** Please tell me who you are.
```
Fix — tell Git your identity for this project:
```bash
git config user.email "your@email.com"
git config user.name "YourName"
```
Then retry your commit. Use `--global` only if you want this for all projects on the machine.

---

**Error: "remote: Permission denied to OldUser"**

This happens when your computer saved old GitHub credentials and is trying to authenticate as a different account.

Fix on Windows — open Credential Manager → Windows Credentials → find `git:https://github.com` → remove or edit it.

Fix on Mac — open Keychain Access → search `github.com` → delete the internet password entry.

---

**Error: "fatal: remote origin already exists"**

You already ran `git remote add origin` before.
```bash
git remote remove origin
git remote add origin https://github.com/Username/repo.git
```

---

**Error: "failed to push some refs to..."**

Your local branch is behind the remote — usually because GitHub has a README or other file your local copy doesn't have.
```bash
git pull origin main --rebase
git push
```

---

## 8. Commands Quick Reference

| Task | Command |
|------|---------|
| Initialise repo | `git init` |
| Stage everything | `git add .` |
| Stage one file | `git add filename.py` |
| Commit | `git commit -m "message"` |
| Push (first time) | `git push -u origin main` |
| Push (after setup) | `git push` |
| Pull latest | `git pull origin main` |
| Clone a repo | `git clone <url>` |
| Check status | `git status` |
| See history | `git log --oneline` |
| Check config | `git config --list` |
| Set name (local) | `git config user.name "Name"` |
| Set email (local) | `git config user.email "email"` |
| Create branch | `git checkout -b branch-name` |
| Switch branch | `git checkout branch-name` |
| List branches | `git branch` |
| Merge branch | `git merge branch-name` |
| Connect remote | `git remote add origin <url>` |
| Remove remote | `git remote remove origin` |
| Rename to main | `git branch -M main` |

---

*Next: merge conflicts, git stash, pull requests, .gitignore*
