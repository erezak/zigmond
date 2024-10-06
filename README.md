
# Zigmond

A simple file watcher in Zig that monitors `.zig` files in a directory and rebuilds the project when changes are detected. The watcher can be stopped gracefully by pressing the `q` key.

## Features

- Watches a directory for changes to `.zig` files.
- Rebuilds the project automatically upon file changes.
- Gracefully stops the watcher when `q` is pressed.

## Requirements

- [Zig](https://ziglang.org/download/) version 0.14.0 or later.

## Getting Started

### Clone the Repository

```bash
git clone https://github.com/erezak/zigmond.git
cd zigmond
```

### Build and Run the Project

To build the project, run:

```bash
zig build
```

To start watching for file changes, run:

```bash
zig build run
```

This will start monitoring all `.zig` files in the current directory.

## How to Use

1. **Start Watching for Changes**  
   Run the watcher from the project directory:

   ```bash
   zigmond
   ```

   This will start monitoring all `.zig` files in the current directory.

2. **Automatic Rebuild on Change**  
   If any `.zig` files are modified, added, or removed, the watcher will automatically trigger a rebuild.

3. **Stop the Watcher**  
   Press the `q` key at any time to stop the watcher gracefully.

## Code Overview

- **`main.zig`**  
  The main file containing the logic for watching `.zig` files in the directory, detecting changes, and rebuilding the project.

- **Functions**  
  - `watchAndBuild`: The core function that monitors file changes and triggers a build.
  - `findZigFiles`: Finds all `.zig` files in the current directory (excluding `.zig-cache`).
  - `compareFiles`: Compares two file lists to detect additions, deletions, or modifications.
  - `build`: Executes `zig build` to rebuild the project.

- **Graceful Exit**  
  The program sets the terminal to "raw" mode to capture keypresses without blocking, and restores the original terminal settings when exiting.

## Customization

You can adjust the behavior of the file watcher by modifying the `interval` in the `watchAndBuild` function. The current setup checks for file changes every second:

```zig
const interval = 1 * std.time.ns_per_s; // Check every second
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request if you have any ideas or improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Made with 💻 and ⚡️ by [Erez Korn](https://github.com/erezak)
