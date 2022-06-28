#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local big = bigint(arg[1]);
local size = bigint(arg[2]);
testbase.register();
local result = big:CastUnsigned(size);
print(result:ToDec())
testbase.check();
