#!/usr/bin/env lua

local bigint, testbase = require("testbase")();

local binopMap = {
    ["+"] = bigint.Add,
    ["-"] = bigint.Sub,
    ["*"] = bigint.Mul,
    ["/"] = bigint.Div,
    ["%"] = bigint.Mod,
    ["&"] = bigint.Band,
    ["|"] = bigint.Bor,
    ["^"] = bigint.Bxor,
    ["pow"] = bigint.Pow,
    ["<<"] = bigint.Shl,
    [">>"] = bigint.Shr,
};

local comparatorMap = {
    ["="] = bigint.Eq,
    ["<"] = bigint.Lt,
    [">"] = bigint.Gt,
    ["<="] = bigint.Le,
    [">="] = bigint.Ge,
};

local unopMap = {
    ["-"] = bigint.Unm,
    ["abs"] = bigint.Unm,
};

local opMapMap = {
    [1] = unopMap,
    [2] = binopMap,
};

local function executeSexp(sexp)
    local symbol = sexp[1];
    local operandCount = #sexp - 1;
    local operands = {};
    for i = 1, operandCount, 1 do
        local operand = sexp[i + 1];
        if type(operand) == "table" then
            operand = executeSexp(operand);
        else
            operand = bigint.Construct(operand);
        end
        operands[i] = operand;
    end
    local op = opMapMap[operandCount][symbol];
    return op(unpack(operands));
end

local sexpStr = arg[1];
local f, err = loadstring("return " .. sexpStr:gsub("'", '"'));
if err ~= nil then
    print(err);
else
    local sexp = f();
    local result = executeSexp(sexp);
    if type(result) == "table" then
        print(result:ToHex());
    else
        print(result);
    end
end
testbase.check();
