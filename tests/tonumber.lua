#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local big = bigint(arg[1]);
testbase.register();
local result = big:ToNumber();
print(result);
testbase.check();
