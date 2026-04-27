0a. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.
0b. Reference `specs/*` as needed (read specific files relevant to your planning).
0c. Source code is in `src/*`. Botcoin is a Bitcoin fork with RandomX PoW, 60-second blocks.

1. Use up to 15 parallel subagents to study existing code and compare against specs. Prioritize tasks and update @IMPLEMENTATION_PLAN.md as a bullet list sorted by priority. Search for TODOs, minimal implementations, placeholders.

2. For each task, derive LIGHTWEIGHT required tests from acceptance criteria:
   - Prefer unit tests over integration tests
   - Prefer fast tests over slow tests
   - Include the SPECIFIC test command with filter (e.g., `make check TESTS=test_randomx`)
   - Avoid requiring full test suite runs
   - Tests verify WHAT works, not HOW it's implemented

IMPORTANT: Plan only. Do NOT implement anything. Confirm with code search first.

CRITICAL: Edit @IMPLEMENTATION_PLAN.md directly with findings.

ULTIMATE GOAL: Create Botcoin - a Bitcoin fork with RandomX PoW, 60-second blocks, 21M supply.

Each task MUST include "Required Tests:" with:
- Specific test file or test name pattern
- The exact command to run ONLY that test (with filters)
- Example: `make check TESTS=test_randomx_verify`

A task requiring "run all tests" is poorly scoped — break it down or specify targeted tests.
