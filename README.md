# dbibih CLI Tool

A modular command-line toolkit by **Marouane Dbibih**, packaged as a Debian `.deb` for Linux automation and cleanup workflows.

## Project Structure

```
dbibih-cli/
├── cmd/
│   └── dbibih-cli
├── internal/
│   ├── core/
│   ├── docker/
│   ├── nodejs/
│   ├── python/
│   └── system/
├── package/
│   └── deb/
│       ├── DEBIAN/
│       └── usr/local/bin/dbibih-cli
├── scripts/
│   ├── build-deb.sh
│   ├── install-local.sh
│   └── smoke-test.sh
├── test/
│   ├── fixtures/
│   └── integration/
├── docs/
│   ├── commands.md
│   └── cleanup-policies.md
├── Makefile
└── build.sh
```

## Build and Install

```bash
bash build.sh
```

Or step-by-step:

```bash
bash scripts/build-deb.sh
bash scripts/install-local.sh
```

## Usage

```bash
dbibih-cli nodejs --cleanup --help
dbibih-cli docker --cleanup --help
dbibih-cli docker status
```

Additional command references:
- `docs/commands.md`
- `docs/cleanup-policies.md`

## Development

```bash
make build
make smoke
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).