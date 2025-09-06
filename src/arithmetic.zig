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

const DECIMAL_MULTI: f128 = 100_000_000;

pub fn addOnePercent(number: u128) u128 {
    if (number < 100) {
        return number + 1;
    }
    const one_percent: u128 = number / 100;
    return number + one_percent;
}

pub fn satoshiEquivalent(btc_price_usd: f128, other_price_usd: f128) u128 {
    const satoshi_value = btc_price_usd / DECIMAL_MULTI;
    const equivalent = satoshi_value / other_price_usd;

    const number = floatToInt(equivalent);
    return addOnePercent(number);
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
