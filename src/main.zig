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

    var client = std.http.Client{
        .allocator = allocator,
    };

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

        const json_file_data = try net.get(json_url, &client, allocator);
        const json_file = try std.fs.cwd().createFile(json_file_path, .{});
        defer json_file.close();

        var json_buffer: [2048]u8 = undefined;
        var writer = json_file.writer(&json_buffer);
        const f_write = &writer.interface;
        try f_write.writeAll(json_file_data);
        try f_write.flush();

        try stdout.print("Successfully downloaded {s}. Continuing...\n", .{json_file_path});
        try stdout.flush();
    }

    const file = std.fs.cwd().openFile("API.txt", .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => blk: {
            try stdout.print("API.txt not found. Please enter your API key: ", .{});
            try stdout.flush();

            const api_key = try net.input(allocator);

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

    // Master loop
    master_loop: while (true) {
        const response_body = try net.get(user_info_url, &client, allocator);

        var result = try std.json.parseFromSlice(types.UserInfoResponse, allocator, response_body, .{ .ignore_unknown_fields = true });
        defer result.deinit();

        const user_data: types.UserInfoResponse = result.value;

        if (user_data.username) |username| {
            try stdout.print("Parsed user data for: {s}\n", .{username});
        } else {
            try stdout.print("User data loaded, but username field was missing.\n", .{});
            try stdout.flush();
            std.process.exit(1);
        }

        var possible_currencies = std.ArrayList([]const u8){};
        defer possible_currencies.deinit(allocator);

        if (user_data.balances) |balances| {
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

        var tle_active: bool = false;
        try stdout.print("--" ** 20 ++ "\n", .{});
        var tle_name: ?[]const u8 = null;
        var tle_hash: ?[]const u8 = null;
        if (user_data.tle.len > 0) {
            try stdout.print("Time Limited Event:\n", .{});
            try stdout.print("--" ** 20 ++ "\n", .{});
            if (user_data.tle[0].name) |name| {
                tle_name = name;
                try stdout.print("   Name: {s}\n", .{name});
            }
            if (user_data.tle[0].hash) |hash| {
                tle_hash = hash;
                try stdout.print("   Hash: {s}\n", .{hash});
            }
            if (user_data.tle[0].status) |status| {
                try stdout.print("   Status: {s}\n", .{status});
                if (std.mem.eql(u8, status, "active")) {
                    tle_active = true;
                }
            }
        }
        try stdout.print("--" ** 20 ++ "\n", .{});
        try stdout.writeAll("Betting strategies:\n1)[S]ingle bet\n");
        try stdout.writeAll("2)[L]abouchere\n3)[F]ibonacci\n");
        try stdout.writeAll("4)[O]ne percent hunt\n0)[E]xit\n");
        try stdout.print("--" ** 20 ++ "\n", .{});
        try stdout.writeAll("Choose betting strategy: ");
        try stdout.flush();

        const bet_strat = try net.input(allocator);

        const bet_strat_choice = if (bet_strat.len > 0) bet_strat[0] else 'z';
        if (bet_strat_choice == 'z') {
            try stdout.print("You didn't enter a choice!\n", .{});
            try stdout.flush();
            continue :master_loop;
        }

        var dice_game: bool = true;
        if (std.mem.eql(u8, bet_strat, "0") or std.mem.eql(u8, bet_strat, "e") or std.mem.eql(u8, bet_strat, "E")) {
            try stdout.writeAll("Have a nice day.\nGoodbye.\n");
            try stdout.flush();
            break :master_loop;
        }

        try stdout.writeAll("Choose Dice Game:\n1)[O]riginal Dice\n2)[R]ange Dice\n");
        try stdout.print("--" ** 20 ++ "\n", .{});
        try stdout.writeAll("Choice: ");
        try stdout.flush();

        const dice_choice = try net.input(allocator);
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
        const coin_num_str = try net.input(allocator);
        const coin_num = (parseInt(u16, coin_num_str, 10) catch 256) - 1;
        const coin_name = if (coin_num < possible_currencies.items.len) possible_currencies.items[coin_num] else "DECOY";
        try stdout.print("Chosen currency: {s}.\n", .{coin_name});
        if (!std.mem.eql(u8, coin_name, "DECOY") or !std.mem.eql(u8, coin_name, "BTC")) {
            try stdout.print("Getting {s} minimum bet from CoinGecko...\n", .{coin_name});
        }
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

        var spec_hash: ?[]const u8 = null;
        var bet_mode: types.betMode = .main;
        if (std.mem.eql(u8, coin_name, "DECOY")) {
            bet_mode = .main;
        } else {
            try stdout.writeAll("Choose a mode:\n1)[M]ain\n2)[F]aucet\n");
            if (tle_active) {
                try stdout.print("3)[T]ime Limited Event: {s}\n", .{tle_name.?});
            }
            try stdout.writeAll("Choose: ");
            try stdout.flush();
            const input_f = try net.input(allocator);
            if (std.mem.eql(u8, input_f, "2") or std.mem.eql(u8, input_f, "f") or std.mem.eql(u8, input_f, "F")) {
                bet_mode = .faucet;
            } else if ((std.mem.eql(u8, input_f, "3") or std.mem.eql(u8, input_f, "t") or std.mem.eql(u8, input_f, "T")) and tle_active) {
                bet_mode = .tle;
                spec_hash = tle_hash.?;
            }
        }

        var is_high: bool = true;
        var limits = types.Limit{};
        var bottom: u16 = undefined;
        if (dice_game) {
            try stdout.writeAll("Side:\n1)[H]igh\n2)[L]ow\nChoose: ");
            try stdout.flush();
            const input_h = try net.input(allocator);
            if (std.mem.eql(u8, input_h, "2") or std.mem.eql(u8, input_h, "l") or std.mem.eql(u8, input_h, "L")) {
                is_high = false;
            }
        } else {
            try stdout.writeAll("Choose bottom limit for your range: ");
            try stdout.flush();
            const input_l = try net.input(allocator);
            bottom = parseInt(u16, input_l, 10) catch 5000;
        }

        var amount: f128 = 0.0;
        try stdout.writeAll("Enter bet amount: ");
        try stdout.flush();
        const input_amount = try net.input(allocator);
        amount = parseFloat(f128, input_amount) catch 0.0;
        if (amount < minimum_as_f128) {
            try stdout.print("Chosen amount is lower than {d:.8} {s}\n", .{ minimum_as_f128, coin_name });
            try stdout.print("Setting amount to {d:.8} {s}\n", .{ minimum_as_f128, coin_name });
            try stdout.flush();
            amount = minimum_as_f128;
        }

        const balances = user_data.balances.?;

        var current_as_str: ?[]const u8 = null;

        for (balances) |balance_item| {
            if (std.mem.eql(u8, coin_name, balance_item.currency.?)) {
                if (bet_mode == .faucet) {
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
                try stdout.writeAll("Enter chance(example 88.88): ");
                try stdout.flush();
                const chance = try net.input(allocator);
                const chance_n = aritmethic.parseOdds(chance);
                if (dice_game) {
                    const og_chance = if (chance_n != null) chance else "94";
                    bet_response = betting.placeABet(og_dice_url, &client, coin_name, amount, spec_hash, bet_mode, og_chance, is_high, allocator) catch |err| {
                        try stdout.print("Bet didn't work. Error: {any}\n", .{err});
                        try stdout.flush();
                        continue :master_loop;
                    };
                } else {
                    const diff_f: f128 = blk: {
                        if (chance_n) |value| {
                            break :blk value * 100;
                        }
                        try stdout.print("Invalid odds input \"{s}\" -> using default 94.0\n", .{chance});
                        try stdout.flush();
                        break :blk 9400.0;
                    };
                    const diff: u16 = @as(u16, @intFromFloat(diff_f)) - 1;
                    limits.set(bottom, diff);
                    bet_response = betting.placeARangeDiceBet(range_dice_url, &client, coin_name, amount, spec_hash, bet_mode, limits, true, allocator) catch |err| {
                        try stdout.print("Bet didn't work. Error: {any}\n", .{err});
                        try stdout.flush();
                        continue :master_loop;
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
                const goal_balance_str = try net.input(allocator);
                var goal_balance_as_f: f128 = parseFloat(f128, goal_balance_str) catch aritmethic.intToFloat(goal_balance_default);
                const goal_balance_as_int = aritmethic.floatToInt(goal_balance_as_f);
                if (goal_balance_as_int > aritmethic.floatToInt(current_balance_as_f) + 10 * amount_as_int) {
                    goal_balance_as_f = aritmethic.intToFloat(goal_balance_default);
                }
                try stdout.print("Goal: {d:.8} {s}\n", .{ goal_balance_as_f, coin_name });
                try stdout.writeAll("Starting Labouchere run.\n");
                try stdout.flush();

                if (dice_game) {
                    try betting.labouchere(og_dice_url, &client, coin_name, amount, spec_hash, bet_mode, current_balance_as_f, goal_balance_as_f, is_high, dice_game, limits, allocator);
                } else {
                    limits.set(bottom, 4399);
                    try betting.labouchere(range_dice_url, &client, coin_name, amount, spec_hash, bet_mode, current_balance_as_f, goal_balance_as_f, is_high, dice_game, limits, allocator);
                }
            },
            '3', 'F', 'f' => {
                try stdout.print("Current balance: {s} {s}\n", .{ current_as_str.?, coin_name });

                const current_balance_as_f = try parseFloat(f128, current_as_str.?);
                try stdout.writeAll("Enter goal balance: ");
                try stdout.flush();
                const goal_balance_str = try net.input(allocator);
                const goal_balance_as_f: f128 = parseFloat(f128, goal_balance_str) catch aritmethic.add(current_balance_as_f, amount, 3);
                try stdout.writeAll("Enter lower limit: ");
                try stdout.flush();
                const limit_balance_str = try net.input(allocator);
                const limit_balance_as_f: f128 = parseFloat(f128, limit_balance_str) catch aritmethic.sub(current_balance_as_f, 10.0 * amount);
                try stdout.print("Goal: {d:.8} {s}\nLimit: {d:.8} {s}\n", .{ goal_balance_as_f, coin_name, limit_balance_as_f, coin_name });
                try stdout.writeAll("Starting Fibonacci run.\n");
                try stdout.flush();

                if (dice_game) {
                    try betting.fibSeq(og_dice_url, &client, coin_name, amount, spec_hash, bet_mode, current_balance_as_f, goal_balance_as_f, limit_balance_as_f, is_high, dice_game, limits, allocator);
                } else {
                    limits.set(bottom, 4399);
                    try betting.fibSeq(range_dice_url, &client, coin_name, amount, spec_hash, bet_mode, current_balance_as_f, goal_balance_as_f, limit_balance_as_f, is_high, dice_game, limits, allocator);
                }
            },
            '4', 'o', 'O' => {
                const current_balance_as_f = try parseFloat(f128, current_as_str.?);
                try stdout.writeAll("Starting One percent hunt.\n");
                try stdout.flush();

                if (dice_game) {
                    try betting.onePercentHunt(og_dice_url, &client, coin_name, amount, spec_hash, bet_mode, current_balance_as_f, is_high, dice_game, limits, allocator);
                } else {
                    limits.set(bottom, 94);
                    try betting.onePercentHunt(range_dice_url, &client, coin_name, amount, spec_hash, bet_mode, current_balance_as_f, is_high, dice_game, limits, allocator);
                }
            },
            else => {
                try stdout.writeAll("Wrong choice!!!\n");
                try stdout.flush();
                continue :master_loop;
            },
        }
        try stdout.print("--" ** 20 ++ "\n", .{});
        try stdout.print("--" ** 20 ++ "\n", .{});
        try stdout.flush();
    }
}
