#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local big = bigint(arg[1]);
testbase.register();
local result = big:Bnot();
print(result:ToHex())
testbase.check();
