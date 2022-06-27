#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local num = arg[1];
local base = 10;
local sign = 1;
if num:sub(1, 1) == "-" then
    sign = -1;
    num = num:sub(2);
end

if num:sub(1, 2) == "0x" then
    base = 16;
    num = num:sub(3);
end

num = tonumber(num, base) * sign;
local big = bigint.FromNumber(num)
print(big:ToHex())
testbase.check();
