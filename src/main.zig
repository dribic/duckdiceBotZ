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

    const response_body = try net.getDuckdice(user_info_url, &client, allocator);

    var result = try std.json.parseFromSlice(types.UserInfoResponse, allocator, response_body, .{ .ignore_unknown_fields = true });
    defer result.deinit();

    if (result.value.username) |username| {
        try stdout.print("Parsed user data for: {s}\n", .{username});
    } else {
        try stdout.print("User data loaded, but username field was missing.\n", .{});
        return;
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
        return;
    }
    try stdout.flush();

    try stdout.writeAll("Possible choices:\n");
    for (possible_currencies.items, 1..) |currency, idx| {
        try stdout.print("{d}: {s}\n", .{ idx, currency });
    }
    try stdout.flush();
    try stdout.writeAll("\n\n");

    // Test only
    const coin_name = "USDT";
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
        return;
    };

    try stdout.writeAll("Bet successfully made:)\n");

    if (bet_result) {
        try stdout.writeAll("Success!✅\n");
    } else {
        try stdout.writeAll("Failure!☯ \n");
    }

    try stdout.flush();
}
