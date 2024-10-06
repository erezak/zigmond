const std = @import("std");

const c = @cImport({
    @cInclude("termios.h");
});
const TCSANOW = 0;

const Error = error{
    BuildFailed,
};

pub fn main() !void {
    const cwd = std.fs.cwd();

    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer().any();

    // Directory and file watching setup
    try watchAndBuild(&cwd, allocator, stdout);
}

fn watchAndBuild(parent_cwd: *const std.fs.Dir, allocator: std.mem.Allocator, writer: std.io.AnyWriter) !void {
    const interval = 1 * std.time.ns_per_s; // Check every second

    // Explicitly open the current working directory
    var cwd = try parent_cwd.openDir(".", .{});
    defer cwd.close();

    var last_checked_time: i128 = std.time.nanoTimestamp();

    var tracked_files = try findZigFiles(allocator, &cwd);

    const stdin = std.io.getStdIn().handle;
    var in_buffer: [1]u8 = undefined;
    var original_termios: c.struct_termios = undefined;
    _ = c.tcgetattr(stdin, &original_termios); // Get the current terminal settings
    var raw_termios = original_termios;
    c.cfmakeraw(&raw_termios);
    _ = c.tcsetattr(stdin, TCSANOW, &raw_termios); // Apply raw mode settings
    defer {
        // Restore original terminal settings on exit
        _ = c.tcsetattr(stdin, TCSANOW, &original_termios);
    }

    while (true) {
        std.time.sleep(interval); // No need for try here
        // Try reading input without blocking
        const bytes_read = try std.io.getStdIn().reader().readAll(&in_buffer);
        if (bytes_read > 0 and in_buffer[0] == 'q') {
            try writer.print("\nExiting watcher...\n", .{});
            break; // Exit the loop if `q` is pressed
        }

        const new_tracked_files = try findZigFiles(allocator, &cwd);

        // Check if any files are added or removed
        if (!compareFiles(tracked_files, new_tracked_files)) {
            tracked_files = new_tracked_files;
            try build(allocator, writer);
            last_checked_time = std.time.microTimestamp();
        } else {
            // Check for modifications in tracked files
            var modified = false;
            for (tracked_files) |file| {
                // Allocate a full path using the allocator
                // TODO: Use std.fs.path.join instead of manual concatenation
                // TODO: Check why full_path only holds the first few bytes of the path
                const full_path = try std.fs.path.join(allocator, &[_][]const u8{ ".", file.name });
                defer allocator.free(full_path);

                // Open the file using the full path
                const file_handle = try cwd.openFile(full_path, .{});
                defer file_handle.close();

                const stat = try file_handle.stat();
                if (stat.mtime > last_checked_time) {
                    last_checked_time = std.time.nanoTimestamp();
                    modified = true;
                    break;
                }
            }

            if (modified) {
                try build(allocator, writer);
                last_checked_time = std.time.nanoTimestamp();
            }
        }
    }
}

fn findZigFiles(allocator: std.mem.Allocator, cwd: *const std.fs.Dir) ![]std.fs.Dir.Entry {
    var zig_files = std.ArrayList(std.fs.Dir.Entry).init(allocator);
    defer zig_files.deinit();

    var it = try cwd.walk(allocator);
    while (try it.next()) |entry| {
        // Skip files in .zig-cache
        if (std.mem.startsWith(u8, entry.path, ".zig-cache")) continue;

        // Check if the entry is a file and ends with ".zig"
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".zig")) {
            // Allocate a deep copy of the entry path
            const name_copy = try allocator.alloc(u8, entry.path.len);
            std.mem.copyForwards(u8, name_copy, entry.path);

            // Create a new fs.Dir.Entry with the copied path
            const new_entry = std.fs.Dir.Entry{
                .name = name_copy,
                .kind = entry.kind,
            };
            try zig_files.append(new_entry);
        }
    }

    return zig_files.toOwnedSlice();
}

fn compareFiles(old: []std.fs.Dir.Entry, new: []std.fs.Dir.Entry) bool {
    // Compare the file lists; if there are changes, return false
    if (old.len != new.len) return false;

    // Use a manual loop to compare files
    var index: usize = 0;
    while (index < old.len) : (index += 1) {
        if (!std.mem.eql(u8, old[index].name, new[index].name)) {
            return false;
        }
    }

    return true;
}

fn build(allocator: std.mem.Allocator, writer: std.io.AnyWriter) !void {
    try writer.print("***************\n", .{});
    try writer.print("* Building... *\n", .{});
    try writer.print("***************\n", .{});

    // Initialize the command with the arguments
    var cmd = std.process.Child.init(&[_][]const u8{ "zig", "build" }, allocator);

    // Make sure stdin, stdout, and stderr are inherited from the parent
    cmd.stdin_behavior = .Inherit;
    cmd.stdout_behavior = .Inherit;
    cmd.stderr_behavior = .Inherit;

    // Spawn the process
    try cmd.spawn();

    // Wait for the process to finish and retrieve the exit code
    const exit_code = try cmd.wait();
    // if exit_code is not 0, create an error and return it
    if (exit_code != std.process.Child.Term.Exited) {
        return Error.BuildFailed;
    }
}
