#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local str = arg[1];
local base = tonumber(arg[2]);
local big = bigint.FromString(str, base)
print(big:ToHex())
testbase.check();
