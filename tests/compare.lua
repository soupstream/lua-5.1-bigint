#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local op = arg[1];
local big1 = bigint(arg[2]);
local big2 = bigint(arg[3]);
testbase.register();
local result = big1:CompareOp(big2, op);
print(result);
testbase.check();
