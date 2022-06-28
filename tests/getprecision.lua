#!/usr/bin/env lua

-- utility to check whether the current build of lua uses floats or doubles

if 0x1000000 == 0x1000001 then
    print(32);
else
    print(64);
end
