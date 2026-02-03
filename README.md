# 12wy.el - 12-Week Year Tracking for Emacs

Track goals using the [12-Week Year](https://12weekyear.com/) methodology in Emacs. Point the system at an org file, get views and tracking.

## Installation

```elisp
(add-to-list 'load-path "/path/to/12wy")
(require '12wy)
```

## Usage

`M-x 12wy` opens the transient menu with all commands:

- **Set File** - Point to your 12-week year org file
- **Weekly View** - See current week's tactics and score
- **Dashboard** - Goals×weeks table with completion percentages
- **New Week** - Insert new week entry with tactics auto-populated
- **Insert Review** - Add end-of-period review template
- **Insert Prep** - Add next period planning template

## Org File Structure

```org
#+TITLE: 12-Week Year - Q1 2026
#+12WY_START: 2026-01-06

* Goals
** Goal 1: Ship side project
*** TODO Tactic: Code 5 hours/week
*** TODO Tactic: Write 1 blog post/week

** Goal 2: Get fit
*** TODO Tactic: Gym 3x/week
*** TODO Tactic: Track calories daily

* Weekly Log
** Week 1 <2026-01-06>
- [X] Code 5 hours/week
- [ ] Gym 3x/week
- [X] Track calories daily

* Review
* Next Period Prep
```

Key points:
- `#+12WY_START` sets week 1 start date
- Goals contain Tactics as TODO subheadings
- Weekly Log tracks tactic completion with checkboxes

## Customization

- `12wy-file` - Path to current org file
- `12wy-target-score` - Target execution % (default 85)
