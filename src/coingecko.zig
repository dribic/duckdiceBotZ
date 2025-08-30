const std = @import("std");
const net = @import("net.zig");
const aritmethic = @import("arithmetic.zig");

const PricesMap = std.StringHashMap(f128);
const CoinsMap = std.StringHashMap(PricesMap);

pub fn loadCoinMap(allocator: std.mem.Allocator) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(allocator);

    // --- Read file ---
    const file = try std.fs.cwd().openFile("dd-coins.json", .{ .mode = .read_only });
    defer file.close();

    const json_bytes = try file.readToEndAlloc(allocator, 8192);
    defer allocator.free(json_bytes);

    // --- Parse JSON ---
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_bytes, .{});
    defer parsed.deinit();

    if (parsed.value != .object) {
        return error.InvalidJson;
    }

    var it = parsed.value.object.iterator();
    while (it.next()) |entry| {
        const symbol = entry.key_ptr.*;
        const cg_name_value = entry.value_ptr.*;
        switch (cg_name_value) {
            .string => |cg_name| {
                try map.put(symbol, cg_name);
            },
            else => {},
        }
    }

    return map;
}

pub fn calculateMinimum(allocator: std.mem.Allocator, client: *std.http.Client, dd_coin_name: []const u8) !u128 {
    var coingecko_names = try loadCoinMap(allocator);
    defer coingecko_names.deinit();

    const coin = coingecko_names.get(dd_coin_name) orelse dd_coin_name;

    const url = if (std.mem.eql(u8, coin, "bitcoin"))
        try std.fmt.allocPrint(allocator, "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd", .{})
    else
        try std.fmt.allocPrint(allocator, "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,{s}&vs_currencies=usd", .{coin});
    defer allocator.free(url);

    const json_data = try net.getCoingecko(url, client, allocator);

    // --- Parse into JSON Value ---
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_data, .{});
    defer parsed.deinit();
    const root = parsed.value;

    // --- Build CoinsMap ---
    var coins = CoinsMap.init(allocator);
    defer {
        var it = coins.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(); // free inner PricesMap
        }
        coins.deinit();
    }

    if (root != .object) return error.InvalidJson;

    var coin_it = root.object.iterator();
    while (coin_it.next()) |coin_entry| {
        const coin_name = coin_entry.key_ptr.*;
        const coin_value = coin_entry.value_ptr.*;

        if (coin_value != .object) continue;

        var prices = PricesMap.init(allocator);

        var price_it = coin_value.object.iterator();
        while (price_it.next()) |price_entry| {
            const currency = price_entry.key_ptr.*;
            const price_value = price_entry.value_ptr.*;

            const as_f128 = switch (price_value) {
                .float => |x| x,
                .integer => |x| @as(f128, @floatFromInt(x)),
                else => continue, // ignore non-numbers
            };

            try prices.put(currency, as_f128);
        }

        try coins.put(coin_name, prices);
    }

    const btc_price: f128 = getUsdPrice(&coins, "bitcoin") orelse 0;

    if (btc_price == 0) {
        return error.CoinGeckoUnavailable;
    }

    const other_coin_price = getUsdPrice(&coins, coin);

    if (other_coin_price) |usd| {
        return aritmethic.satoshiEquivalent(btc_price, usd);
    }

    return error.CoinNotFound;
}

fn getUsdPrice(map: *const CoinsMap, name: []const u8) ?f128 {
    if (map.get(name)) |prices| {
        return prices.get("usd");
    }
    return null;
}
