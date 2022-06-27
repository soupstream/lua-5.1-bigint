#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local arr = {};
local littleEndian = testbase.toboolean(arg[1]);
for i = 2, #arg, 1 do
    arr[i - 1] = tonumber(arg[i]);
end
local big = bigint.FromArray(arr, littleEndian);
print(big:ToHex());
testbase.check();
