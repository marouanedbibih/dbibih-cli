# dbibih CLI Tool

A lightweight custom command-line interface (CLI) toolkit by **Marouane Dbibih**, packaged as a Debian `.deb` package to automate essential system maintenance tasks on Linux.

---

## Features

The **dbibih-cli** package provides the following commands:
- `backup` — Perform system backups.
- `cleanup` — Clean up unnecessary system files.
- `cpu_memory_check` — Check current CPU and memory usage.
- `disk_check` — Display disk space usage.
- `system_update` — Update the system packages.

Each command is implemented as a standalone Bash script.

---

## Project Structure

```
dbibih-cli/
├── build.sh                  # Package build and install script
├── cli/
│   ├── DEBIAN/
│   │   ├── control           # Debian package metadata
│   │   ├── postinst          # Post-installation setup script
│   │   ├── postrm            # Post-removal cleanup script
│   │   └── prerm             # Pre-removal script
│   └── usr/
│       └── local/
│           └── bin/
│               ├── dbibih    # Main CLI command
│               └── scripts/
│                   ├── backup.sh
│                   ├── cleanup.sh
│                   ├── cpu_memory_check.sh
│                   ├── disk_check.sh
│                   └── system_update.sh
├── LICENSE
└── README.md
```

---

## Installation

**Prerequisites**  
- A Linux system (Debian-based)
- `dpkg` installed

**Build and Install**
```bash
bash build.sh
```

This will:
- Build the `dbibih-cli.deb` package
- Install it using `dpkg`
- Set up executable symlinks for your commands in `/usr/local/bin`

---

## Usage

After installation, you can run:

```bash
backup
cleanup
cpu_memory_check
disk_check
system_update
```

You can also run the main CLI entry point:
```bash
dbibih
```

---

## Uninstall

To remove the package:
```bash
sudo dpkg --remove dbibih-cli
```

This will cleanly remove the CLI and associated symlinks from your system.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Author

**Marouane Dbibih**  
Email: marouane.dbibih@gmail.com  
GitHub: [github.com/marouane-db](https://github.com/marouane-db)

---

If you'd like, I can also generate a `man` page or a help message for `dbibih` itself. Would you like that?