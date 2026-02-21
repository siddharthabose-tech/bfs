# BFS - Bootable Fix System

A guided Linux rescue system designed for users coming from non-Linux backgrounds.

## What is BFS?

BFS is a bootable ISO that helps you rescue broken Linux systems through:
- Guided step-by-step wizards (no terminal knowledge required)
- Plain English explanations of what's broken and how to fix it
- Showing exact commands before running them (educational)
- Offline documentation so you don't need internet access

## Status

🚧 **Currently in development** - Phase 1 implementation in progress

## Project Structure

```
bfs/
├── build/      # Build scripts for creating the ISO
├── src/        # BFS source code
├── data/       # Static data (distro database, help files)
├── docs/       # All design documents
├── tests/      # Testing framework
└── scripts/    # Development utilities
```

## Development Setup

See `docs/development/setup-guide.md` for development environment setup.

## License

GPL v3 - See LICENSE file

## Contributing

This project is in early development. Contributions welcome once v1.0 is released.
