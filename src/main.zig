const std = @import("std");
const csv = @import("csv");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const csv_path = std.os.argv[1];
    const csv_file = try std.fs.cwd().openFile(std.mem.spanZ(csv_path), .{});
    defer csv_file.close();

    const out_path = std.os.argv[2];
    var out_dir = try std.fs.cwd().openDir(std.mem.spanZ(out_path), .{});
    defer out_dir.close();

    const columns_path = std.os.argv[3];
    const columns_file = try std.fs.cwd().openFile(std.mem.spanZ(columns_path), .{});
    defer columns_file.close();

    const buffer = try allocator.alloc(u8, 4096);
    var tokenizer = try csv.CsvTokenizer(std.fs.File.Reader).init(csv_file.reader(), buffer, .{});

    var columns = std.ArrayList([]const u8).init(allocator);
    while (try columns_file.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
        try columns.append(line);
    }

    while (try tokenizer.next()) |token| {
        switch (token) {
            .field => continue,
            .row_end => break,
        }
    }

    var current_id: ?[]const u8 = null;
    var current_col: usize = 0;
    var current_out_file: ?std.fs.File = null;
    while (try tokenizer.next()) |token| {
        switch (token) {
            .field => |val| {
                if (current_id) |_| {
                    try current_out_file.?.writer().print("** {s}\n\n{s}\n\n", .{ columns.items[current_col], val });
                } else {
                    current_id = val;
                    current_out_file = try out_dir.createFile(try std.fmt.allocPrint(allocator, "{s}.org", .{current_id}), .{});
                }

                current_col += 1;
            },
            .row_end => {
                current_id = null;
                current_col = 0;
                current_out_file.?.close();
            },
        }
    }
}
