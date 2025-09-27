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
const parseFloat = std.fmt.parseFloat;

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
    var user_info_url_buffer: [96]u8 = undefined;
    const user_info_url = try std.fmt.bufPrint(&user_info_url_buffer, "{s}bot/user-info?api_key={s}", .{ duckdice_base_url, api });

    var og_dice_url_buffer: [96]u8 = undefined;
    const og_dice_url = try std.fmt.bufPrint(&og_dice_url_buffer, "{s}dice/play?api_key={s}", .{ duckdice_base_url, api });

    var range_dice_url_buffer: [96]u8 = undefined;
    const range_dice_url = try std.fmt.bufPrint(&range_dice_url_buffer, "{s}range-dice/play?api_key={s}", .{ duckdice_base_url, api });

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
    try stdout.print("--" ** 20 ++ "\n", .{});
    try stdout.writeAll("Betting strategies:\n1)[S]ingle bet\n");
    try stdout.writeAll("2)[L]abouchere\n3)[F]ibonacci\n");
    try stdout.print("--" ** 20 ++ "\n", .{});
    try stdout.writeAll("Choose betting strategy: ");
    try stdout.flush();

    const bet_strat = try input(allocator);

    var dice_game: bool = true;
    try stdout.writeAll("Choose Dice Game:\n1)[O]riginal Dice\n2)[R]ange Dice\n");
    try stdout.print("--" ** 20 ++ "\n", .{});
    try stdout.writeAll("Choice: ");
    try stdout.flush();

    const dice_choice = try input(allocator);
    if (std.mem.eql(u8, dice_choice, "2") or std.mem.eql(u8, dice_choice, "R") or std.mem.eql(u8, dice_choice, "r")) {
        dice_game = false;
    }

    try stdout.writeAll("Possible currency choices:\n");
    for (possible_currencies.items, 1..) |currency, idx| {
        try stdout.print("{d}: {s}\n", .{ idx, currency });
    }
    try stdout.print("--" ** 20 ++ "\n", .{});
    try stdout.writeAll("Enter a number for the chosen currency: ");
    try stdout.flush();
    const coin_num_str = try input(allocator);
    const coin_num = (parseInt(u16, coin_num_str, 10) catch 256) - 1;
    const coin_name = if (coin_num < possible_currencies.items.len) possible_currencies.items[coin_num] else "DECOY";
    try stdout.print("Chosen currency: {s}.\n", .{coin_name});
    try stdout.flush();
    const minimum: u128 = if (std.mem.eql(u8, coin_name, "DECOY")) 1_000_000 else if (std.mem.eql(u8, coin_name, "BTC")) 1 else cg.calculateMinimum(allocator, &client, coin_name) catch |err| blk: {
        try stdout.print(
            "Minimum couldn't be calculated for {s}, because of {any}\nSetting minimum to 1.\n",
            .{ coin_name, err },
        );
        try stdout.flush();
        break :blk 1;
    };
    const minimum_as_f128 = aritmethic.intToFloat(minimum);

    var faucet: bool = false;
    if (std.mem.eql(u8, coin_name, "DECOY")) {
        faucet = false;
    } else {
        try stdout.writeAll("Choose a mode:\n1)[M]ain\n2)[F]aucet\nEnter a number: ");
        try stdout.flush();
        const input_f = try input(allocator);
        if (std.mem.eql(u8, input_f, "2") or std.mem.eql(u8, input_f, "f") or std.mem.eql(u8, input_f, "F")) {
            faucet = true;
        }
    }

    var is_high: bool = true;
    var limits = types.Limit{};
    var bottom: u16 = undefined;
    if (dice_game) {
        try stdout.writeAll("Side:\n1)[H]igh\n2)[L]ow\nChoose: ");
        try stdout.flush();
        const input_h = try input(allocator);
        if (std.mem.eql(u8, input_h, "2") or std.mem.eql(u8, input_h, "l") or std.mem.eql(u8, input_h, "L")) {
            is_high = false;
        }
    } else {
        try stdout.writeAll("Choose bottom limit for your range: ");
        try stdout.flush();
        const input_l = try input(allocator);
        bottom = parseInt(u16, input_l, 10) catch 5000;
    }

    var amount: f128 = 0.0;
    try stdout.writeAll("Enter bet amount: ");
    try stdout.flush();
    const input_amount = try input(allocator);
    amount = parseFloat(f128, input_amount) catch 0.0;
    if (amount < minimum_as_f128) {
        try stdout.print("Chosen amount is lower than {d:.8} {s}\n", .{ minimum_as_f128, coin_name });
        try stdout.print("Setting amount to {d:.8} {s}\n", .{ minimum_as_f128, coin_name });
        try stdout.flush();
        amount = minimum_as_f128;
    }

    const bet_strat_choice = if (bet_strat.len > 0) bet_strat[0] else 'e';

    const bals = result.value.balances.?;

    var current_as_str: ?[]const u8 = null;

    for (bals) |balance_item| {
        if (std.mem.eql(u8, coin_name, balance_item.currency.?)) {
            if (faucet) {
                current_as_str = balance_item.faucet;
            } else {
                current_as_str = balance_item.main;
            }
            break;
        }
    }

    switch (bet_strat_choice) {
        '1', 'S', 's' => {
            var bet_response: types.Bet = undefined;
            if (dice_game) {
                bet_response = betting.placeABet(og_dice_url, coin_name, amount, faucet, "44", is_high, allocator) catch |err| {
                    try stdout.print("Bet didn't work. Error: {any}\n", .{err});
                    try stdout.flush();
                    std.process.exit(1);
                };
            } else {
                limits.set(bottom, 4399);
                bet_response = betting.placeARangeDiceBet(range_dice_url, coin_name, amount, faucet, limits, true, allocator) catch |err| {
                    try stdout.print("Bet didn't work. Error: {any}\n", .{err});
                    try stdout.flush();
                    std.process.exit(1);
                };
            }

            try stdout.writeAll("Bet successfully made:)\n");

            const bet_roll = bet_response.number.?;
            const bet_result = bet_response.result;

            if (!dice_game) {
                try stdout.print("Range: {d}-{d}\n", .{ limits.bottom(), limits.top() });
            }
            try stdout.print("Roll: {d}\n", .{bet_roll});

            if (bet_result) {
                try stdout.writeAll("Success!✅\n");
            } else {
                try stdout.writeAll("Failure!☯ \n");
            }

            try stdout.flush();
        },
        '2', 'L', 'l' => {
            try stdout.print("Current balance: {s} {s}\n", .{ current_as_str.?, coin_name });

            const current_balance_as_f = try parseFloat(f128, current_as_str.?);
            const amount_as_int = aritmethic.floatToInt(amount);
            const goal_balance_default: u128 = aritmethic.floatToInt(current_balance_as_f) + 5 * amount_as_int;
            try stdout.writeAll("Enter goal balance: ");
            try stdout.flush();
            const goal_balance_str = try input(allocator);
            var goal_balance_as_f: f128 = parseFloat(f128, goal_balance_str) catch aritmethic.intToFloat(goal_balance_default);
            const goal_balance_as_int = aritmethic.floatToInt(goal_balance_as_f);
            if (goal_balance_as_int > aritmethic.floatToInt(current_balance_as_f) + 10 * amount_as_int) {
                goal_balance_as_f = aritmethic.intToFloat(goal_balance_default);
            }
            try stdout.print("Goal: {d:.8} {s}\n", .{ goal_balance_as_f, coin_name });
            try stdout.writeAll("Starting Labouchere run.\n");
            try stdout.flush();

            if (dice_game) {
                try betting.labouchere(og_dice_url, coin_name, amount, faucet, current_balance_as_f, goal_balance_as_f, is_high, dice_game, limits, allocator);
            } else {
                limits.set(bottom, 4399);
                try betting.labouchere(range_dice_url, coin_name, amount, faucet, current_balance_as_f, goal_balance_as_f, is_high, dice_game, limits, allocator);
            }
        },
        '3', 'F', 'f' => {
            try stdout.print("Current balance: {s} {s}\n", .{ current_as_str.?, coin_name });

            const current_balance_as_f = try parseFloat(f128, current_as_str.?);
            try stdout.writeAll("Enter goal balance: ");
            try stdout.flush();
            const goal_balance_str = try input(allocator);
            const goal_balance_as_f: f128 = parseFloat(f128, goal_balance_str) catch aritmethic.add(current_balance_as_f, amount, 3);
            try stdout.writeAll("Enter lower limit: ");
            try stdout.flush();
            const limit_balance_str = try input(allocator);
            const limit_balance_as_f: f128 = parseFloat(f128, limit_balance_str) catch aritmethic.sub(current_balance_as_f, 10.0 * amount);
            try stdout.print("Goal: {d:.8} {s}\nLimit: {d:.8} {s}\n", .{ goal_balance_as_f, coin_name, limit_balance_as_f, coin_name });
            try stdout.writeAll("Starting Fibonacci run.\n");
            try stdout.flush();

            if (dice_game) {
                try betting.fibSeq(og_dice_url, coin_name, amount, faucet, current_balance_as_f, goal_balance_as_f, limit_balance_as_f, is_high, dice_game, limits, allocator);
            } else {
                limits.set(bottom, 4399);
                try betting.fibSeq(range_dice_url, coin_name, amount, faucet, current_balance_as_f, goal_balance_as_f, limit_balance_as_f, is_high, dice_game, limits, allocator);
            }
        },
        else => {
            try stdout.writeAll("You chose poorly!\n");
            try stdout.flush();
            std.process.exit(1);
        },
    }
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
