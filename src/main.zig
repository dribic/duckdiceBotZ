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
const types = @import("types.zig");
const net = @import("net.zig");
const cg = @import("coingecko.zig");
const aritmethic = @import("arithmetic.zig");
const betting = @import("betting.zig");

const parseInt = std.fmt.parseInt;

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    const json_file_path = "dd-coins.json";
    const json_url = "https://drive.google.com/uc?export=download&id=1uwQzYrdDX5puSHLeonf45oTbhtht8c3g";

    const json_file_exists: bool = blk: {
        _ = std.fs.cwd().access(json_file_path, .{}) catch |err| switch (err) {
            error.FileNotFound => break :blk false,
            else => return err,
        };
        break :blk true;
    };

    if (json_file_exists) {
        try stdout.print("File: {s} already exists.\n", .{json_file_path});
        try stdout.flush();
    } else {
        try stdout.print("File: {s} doesn't exist. Downloading...\n", .{json_file_path});
        try stdout.flush();
        var dl_list = std.ArrayList([]const u8){};
        defer dl_list.deinit(allocator);

        try dl_list.append(allocator, "curl");
        try dl_list.append(allocator, "-L");
        try dl_list.append(allocator, "-s");
        try dl_list.append(allocator, "-o");
        try dl_list.append(allocator, json_file_path);
        try dl_list.append(allocator, json_url);

        var child = std.process.Child.init(dl_list.items, allocator);
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        try child.spawn();
        const term = try child.wait();
        if (term.Exited != 0) {
            return error.DownloadFailed;
        }
        try stdout.print("Successfully downloaded {s}. Continuing...\n", .{json_file_path});
        try stdout.flush();
    }

    const file = std.fs.cwd().openFile("API.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => blk: {
            try stdout.print("API.txt not found. Please enter your API key: ", .{});
            try stdout.flush();

            const api_key = try input(allocator);

            const new_file = try std.fs.cwd().createFile("API.txt", .{});
            defer new_file.close();
            try new_file.writeAll(api_key);

            break :blk try std.fs.cwd().openFile("API.txt", .{ .mode = .read_only });
        },
        else => {
            try stdout.print("API file error: {any}\n", .{err});
            try stdout.flush();
            std.process.exit(1);
        },
    };

    const api_raw = try file.readToEndAlloc(allocator, 122);
    const api = std.mem.trim(u8, api_raw, " \r\n\t");

    const duckdice_base_url = "https://duckdice.io/api/";
    var user_info_url_buffer: [512]u8 = undefined;
    const user_info_url = try std.fmt.bufPrint(&user_info_url_buffer, "{s}bot/user-info?api_key={s}", .{ duckdice_base_url, api });

    var og_dice_url_buffer: [512]u8 = undefined;
    const og_dice_url = try std.fmt.bufPrint(&og_dice_url_buffer, "{s}dice/play?api_key={s}", .{ duckdice_base_url, api });

    // Cleanups
    file.close();
    defer arena.deinit();

    var client = std.http.Client{
        .allocator = allocator,
    };

    const response_body = try net.get(user_info_url, &client, allocator);

    var result = try std.json.parseFromSlice(types.UserInfoResponse, allocator, response_body, .{ .ignore_unknown_fields = true });
    defer result.deinit();

    if (result.value.username) |username| {
        try stdout.print("Parsed user data for: {s}\n", .{username});
    } else {
        try stdout.print("User data loaded, but username field was missing.\n", .{});
        try stdout.flush();
        std.process.exit(1);
    }

    var possible_currencies = std.ArrayList([]const u8){};
    defer possible_currencies.deinit(allocator);

    if (result.value.balances) |balances| {
        try stdout.print("User's balances:\n", .{});
        for (balances) |balance| {
            if (balance.currency) |currency| {
                try stdout.print("  - Currency: {s}\n", .{currency});
                try possible_currencies.append(allocator, currency);
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
        try stdout.flush();
        std.process.exit(1);
    }
    try stdout.flush();

    try stdout.writeAll("Possible choices:\n");
    for (possible_currencies.items, 1..) |currency, idx| {
        try stdout.print("{d}: {s}\n", .{ idx, currency });
    }

    // Test only
    try stdout.writeAll("Enter a number for the chosen currency: ");
    try stdout.flush();
    const coin_num_str = try input(allocator);
    const coin_num = try parseInt(u16, coin_num_str, 10) - 1;
    const coin_name = possible_currencies.items[coin_num];
    const minimum: u128 = if (std.mem.eql(u8, coin_name, "DECOY")) 1_000_000 else if (std.mem.eql(u8, coin_name, "BTC")) 1 else cg.calculateMinimum(allocator, &client, coin_name) catch |err| blk: {
        try stdout.print(
            "Minimum couldn't be calculated for {s}, because of {any}\nSetting minimum to 1.\n",
            .{ coin_name, err },
        );
        try stdout.flush();
        break :blk 1;
    };

    const minimum_as_f128 = aritmethic.intToFloat(minimum);

    try stdout.print("Minimum bet set to: {d:.8} {s}\n", .{ minimum_as_f128, coin_name });

    try stdout.print("Trying minimum bet on faucet for testing.\n", .{});

    try stdout.flush();

    const bet_result = betting.placeABet(og_dice_url, coin_name, minimum_as_f128, true, "44", true, allocator) catch |err| {
        try stdout.print("Bet didn't work. Error: {any}\n", .{err});
        try stdout.flush();
        std.process.exit(1);
    };

    try stdout.writeAll("Bet successfully made:)\n");

    if (bet_result) {
        try stdout.writeAll("Success!✅\n");
    } else {
        try stdout.writeAll("Failure!☯ \n");
    }

    try stdout.flush();
}

fn input(allocator: std.mem.Allocator) ![]const u8 {
    var stdin_buf: [64]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    const stdin = &stdin_reader.interface;

    const line = try stdin.takeDelimiterExclusive('\n');
    const trimmed = std.mem.trim(u8, line, " \t\r\n"); // Because Windows
    const result = try allocator.dupe(u8, trimmed);

    return result;
}
