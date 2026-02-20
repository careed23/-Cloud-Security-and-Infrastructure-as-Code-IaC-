# Contributing

Thanks for contributing to this repository.

## Development Workflow

1. Fork the repository and create a branch from `main`.
2. Make focused changes tied to a single objective.
3. Run local checks before opening a pull request:

```bash
pre-commit run --all-files
```

4. Open a pull request with:
   - What changed
   - Why it changed
   - Security/compliance impact
   - Validation evidence (command output or screenshots)

## Commit Style

Use clear, imperative commit messages (example: `add checkov scan to ci workflow`).

## Pull Request Criteria

- Keep changes small and reviewable.
- Avoid unrelated refactors.
- Update `README.md` when behavior, setup, or workflows change.
- Ensure CI checks pass.

## Reporting Security Issues

Please do not open public issues for sensitive vulnerabilities. Follow [SECURITY.md](SECURITY.md) for responsible disclosure.
