#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local unpack = unpack or table.unpack;

local bits = {};
for i = 2, #arg, 1 do
    bits[i - 1] = tonumber(arg[i]);
end
local big = bigint(arg[1]);
testbase.register();
local result = big:UnsetBits(unpack(bits));
print(result:ToHex());
testbase.check();
