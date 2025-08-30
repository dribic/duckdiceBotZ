const std = @import("std");

const DECIMAL_MULTI: f128 = 100_000_000;

pub fn satoshiEquivalent(btc_price_usd: f128, other_price_usd: f128) u128 {
    const satoshi_value = btc_price_usd / DECIMAL_MULTI;
    const equivalent = satoshi_value / other_price_usd;

    return floatToInt(equivalent);
}

pub fn floatToInt(number: f128) u128 {
    const floatie = number * DECIMAL_MULTI;
    const result: u128 = @intFromFloat(floatie);
    return result;
}

pub fn intToFloat(number: u128) f128 {
    const floatie: f128 = @floatFromInt(number);
    const result = floatie / DECIMAL_MULTI;
    return result;
}

pub fn sub(a: f128, b: f128) f128 {
    const a_as_int: u128 = floatToInt(a);
    const b_as_int: u128 = floatToInt(b);
    const diff = a_as_int - b_as_int;

    return intToFloat(diff);
}

pub fn add(a: f128, b: f128, factor: f128) f128 {
    const a_int: u128 = floatToInt(a);
    const b_int: u128 = floatToInt(b);
    var b_scaled_int: u128 = b_int;
    if (factor != 1.0) {
        const factor_int: u128 = @intFromFloat(factor * 10_000.0); // 4 decimals → scale factor to int
        b_scaled_int = (b_int * factor_int) / 10_000;
    }
    const sum_int: u128 = a_int + b_scaled_int;

    return intToFloat(sum_int);
}

pub fn multiply(a: f128, b: f128) f128 {
    const a_int: u128 = floatToInt(a);
    const b_int: u128 = @intFromFloat(b * 10_000.0); // 4 decimals
    const result_int: u128 = (a_int * b_int) / 10_000;

    return intToFloat(result_int);
}
