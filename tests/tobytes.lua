#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local big = bigint(arg[1]);
local size = tonumber(arg[2]);
local littleEndian = testbase.toboolean(arg[3]);
testbase.register();
local result = big:ToBytes(size, littleEndian);
local str = table.concat({string.byte(result, 1, #result)}, ",");
print(str);
testbase.check();
