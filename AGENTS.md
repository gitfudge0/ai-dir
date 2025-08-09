# AGENTS.md

This repository contains agentic coding agents for Python and frontend development. Follow these guidelines for consistency and quality:

## Build, Lint, and Test Commands
- **Python:**
  - Run all tests: `pytest`
  - Run a single test: `pytest -k "test_name"`
  - Format code: `black .`
- **Frontend (if applicable):**
  - Run all tests: `npm test` or `yarn test`
  - Run a single test: `npm test -- -t "test_name"` (Jest)
  - Lint: `npm run lint` or `yarn lint`
  - Format: `npm run format` or `yarn format`

## Code Style Guidelines
- **Python:**
  - Follow PEP 8 and Black formatting (88 char lines).
  - Use snake_case for functions/variables, PascalCase for classes, SCREAMING_SNAKE_CASE for constants.
  - Add type hints and PEP 257 docstrings.
  - Prefer pathlib over os.path.
  - Use specific exceptions, logging, and context managers.
  - Test with pytest, use fixtures, TDD when possible.
- **Frontend:**
  - Use semantic HTML, WCAG 2.2 AA accessibility, and Core Web Vitals.
  - Test in major browsers; use linting and formatting tools.
  - Follow project framework conventions (React/Next.js: use next/link, next/image, accessible components).
  - Sanitize inputs, use HTTPS, secure headers, and CSP.

## General
- No Cursor or Copilot rules found in this repo.
- If you add build/lint/test config files, update this document.
- Always write clean, maintainable, and well-tested code.
