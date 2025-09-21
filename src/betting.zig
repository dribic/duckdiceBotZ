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
const aritmethic = @import("arithmetic.zig");

pub fn fibSeq(
    url: []const u8,
    client: *std.http.Client,
    currency: []const u8,
    bet_value: f128,
    faucet: bool,
    starting_balance: f128,
    goal_balance: f128,
    limit_balance: f128,
    is_high: bool,
    dice_game: bool,
    limits: types.Limit,
    allocator: std.mem.Allocator,
) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var fib_list: std.ArrayList(u16) = .empty;
    defer fib_list.deinit(allocator);

    const factor: f128 = if (faucet) 1.2045 else 1.25;
    try fib_list.appendNTimes(allocator, 1, 2);

    var current_balance: f128 = starting_balance;

    m_loop: while (current_balance < goal_balance and current_balance > limit_balance) {
        while (fib_list.items.len > 1) {
            const bet_amount: f128 = bet_value * @as(f128, @floatFromInt(fib_list.items[fib_list.items.len - 1]));
            if (aritmethic.sub(current_balance, bet_amount) < limit_balance) break :m_loop;
            const bet_response = if (dice_game) try placeABet(url, client, currency, bet_amount, faucet, "44", is_high, allocator) else try placeARangeDiceBet(url, client, currency, bet_amount, faucet, limits, true, allocator);
            const bet_roll = bet_response.number.?;
            const bet_result = bet_response.result;

            try stdout.print("Current bet amount: {d:.8} {s}\n", .{ bet_amount, currency });
            try stdout.print("Current balance: {d:.8} {s}\nGoal: {d:.8} {s}\n", .{ current_balance, currency, goal_balance, currency });
            if (!dice_game) {
                try stdout.print("Range: {d}-{d}\n", .{ limits.bottom(), limits.top() });
            }
            try stdout.print("Roll: {d}\n", .{bet_roll});

            if (bet_result) {
                current_balance = aritmethic.add(current_balance, bet_amount, factor);
                _ = fib_list.pop();
                _ = fib_list.pop();
                try stdout.writeAll("Success!✅\n");
                try stdout.flush();
                if (current_balance > goal_balance) return;
            } else {
                current_balance = aritmethic.sub(current_balance, bet_amount);
                const next_fib = fib_list.items[fib_list.items.len - 2] + fib_list.items[fib_list.items.len - 1];
                try fib_list.append(allocator, next_fib);
                try stdout.writeAll("Failure!☯ \n");
                try stdout.flush();
                if (current_balance < limit_balance) return;
            }
            try stdout.print("Current fibonnacci list:\n[ ", .{});
            for (fib_list.items) |ele| {
                try stdout.print("{d} ", .{ele});
            }
            try stdout.print("]\n", .{});
            try stdout.flush();
        }

        fib_list.clearRetainingCapacity();
        try fib_list.appendNTimes(allocator, 1, 2);
    }
}

fn safety(allocator: std.mem.Allocator, bet_slip: *std.ArrayList(f128), base_value: u128) !void {
    var sum: u128 = 0;
    for (bet_slip.items) |bet_value| {
        const number = aritmethic.floatToInt(bet_value);
        sum += number;
    }
    try bet_slip.ensureTotalCapacity(allocator, 3 * bet_slip.items.len); // Pre-allocating large capacity to avoid constant allocations
    bet_slip.clearRetainingCapacity();

    while (sum != 0) {
        for (1..3) |multi| {
            const element_int: u128 = base_value * @as(u128, multi);
            if (element_int > sum) {
                break;
            }
            const element_f: f128 = aritmethic.intToFloat(element_int);
            try bet_slip.append(allocator, element_f);
            sum -= element_int;
        }
    }

    std.mem.sort(f128, bet_slip.items, {}, std.sort.asc(f128));
}

pub fn labouchere(
    url: []const u8,
    client: *std.http.Client,
    currency: []const u8,
    element_f: f128,
    faucet: bool,
    starting_balance: f128,
    goal_balance: f128,
    is_high: bool,
    dice_game: bool,
    limits: types.Limit,
    allocator: std.mem.Allocator,
) !void {
    const element_int = aritmethic.floatToInt(element_f);
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var number_of_bets: u16 = 0;
    var number_of_wins: u16 = 0;
    var number_of_loses: u16 = 0;
    var total_value_betted: f128 = 0;
    var betting_seq = std.ArrayList(f128){};
    defer betting_seq.deinit(allocator);

    try betting_seq.ensureTotalCapacity(allocator, 15); // Pre-allocating slightly larger capacity, because bet odds less than 50%
    try betting_seq.appendNTimes(allocator, element_f, 10);
    const factor: f128 = if (faucet) 1.2045 else 1.25;

    try stdout.print("Betting slip:\n[ ", .{});
    for (betting_seq.items) |ele| {
        try stdout.print("{d:.8} ", .{ele});
    }
    try stdout.print("]\n", .{});
    try stdout.flush();

    var current_balance: f128 = starting_balance;

    while (current_balance < goal_balance) {
        if (betting_seq.items.len == 0) {
            const msgs = [_][]const u8{ "🖖 Sequence collapsed... initiating Vulcan logic reboot.", "✨ The Force has balanced... resetting Jedi sequence.", "🌀 Wormhole unstable — recalibrating Stargate sequence.", "🚀 Sequence fell out of warp — reinitializing at starbase.", "💫 Hyperdrive misfire! Restoring sequence from backup crystals.", "⚡ Phaser overload detected — diverting power to new sequence.", "👽 Borg interference detected — sequence has been assimilated, regenerating...", "🌌 Death Star superlaser misfire — reconstructing sequence from debris.", "🔮 ZPM fluctuations detected — Stargate dialing new sequence.", "📡 Subspace anomaly detected — rematerializing betting sequence.", "🛰️ Shields at 10%! Diverting power to sequence restoration.", "🕳️ Sequence fell into a black hole... retrieving via temporal anomaly.", "🤖 R2-D2 rerouted power — rebooting sequence systems.", "🪐 Sequence lost in the Gamma Quadrant... calling USS Defiant for backup." };

            const idx = std.crypto.random.intRangeLessThan(usize, 0, msgs.len);

            try stdout.print("{s}\n", .{msgs[idx]});
            try stdout.flush();

            try betting_seq.appendNTimes(allocator, element_f, 10);
        }
        const first_as_int = aritmethic.floatToInt(betting_seq.items[0]);

        const final_idx = betting_seq.items.len - 1;
        var bet_amount: f128 = if (final_idx == 0) betting_seq.items[0] else aritmethic.add(betting_seq.items[0], betting_seq.items[final_idx], 1.0);
        try stdout.print("Current bet amount: {d:.8} {s}\n", .{ bet_amount, currency });
        const bet_as_int = aritmethic.floatToInt(bet_amount);
        var lowering: bool = false;
        while (aritmethic.add(current_balance, bet_amount, factor) > goal_balance and bet_amount > element_f) {
            lowering = true;
            try stdout.print("Lowering bet amount by {d:.8} for safety!\n", .{element_f});
            try stdout.flush();
            bet_amount = aritmethic.sub(bet_amount, element_f);
        }
        if (lowering) {
            try stdout.print("New bet amount: {d:.8} {s}\n", .{ bet_amount, currency });
        }
        try stdout.flush();

        // Safety
        if (bet_as_int >= element_int * 11 or first_as_int >= element_int * 4) {
            try stdout.print("⚠️ Safety triggered, reconstructing slip... cooling down for 5 seconds.\n", .{});
            try stdout.flush();
            std.Thread.sleep(5 * std.time.ns_per_s);
            try safety(allocator, &betting_seq, element_int);
            continue;
        }

        if (bet_amount > current_balance) {
            try stdout.print("Balance too low!\n", .{});
            try stdout.flush();
            return;
        }

        const bet_response = if (dice_game) try placeABet(url, client, currency, bet_amount, faucet, "44", is_high, allocator) else try placeARangeDiceBet(url, client, currency, bet_amount, faucet, limits, true, allocator);
        number_of_bets += 1;
        total_value_betted = aritmethic.add(total_value_betted, bet_amount, 1.0);
        const bet_roll = bet_response.number.?;
        const bet_result = bet_response.result;

        if (!dice_game) {
            try stdout.print("Range: {d}-{d}\n", .{ limits.bottom(), limits.top() });
        }
        try stdout.print("Roll: {d}\n", .{bet_roll});

        if (bet_result) {
            number_of_wins += 1;
            current_balance = aritmethic.add(current_balance, bet_amount, factor);
            if (lowering) {
                var bet_amount_int: u128 = aritmethic.floatToInt(bet_amount);
                while (bet_amount_int != 0) {
                    var last_element_int: u128 = aritmethic.floatToInt(betting_seq.items[betting_seq.items.len - 1]);
                    if (last_element_int > bet_amount_int) {
                        last_element_int -= bet_amount_int;
                        bet_amount_int = 0;
                        betting_seq.items[betting_seq.items.len - 1] = aritmethic.intToFloat(last_element_int);
                    } else {
                        bet_amount_int -= last_element_int;
                        _ = betting_seq.pop();
                    }
                }
            } else {
                _ = betting_seq.pop();
                _ = betting_seq.orderedRemove(0);
            }
            try stdout.writeAll("Success!✅\n");
            try stdout.flush();
        } else {
            number_of_loses += 1;
            current_balance = aritmethic.sub(current_balance, bet_amount);
            try betting_seq.append(allocator, bet_amount);
            try stdout.writeAll("Failure!☯ \n");
            try stdout.flush();
        }

        try stdout.print("Current balance: {d:.8} {s}\nGoal: {d:.8} {s}\nNumber of bets: {d}, Number of wins: {d}, Number of loses: {d}.\n", .{ current_balance, currency, goal_balance, currency, number_of_bets, number_of_wins, number_of_loses });
        try stdout.print("Current betting slip:\n[ ", .{});
        for (betting_seq.items) |ele| {
            try stdout.print("{d:.8} ", .{ele});
        }
        try stdout.print("]\n", .{});
        try stdout.flush();
    }
}

pub fn placeABet(
    url: []const u8,
    client: *std.http.Client,
    currency: []const u8,
    amount_f: f128,
    faucet: bool,
    chance: []const u8,
    is_high: bool,
    allocator: std.mem.Allocator,
) !types.Bet {
    var buf: [64]u8 = undefined;
    const amount = try std.fmt.bufPrint(&buf, "{d:.8}", .{amount_f});

    const bet = types.OriginalDicePlayRequest{ .amount = amount, .chance = chance, .symbol = currency, .isHigh = is_high, .faucet = faucet };

    var body_writter: std.io.Writer.Allocating = .init(allocator);
    const writer = &body_writter.writer;
    defer body_writter.deinit();

    try std.json.Stringify.value(bet, .{ .emit_null_optional_fields = false, .whitespace = .minified }, writer);

    const slice = body_writter.written();

    const response = try net.post(url, slice, client, allocator);
    var result = try std.json.parseFromSlice(types.DicePlayResponse, allocator, response, .{ .ignore_unknown_fields = true });
    defer result.deinit();

    return result.value.bet.?;
}

pub fn placeARangeDiceBet(
    url: []const u8,
    client: *std.http.Client,
    currency: []const u8,
    amount_f: f128,
    faucet: bool,
    limits: types.Limit,
    is_in: bool,
    allocator: std.mem.Allocator,
) !types.Bet {
    var buf: [64]u8 = undefined;
    const amount = try std.fmt.bufPrint(&buf, "{d:.8}", .{amount_f});

    const bet = types.RangeDicePlayRequest{ .amount = amount, .range = &limits.range, .symbol = currency, .isIn = is_in, .faucet = faucet };

    var body_writter: std.io.Writer.Allocating = .init(allocator);
    const writer = &body_writter.writer;
    defer body_writter.deinit();

    try std.json.Stringify.value(bet, .{ .emit_null_optional_fields = false, .whitespace = .minified }, writer);

    const slice = body_writter.written();

    const response = try net.post(url, slice, client, allocator);
    var result = try std.json.parseFromSlice(types.DicePlayResponse, allocator, response, .{ .ignore_unknown_fields = true });
    defer result.deinit();

    return result.value.bet.?;
}
