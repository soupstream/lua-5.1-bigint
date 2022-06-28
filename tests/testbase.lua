local testbase = {};
local origEnv;
local bigint;
local importPath = "../bigint";
function testbase.dtostring(obj)
    local function rec(obj, t, visited, level)
        local indent = function()
            t[#t+1] = "\n" .. ("  "):rep(level);
            return t[#t];
        end
        if type(obj) == "table" and not visited[obj] then
            visited[obj] = true;
            t[#t+1] = "{";
            level = level + 1;
            indent();
            local i = 1;
            while obj[i] ~= nil do
                rec(obj[i], t, visited, level);
                t[#t+1] = ",";
                indent();
                i = i + 1;
            end
            for k, v in pairs(obj) do
                if not (type(k) == "number" and k >= 1 and k < i) then
                    t[#t+1] = "[";
                    rec(k, t, visited, level);
                    t[#t+1] = "] = ";
                    rec(v, t, visited, level);
                    t[#t+1] = ",";
                    indent();
                end
            end
            if indent() == t[#t] then
                t[#t] = nil
                t[#t] = nil
            end
            if t[#t] == "," then
                t[#t] = nil
            end
            level = level - 1;
            if t[#t] ~= "{" then
                indent()
            end
            t[#t+1] = "}";
        elseif type(obj) == "string" then
            t[#t+1] = '"' .. obj .. '"';
        else
            t[#t+1] = tostring(obj);
        end
    end
    local t = {};
    rec(obj, t, {}, 0);
    return table.concat(t);
end
function testbase.dprint(obj)
    print(testbase.dtostring(obj));
end
function testbase.toboolean(str)
    if str == nil then
        return nil;
    end
    str = str:lower();
    if str == "true" then
        return true;
    elseif str == "false" then
        return false;
    else
        error("not a bool");
    end
end
function testbase.getEnv()
    -- nil out package table to make checkEnv simpler
    local package = package;
    _G["package"] = nil;
    local env = testbase.dtostring(_G);
    _G["package"] = package;
    return env;
end
function testbase.checkEnv()
    local env = testbase.getEnv();
    if env ~= origEnv then
        local file = io.open("/tmp/origEnv.txt", "w");
        file:write(origEnv);
        file:close();
        file = io.open("/tmp/env.txt", "w");
        file:write(env);
        file:close();
        error("env mismatch");
    end
end

-- args: variable names as strings
testbase.registeredBigInts = {};
function testbase.register(...)
    local arg = {...};
    local argMap = {};
    for i, v in ipairs(arg) do
        if not bigint.IsBigInt(v) then
            error("not a bigint");
        end
        argMap[tostring(v)] = true;
    end
    local didRegister = false;
    local i = 1;
    repeat
        local name, value = debug.getlocal(2, i);
        if bigint.IsBigInt(value) and (#arg == 0 or argMap[tostring(value)]) then
            testbase.registeredBigInts[name] = value:Copy();
            didRegister = true;
        end
        i = i + 1;
    until name == nil;

    if not didRegister then
        error("no bigints registered");
    end
end
function testbase.checkMutation(level)
    local localMap = {};
    local i = 1;
    repeat
        local name, value = debug.getlocal(level or 2, i);
        if bigint.IsBigInt(value) then
            localMap[name] = value;
        end
        i = i + 1;
    until name == nil;
    for name, origValue in pairs(testbase.registeredBigInts) do
        local value = localMap[name];
        if not origValue:Eq(value) then
            error("bigint " .. name .. " mutated: " .. origValue:ToHex() .. " ~= " .. value:ToHex());
        end
    end
end
function testbase.check()
    testbase.checkMutation(3);
    testbase.checkEnv();
end

package.path = "../?.lua;" .. package.path;
origEnv = testbase.getEnv();

bigint = require(importPath);
return function() return bigint, testbase end

