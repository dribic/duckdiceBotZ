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

pub fn getDuckdice(
    url: []const u8,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) ![]u8 {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    const limit = std.mem.indexOf(u8, url, "=").?;
    try stdout.print("\nURL: {s}<API-KEY> GET\n", .{url[0 .. limit + 1]});

    const headers = &[_]std.http.Header{
        .{ .name = "X-Custom-Header", .value = "application" },
    };

    var body_writter: std.io.Writer.Allocating = .init(allocator);
    defer body_writter.deinit();

    try stdout.print("Sending request...\n", .{});
    const response = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .extra_headers = headers, //put these here instead of .headers
        .response_writer = &body_writter.writer, // this allows us to get a response of unknown size
    });

    const slice = try body_writter.toOwnedSlice();
    try stdout.print("Response Status: {d}\nResponse Body:{s}\n", .{ response.status, slice });

    try stdout.flush();

    // Return the response body to the caller
    return slice;
}

pub fn getCoingecko(
    url: []const u8,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) ![]u8 {
    var body_writter: std.io.Writer.Allocating = .init(allocator);
    defer body_writter.deinit();

    _ = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .response_writer = &body_writter.writer, // this allows us to get a response of unknown size
    });

    const slice = try body_writter.toOwnedSlice();

    return slice;
}

pub fn post(
    url: []const u8,
    bet_data: []const u8,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) ![]u8 {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    const limit = std.mem.indexOf(u8, url, "=").?;
    try stdout.print("\nURL: {s}<API-KEY> GET\n", .{url[0 .. limit + 1]});

    const headers = &[_]std.http.Header{
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var body_writter: std.io.Writer.Allocating = .init(allocator);
    defer body_writter.deinit();

    try stdout.print("Sending request...\n", .{});
    const response = try client.fetch(.{
        .method = .GET,
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
