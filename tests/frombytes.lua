#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local arr = {};
for i = 1, #arg, 1 do
    arr[i] = tonumber(arg[i]);
end
local bytes = string.char(unpack(arr))
local big = bigint.FromBytes(bytes);
print(big:ToHex());
testbase.check();
