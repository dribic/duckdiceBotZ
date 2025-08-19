const std = @import("std");
const types = @import("types.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    const file = std.fs.cwd().openFile("API.txt", .{ .mode = .read_only }) catch |err| {
        try stdout.print("API file error: {any}\n", .{err});
        return;
    };
    var reader = std.io.bufferedReader(file.reader());
    var in_stream = reader.reader();
    var line_buffer: [124]u8 = undefined;

    const api = try in_stream.readUntilDelimiterOrEof(&line_buffer, '\n');

    var url_buffer: [1022]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "https://duckdice.io/api/bot/user-info?api_key={s}", .{api.?});
    file.close();
    defer arena.deinit();

    var client = std.http.Client{
        .allocator = allocator,
    };

    const headers = &[_]std.http.Header{
        .{ .name = "X-Custom-Header", .value = "application" },
    };

    const response_body = try get(url, headers, &client, allocator);

    var result = try std.json.parseFromSlice(types.Response, allocator, response_body.items, .{ .ignore_unknown_fields = true });

    defer result.deinit();

    if (result.value.username) |username| {
        try stdout.print("Parsed user data for: {s}\n", .{username});
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
}

fn get(
    url: []const u8,
    headers: []const std.http.Header,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) !std.ArrayList(u8) {
    const stdout = std.io.getStdOut().writer();
    const limit = std.mem.indexOf(u8, url, "=").?;
    try stdout.print("\nURL: {s}<API-KEY> GET\n", .{url[0 .. limit + 1]});

    var response_body = std.ArrayList(u8).init(allocator);

    try stdout.print("Sending request...\n", .{});
    const response = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .extra_headers = headers, //put these here instead of .headers
        .response_storage = .{ .dynamic = &response_body }, // this allows us to get a response of unknown size
    });

    try stdout.print("Response Status: {d}\n Response Body:{s}\n", .{ response.status, response_body.items });

    // Return the response body to the caller
    return response_body;
}
