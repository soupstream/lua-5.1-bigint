#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local base = tonumber(arg[2]) or 10;
local big = bigint(arg[1]);
testbase.register();
local result = big:ToBase(base);
print(result);
testbase.check();
