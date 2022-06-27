#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local bit = tonumber(arg[2]);
local big = bigint(arg[1]);
testbase.register();
local result = big:GetBit(bit);
print(result);
testbase.check();
