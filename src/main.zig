const std = @import("std");
const types = @import("types.zig");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    const file = std.fs.cwd().openFile("API.txt", .{ .mode = .read_only }) catch |err| {
        try stdout.print("API file error: {any}\n", .{err});
        return;
    };

    const api_raw = try file.readToEndAlloc(allocator, 122);
    const api = std.mem.trim(u8, api_raw, " \r\n\t");

    var url_buffer: [1022]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "https://duckdice.io/api/bot/user-info?api_key={s}", .{api});
    file.close();
    defer arena.deinit();

    var client = std.http.Client{
        .allocator = allocator,
    };

    const headers = &[_]std.http.Header{
        .{ .name = "X-Custom-Header", .value = "application" },
    };

    const response_body = try get(url, headers, &client, allocator);

    var result = try std.json.parseFromSlice(types.Response, allocator, response_body, .{ .ignore_unknown_fields = true });

    defer result.deinit();

    if (result.value.username) |username| {
        try stdout.print("\nParsed user data for: {s}\n", .{username});
    } else {
        try stdout.print("User data loaded, but username field was missing.\n", .{});
    }

    if (result.value.balances) |balances| {
        try stdout.print("User's balances:\n", .{});
        for (balances) |balance| {
            if (balance.currency) |currency| {
                try stdout.print("  - Currency: {s}\n", .{currency});
            }
            if (balance.main) |main_balance| {
                try stdout.print("    Main balance: {s}\n", .{main_balance});
            }
            if (balance.faucet) |faucet_balance| {
                try stdout.print("    Faucet balance: {s}\n", .{faucet_balance});
            }
        }
    } else {
        try stdout.print("User data loaded, but the balances field was missing.\n", .{});
    }

    try stdout.flush();
}

fn get(
    url: []const u8,
    headers: []const std.http.Header,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) ![]u8 {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    const limit = std.mem.indexOf(u8, url, "=").?;
    try stdout.print("\nURL: {s}<API-KEY> GET\n", .{url[0 .. limit + 1]});

    var body_writter: std.io.Writer.Allocating = .init(allocator);
    defer body_writter.deinit();

    try stdout.print("Sending request...\n", .{});
    const response = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .extra_headers = headers, //put these here instead of .headers
        .response_writer = &body_writter.writer, // this allows us to get a response of unknown size
    });

    try stdout.flush();

    const slice = try body_writter.toOwnedSlice();
    try stdout.print("Response Status: {d}\nResponse Body:{s}\n", .{ response.status, slice });

    // Return the response body to the caller
    return slice;
}
