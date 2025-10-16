// Copyright (C) 2025 Dejan Ribič
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");

pub fn get(
    url: []const u8,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) ![]u8 {
    const headers = &[_]std.http.Header{
        .{ .name = "X-Custom-Header", .value = "application" },
    };

    var body_writter: std.io.Writer.Allocating = .init(allocator);
    defer body_writter.deinit();

    _ = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .extra_headers = headers, //put these here instead of .headers
        .response_writer = &body_writter.writer, // this allows us to get a response of unknown size
    });

    const slice = try body_writter.toOwnedSlice();

    // Return the response body to the caller
    return slice;
}

pub fn post(
    url: []const u8,
    bet_data: []const u8,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) ![]u8 {
    const headers = &[_]std.http.Header{
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var body_writter: std.io.Writer.Allocating = .init(allocator);
    defer body_writter.deinit();

    _ = try client.fetch(.{
        .method = .POST,
        .payload = bet_data,
        .location = .{ .url = url },
        .extra_headers = headers, //put these here instead of .headers
        .response_writer = &body_writter.writer, // this allows us to get a response of unknown size
    });

    const slice = try body_writter.toOwnedSlice();

    // Return the response body to the caller
    return slice;
}

// Not used anymore
pub fn postUsingCurl(
    allocator: std.mem.Allocator,
    url: []const u8,
    body: []const u8,
) ![]u8 {
    // Build curl arguments
    var argv = std.ArrayList([]const u8){};
    defer argv.deinit(allocator);

    try argv.append(allocator, "curl");
    try argv.append(allocator, "-s"); // silent mode
    try argv.append(allocator, "-X");
    try argv.append(allocator, "POST");

    try argv.append(allocator, url);

    // Headers
    try argv.append(allocator, "-H");
    try argv.append(allocator, "Content-Type: application/json");
    try argv.append(allocator, "-H");
    try argv.append(allocator, "User-Agent: DuckDiceBot/1.0.0");
    try argv.append(allocator, "-H");
    try argv.append(allocator, "Accept: */*");

    // JSON payload
    try argv.append(allocator, "-d");
    try argv.append(allocator, body);

    // Initialize and configure Child
    var child = std.process.Child.init(argv.items, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    // Spawn the process
    try child.spawn();

    // Collect output
    var stdout_buf = std.ArrayList(u8){};
    var stderr_buf = std.ArrayList(u8){};
    defer stderr_buf.deinit(allocator);

    try child.collectOutput(allocator, &stdout_buf, &stderr_buf, 64 * 1024);

    const term = try child.wait();
    if (term != .Exited or stderr_buf.items.len != 0) {
        return error.CurlFailed;
    }

    return stdout_buf.toOwnedSlice(allocator);
}

pub fn input(allocator: std.mem.Allocator) ![]const u8 {
    var stdin_buf: [64]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    const stdin = &stdin_reader.interface;

    const line = try stdin.takeDelimiterExclusive('\n');
    const trimmed = std.mem.trim(u8, line, " \t\r\n"); // Because Windows
    const result = try allocator.dupe(u8, trimmed);

    return result;
}
