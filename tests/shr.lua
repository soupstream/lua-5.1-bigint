#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local big = bigint(arg[1]);
local shift = bigint(arg[2]);
testbase.register();
local result = big:Shr(shift);
print(result:ToHex())
testbase.check();
