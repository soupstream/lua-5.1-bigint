#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local unpack = unpack or table.unpack;

local arr = {};
local littleEndian = testbase.toboolean(arg[1]);
for i = 2, #arg, 1 do
    arr[i - 1] = tonumber(arg[i]);
end
local bytes = string.char(unpack(arr))
local big = bigint.FromBytes(bytes, littleEndian);
print(big:ToHex());
testbase.check();
