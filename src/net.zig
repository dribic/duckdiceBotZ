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
    allocator: std.mem.Allocator,
) ![]u8 {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    const limit = std.mem.indexOf(u8, url, "=").?;
    try stdout.print("\nURL: {s}<API-KEY> POST\n", .{url[0 .. limit + 1]});
    try stdout.flush();

    // 1. Connect TCP
    const host = "duckdice.io"; // extract host from url if needed
    var stream = try std.net.tcpConnectToHost(allocator, host, 443);
    defer stream.close();

    var write_buf: [std.crypto.tls.max_ciphertext_record_len]u8 = undefined;
    var writer = stream.writer(&write_buf);

    var read_buf: [std.crypto.tls.max_ciphertext_record_len]u8 = undefined;
    var reader = stream.reader(&read_buf);

    var bundle = std.crypto.Certificate.Bundle{};
    try bundle.rescan(allocator);

    var write_buf2: [std.crypto.tls.max_ciphertext_record_len]u8 = undefined;
    var read_buf2: [std.crypto.tls.max_ciphertext_record_len]u8 = undefined;

    const tls_writer = &writer.interface;

    var tls_client = try std.crypto.tls.Client.init(
        reader.interface(),
        tls_writer,
        .{
            .ca = .{ .bundle = bundle },
            .host = .{ .explicit = host },
            .read_buffer = &read_buf2,
            .write_buffer = &write_buf2,
        },
    );
    defer tls_client.end() catch {};

    // 4. HTTP client over TLS
    var client = std.http.Client{
        .allocator = allocator,
        .ca_bundle = bundle,
    };
    defer client.deinit();

    const headers = &[_]std.http.Header{
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "User-Agent", .value = "DuckDiceBot/1.0.0" },
        .{ .name = "Accept", .value = "*/*" },
    };

    var body_writter: std.io.Writer.Allocating = .init(allocator);
    defer body_writter.deinit();
    try stdout.print("Cut url: {s}\n", .{url[19..]});
    try stdout.print("Headers:\n", .{});
    for (headers) |h| {
        try stdout.print("  {s}: {s}\n", .{ h.name, h.value });
    }
    try stdout.print("Body: {s}\n", .{bet_data});
    try stdout.flush();
    try stdout.print("Sending request...\n", .{});
    try stdout.flush();

    const string = try buildASendString(allocator, url, headers, bet_data);
    try stdout.print("Built string: {s}\nString length: {d}\n", .{ string, string.len });
    try stdout.flush();

    try tls_writer.writeAll(string);
    try tls_writer.flush();

    var resp_buf: [65536]u8 = undefined;
    const tls_reader = reader.interface();
    tls_reader.readSliceAll(&resp_buf) catch |err| {
        try stdout.print("Response string: {s}\nString length: {d}\nError: {any}\n", .{ resp_buf, resp_buf.len, err });
        try stdout.flush();
    };

    const response = try client.fetch(.{
        .method = .POST,
        .location = .{ .url = url },
        .payload = bet_data,
        .extra_headers = headers, //put these here instead of .headers
        .response_writer = &body_writter.writer, // this allows us to get a response of unknown size
    });

    const slice = try body_writter.toOwnedSlice();
    try stdout.print("Response Status: {d}\nResponse Body:{s}\n", .{ response.status, slice });

    try stdout.flush();

    // Return the response body to the caller
    return slice;
}

fn buildASendString(allocator: std.mem.Allocator, url: []const u8, headers: []const std.http.Header, bet_data: []const u8) ![]u8 {
    var writer = std.ArrayList(u8){};

    var stream = writer.writer(allocator);

    try stream.print("POST {s} HTTP/1.1\r\n", .{url[19..]});
    try stream.writeAll("Host: duckdice.io\r\n");
    for (headers) |header| {
        try stream.print("{s}: {s}", .{ header.name, header.value });
        try stream.writeAll("\r\n");
    }

    try stream.print("Content-Length: {d}\r\n", .{bet_data.len});
    try stream.writeAll("Connection: close\r\n\r\n");
    try stream.writeAll(bet_data);

    const slice = writer.toOwnedSlice(allocator);

    return slice;
}

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
