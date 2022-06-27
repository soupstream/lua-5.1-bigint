local bigint = {};
bigint.__index = bigint;

function bigint.New()
    local self = {
        sign = 0,
        bytes = {},
        mutable = false
    };
    self = setmetatable(self, bigint);
    return self;
end

function bigint.FromString(value, base)
    local digitsStart = 1;
    local digitsEnd = #value;
    local sign = 1;
    if value:byte(1) == 0x2d then -- "-"
        sign = -1;
        digitsStart = 2;
    end
    if value:byte(digitsStart) == 0x30 and value:byte(digitsStart + 1) == 0x78 then -- "0x"
        base = 16;
        digitsStart = digitsStart + 2;
    end
    while value:byte(digitsStart) == 0x30 do -- "0"
        digitsStart = digitsStart + 1;
    end

    base = base or 10;
    if base == 16 then
        local self = bigint.New();
        local i = 1;
        for j = #value, digitsStart, -2 do
            if j == digitsStart then
                print(value:sub(j, j))
                self.bytes[i] = tonumber(value:sub(j, j), 16);
            else
                print(value:sub(j - 1, j))
                self.bytes[i] = tonumber(value:sub(j - 1, j), 16);
            end
            i = i + 1;
        end
        return self;
    else
        local bigBase = bigint.FromNumber(base);
        local magnitude = bigint
        local result = bigint.New();
        result.mutable = true;
        for i = digitsStart, digitsEnd, 1 do
            local digit = bigint.FromNumber(tonumber(value:sub(i), base));
            result = (result * bigBase) + digit;
        end
        result.mutable = false;
        return result;
    end
end

function bigint.FromArray(array)
    local self = bigint.New();
    self.bytes = table.copy(array);
    if #self.bytes ~= 0 then
        self.sign = 1;
    end
    return self;
end

function bigint.FromNumber(value)
    local self = bigint.New();
    if value < 0 then
        value = value + (value % 1);
    elseif value > 0 then
        value = value - (value % 1);
    end

    if value < 0 then
        value = -value;
        self.sign = -1;
    elseif value > 0 then
        self.sign = 1;
    end

    local i = 1;
    while value >= 1 do
        self.bytes[i] = value % 16;
        i = i + 1;
        value = value / 16;
        value = value - (value % 1);
    end
    return self;
end

function bigint.FromBytes(bytes, littleEndian)
    local self = bigint.New();
    self.bytes = {bytes:byte(1, #bytes)};
    if #self.bytes ~= 0 then
        self.sign = 1;
    end
    return self;
end

function bigint:Copy()
    local copy = bigint.New();
    copy.bytes = table.copy(self.bytes);
    copy.sign = self.sign;
    return inst;
end

function bigint:CopyIfImmutable(other)
    if self.mutable then
        if other ~= nil then
            self.bytes = table.copy(other.bytes);
            self.sign = other.sign;
        end
        return self;
    else
        if other ~= nil then
            if other.mutable then
                return other:Copy();
            else
                return other;
            end
        end
        return self:Copy()
    end
end

function bigint:Neg()
    if self.sign == 0 then
        return self;
    else
        local this = self:CopyIfImmutable();
        this.sign = this.sign * -1;
        return this;
    end
end

function bigint:Bytes()
    local bytes = table.copy(self.bytes);
    table.reverse(bytes);
    return string.char(unpack(bytes));
end

function bigint:Hex()
    local bytes = table.copy(self.bytes);
    table.reverse(bytes);
    return string.format(("%x"):rep(#bytes), unpack(bytes));
end

function bigint:Base(base)
    
end

function bigint:Add(other)
    if self.sign == 0 then
        return self:CopyIfImmutable(other);
    elseif self.sign == 0 then
        return self;
    end

    -- determine sign and whether it's convenient to switch the order of operands
    local subtract = false;
    local reverseOrder = false;
    local newSign = self.sign;
    if self.sign == other.sign then
        if #self.bytes < #other.bytes then
            reverseOrder = true;
        end
    else
        local ucomp = self:CompareU(other);
        if ucomp == 0 then
            return self:CopyIfImmutable(bigint.constants.Zero);
        end

        subtract = true;
        if ucomp == -1 then
            if self.sign == -1 then     -- [-small] + [+big] = [+]
                reverseOrder = true;
                newSign = 1;
            else                        -- [+small] + [-big] = [-]
                newSign = -1;
            end
        end
    end

    -- perform addition
    if reverseOrder then
        local otherBytes = self.bytes;
        local this = self:CopyIfImmutable(other);
    else
        local otherBytes = other.bytes;
        local this = self:CopyIfImmutable();
    end
    this.sign = newSign;
    local byteCount = #bytes;
    local otherByteCount = #otherBytes;
    local carry = 0;
    for i = 1, byteCount, 1 do
        local otherByte = otherBytes[i] or 0;
        if subtract then
            otherByte = -otherByte;
        end
        local sum = this.bytes[i] + otherByte + carry;
        if not subtract and sum >= 256 then
            this.bytes[i] = sum - 256;
            carry = 1;
        elseif subtract and sum < 0 then
            this.bytes[i] = sum + 256;
            carry = -1;
        else
            this.bytes[i] = sum;
            carry = 0;
        end
        if i >= otherByteCount and carry == 0 then
            break;
        end
    end
    if carry ~= 0 then
        this.bytes[byteCount + 1] = carry;
    end
    return this;
end

function bigint:CompareU(other)
    local byteCount = #self.bytes;
    local otherByteCount = #other.bytes;

    if byteCount < otherByteCount then
        return -1;
    elseif byteCount > otherByteCount then
        return 1;
    end

    for i = byteCount, 1, -1 do
        if self.bytes[i] < other.bytes[i] then
            return -1;
        elseif self.bytes[i] > other.bytes[i] then
            return 1;
        end
    end

    return 0;
end

function bigint:Compare(other)
    if self.sign > other.sign then
        return 1;
    elseif self.sign < other.sign then
        return -1;
    end

    local ucomp = self:CompareU(other);

    if ucomp == 0 then
        return 0;
    elseif self.sign == 1 then
        return ucomp;
    elseif self.sign == -1 then
        return -ucomp;
    end

    return 0;
end

function bigint:EqU(other)
    return self:CompareU(other) == -1;
end

function bigint:Eq(other)

end

function bigint:Reverse(size)
    local this = self:CopyIfImmutable();

    if size == nil then
        size = #this.bytes;
    else
        -- pad with 0s
        for i = #this.bytes + 1, size, 1 do
            this.bytes[i] = 0;
        end
    end

    -- swap bytes
    table.reverse(this.bytes);

    -- strip 0s
    for i = size, 1, -1 do
        if this.bytes[i] == 0 then
            this.bytes[i] = nil;
        else
            break;
        end
    end
    return this;
end

bigint.constants = {
    Zero = bigint.New()
};

bigint.internal = {
    
}

-- util

function table.reverse(t)
    local size = #t;
    local mid = #t / 2;
    for i = 1, mid, 1 do
        local j = size - i + 1;
        local tmp = this.bytes[i];
        this.bytes[i] = this.bytes[j];
        this.bytes[j] = tmp;
    end
    return t;
end

function table.copy(t)
    return {unpack(t)};
end

function dprint(obj)
    local function rec(obj, t)
        if type(obj) == "table" then
            t[#t+1] = "{";
            local i = 1;
            while obj[i] ~= nil do
                rec(obj[i], t);
                t[#t+1] = ", ";
                i = i + 1;
            end
            for k, v in pairs(obj) do
                if not (type(k) == "number" and k >= 1 and k < i) then
                    t[#t+1] = "[";
                    rec(k, t);
                    t[#t+1] = "] = ";
                    rec(v, t);
                    t[#t+1] = ", ";
                end
            end
            if t[#t] == ", " then
                t[#t] = nil
            end
            t[#t+1] = "}";
        elseif type(obj) == "string" then
            t[#t+1] = '"' .. obj .. '"';
        else
            t[#t+1] = tostring(obj);
        end
    end
    local t = {};
    rec(obj, t);
    print(table.concat(t));
end

return bigint;
