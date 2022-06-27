#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local big1 = bigint(arg[1]);
local big2 = bigint(arg[2]);
testbase.register();
local result = big1:Bor(big2);
print(result:ToHex())
testbase.check();
