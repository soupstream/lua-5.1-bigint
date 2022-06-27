local function bigint_module()

local bigint = {};

--##### FORWARD DECLARATIONS #####--

local bigint_mt;
local bigint_digits;
local bigint_comparatorMap;
local table_reverse;
local table_copy;

--##### MODULE FUNCTIONS #####--

local math_floor = math.floor;
local math_ceil = math.ceil;
local table_concat = table.concat;
local string_sub = string.sub;
local string_byte = string.byte;
local string_char = string.char;
local string_format = string.format;

--##### CONSTRUCTORS #####--

function bigint.New()
    local self = {
        sign = 0,
        bytes = {},
        mutable = false
    };
    self = setmetatable(self, bigint_mt);
    return self;
end

function bigint.Construct(value, base)
    if type(value) == "string" then
        return bigint.FromString(value, base);
    elseif type(value) == "number" then
        return bigint.FromNumber(value);
    elseif type(value) == "table" then
        return bigint.FromArray(value);
    end
end

-- parse integer from a string
function bigint.FromString(value, base)
    local self = bigint.New();
    self.sign = 1;
    local digitsStart = 1;
    local digitsEnd = #value;
    if string_byte(value, digitsStart) == 0x2d then -- "-"
        self.sign = -1;
        digitsStart = digitsStart + 1;
    end
    if string_byte(value, digitsStart) == 0x30 then -- "0"
        digitsStart = digitsStart + 1;
        local prefix = string_byte(value, digitsStart);
        if (base == nil or base == 16) and prefix == 0x78 then      -- "x"
            base = 16;
            digitsStart = digitsStart + 1;
        elseif (base == nil or base == 2) and prefix == 0x62 then   -- "b"
            base = 2;
            digitsStart = digitsStart + 1;
        end
    end
    while string_byte(value, digitsStart) == 0x30 do -- "0"
        digitsStart = digitsStart + 1;
    end
    if digitsStart > digitsEnd then
        self.sign = 0;
        return self;
    end

    base = base or 10;
    if base == 2 or base == 16 then
        -- fast bin/hex parser
        local width = 8;
        if base == 16 then
            width = 2;
        end
        local i = 1;
        for j = digitsEnd, digitsStart, -width do
            if j - width + 1 <= digitsStart then
                self.bytes[i] = tonumber(string_sub(value, digitsStart, j), base);
            else
                self.bytes[i] = tonumber(string_sub(value, j - width + 1, j), base);
            end
            i = i + 1;
        end
        return self;
    else
        -- general parser
        local carry = 0;
        for i = digitsStart, digitsEnd, 1 do
            -- multiply by base
            local carry = 0;
            local j = 1;
            while self.bytes[j] ~= nil or carry ~= 0 do
                local product = (self.bytes[j] or 0) * base + carry;
                self.bytes[j] = product % 256;
                carry = math_floor(product / 256);
                j = j + 1;
            end

            -- add digit
            j = 1;
            carry = tonumber(string_sub(value, i, i), base);
            while carry ~= 0 do
                local sum = (self.bytes[j] or 0) + carry;
                self.bytes[j] = sum % 256;
                carry = math_floor(sum / 256);
                j = j + 1;
            end
        end
        return self;
    end
end

function bigint.FromArray(array)
    local self = bigint.New();
    self.bytes = table_copy(array);
    if #self.bytes ~= 0 then
        self.sign = 1;
    end
    return self;
end

function bigint.FromNumber(value)
    local self = bigint.New();
    if value < 0 then
        value = math_ceil(value);
        if value ~= 0 then
            value = -value;
            self.sign = -1;
        end
    elseif value > 0 then
        value = math_floor(value);
        if value ~= 0 then
            self.sign = 1;
        end
    end

    local i = 1;
    while value > 0 do
        self.bytes[i] = value % 256;
        i = i + 1;
        value = math_floor(value / 256);
    end
    return self;
end

function bigint.FromBytes(bytes, littleEndian)
    local self = bigint.New();
    self.bytes = {string_byte(bytes, 1, #bytes)};
    if #self.bytes ~= 0 then
        self.sign = 1;
    end
    return self;
end

--##### ARITHMETIC OPERATORS #####--

function bigint:Unm()
    if self.sign == 0 then
        return self;
    else
        local this = self:CopyIfImmutable();
        this.sign = -this.sign;
        return this;
    end
end

function bigint:Abs()
    if self.sign >= 0 then
        return self;
    else
        local this = self:CopyIfImmutable();
        this.sign = 1;
        return this;
    end
end

function bigint:Add(other)
    -- addition of 0
    if other.sign == 0 then
        return self;
    elseif self.sign == 0 then
        return other;
    end

    -- determine sign, operation, and order of operands
    local subtract = false;
    local swapOrder = false;
    local changeSign = false;
    if self.sign == other.sign then
        if #self.bytes < #other.bytes then
            swapOrder = true;
        end
    else
        local ucomp = self:CompareU(other);
        if ucomp == 0 then
            return bigint.Zero;
        end
        subtract = true;
        if ucomp == -1 then
            swapOrder = true;
            changeSign = true;
        end
    end

    -- perform operation
    local this = self:CopyIfImmutable();
    local byteCount;
    local otherByteCount;
    local bytes;
    local otherBytes;
    if swapOrder then
        bytes = other.bytes;
        otherBytes = self.bytes;
    else
        bytes = self.bytes;
        otherBytes = other.bytes;
    end
    byteCount = #bytes;
    otherByteCount = #otherBytes;
    local carry = 0;
    for i = 1, byteCount, 1 do
        local byte = bytes[i];
        local otherByte = otherBytes[i] or 0;
        if subtract then
            otherByte = -otherByte;
        end
        local sum = byte + otherByte + carry;
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

        -- end loop as soon as possible
        if i >= otherByteCount and carry == 0 then
            if swapOrder then
                -- just need to copy remaining bytes
                for j = i + 1, byteCount, 1 do
                    this.bytes[j] = bytes[j];
                end
            end
            break;
        end
    end
    if carry > 0 then
        this.bytes[byteCount + 1] = carry
    end
    if subtract then
        this:Rstrip();
    end
    if changeSign then
        this.sign = -this.sign;
    end
    return this;
end

function bigint:Sub(other)
    return self:Add(other:Unm());
end

function bigint:Mul(other)
    -- multiplication by 0
    if self.sign == 0 or other.sign == 0 then
        return bigint.Zero;
    end

    -- multiplication by 1
    if self:IsOne() then
        if self.sign == -1 then
            return other:Unm();
        else
            return other;
        end
    end
    if other:IsOne() then
        if other.sign == -1 then
            return self:Unm();
        else
            return self;
        end
    end

    -- general multiplication
    local carry = 0;
    local this = self:CopyIfImmutable();
    local bytes = this.bytes;
    local otherBytes = other.bytes;
    local byteCount = #bytes;
    local otherByteCount = #otherBytes;
    if otherByteCount > byteCount then
        -- swap order so that number with more bytes comes first
        bytes = other.bytes;
        otherBytes = this.bytes;
        local tmp = byteCount;
        byteCount = otherByteCount;
        otherByteCount = tmp;
    end
    local shift = 0;
    local result = {};
    local carry = 0;
    for i = 1, otherByteCount, 1 do
        if otherBytes[i] == 0 then
            if result[i] == nil then
                result[i] = 0;
            end
        else
            -- multiply each byte
            local j = 1;
            while j <= byteCount do
                local resultIdx = i + j - 1;
                local product = bytes[j] * otherBytes[i] + carry + (result[resultIdx] or 0);
                -- add product to result
                result[resultIdx] = product % 256;
                carry = math_floor(product / 256);
                j = j + 1;
            end

            -- finish adding carry
            while carry ~= 0 do
                local resultIdx = i + j - 1;
                local sum = (result[resultIdx] or 0) + carry;
                result[resultIdx] = sum % 256;
                carry = math_floor(sum / 256);
                j = j + 1;
            end
        end
    end
    table_copy(this.bytes, result);
    this.sign = this.sign * other.sign;
    return this;
end

function bigint:DivWithRemainder(other, ignoreRemainder)
    -- division of/by 0
    if self.sign == 0 then
        return self, self;
    elseif other.sign == 0 then
        return other, other;
    end

    -- division by 1
    if other:IsOne() then
        if other.sign == -1 then
            return self:Unm(), bigint.Zero;
        else
            return self, bigint.Zero;
        end
    end

    -- division by bigger number or self
    local ucomp = self:CompareU(other);
    if ucomp == -1 then
        if self.sign == other.sign then
            return bigint.Zero, self;
        else
            if ignoreRemainder then
                return bigint.NegOne, self;
            else
                return bigint.NegOne, self:Add(other);
            end
        end
    elseif ucomp == 0 then
        if self.sign == other.sign then
            return bigint.One, bigint.Zero;
        else
            return bigint.NegOne, bigint.Zero;
        end
    end

    -- general division
    local this = self:CopyIfImmutable();
    local another = other:CopyIfImmutable();
    local byteCount = #this.bytes;
    local otherByteCount = #another.bytes;
    local resultIdx = 1;
    local result = {};
    local divIdx = byteCount - otherByteCount + 1;
    while divIdx >= 1 do
        local factor = 0;
        repeat
            -- check if divisor is smaller
            local foundFactor = false;
            local sliceSize = otherByteCount;
            if divIdx + sliceSize <= byteCount and this.bytes[divIdx + sliceSize] ~= 0 then
                sliceSize = sliceSize + 1;
            end
            for i = sliceSize, 1, -1 do
                local byte = this.bytes[divIdx + i - 1] or 0;
                local otherByte = another.bytes[i] or 0;
                if otherByte < byte then
                    foundFactor = false;
                    break;
                elseif otherByte > byte then
                    foundFactor = true;
                    break;
                end
            end

            -- subtract divisor
            if not foundFactor then
                factor = factor + 1;
                local carry = 0;
                local i = 1;
                while i <= sliceSize or carry ~= 0 do
                    local j = divIdx + i - 1;
                    local diff = (this.bytes[j] or 0) - (another.bytes[i] or 0) + carry;
                    if diff < 0 then
                        carry = -1;
                        diff = diff + 256;
                    else
                        carry = 0;
                    end
                    this.bytes[j] = diff;
                    i = i + 1;
                end
            end
        until foundFactor;

        -- set digit
        result[resultIdx] = factor;
        resultIdx = resultIdx + 1;

        divIdx = divIdx - 1;
    end

    local sign = this.sign;
    local otherSign = another.sign;
    local divSign = sign * otherSign;

    this:Rstrip();
    if this.bytes[1] == nil then
        this.sign = 0;
    end

    table_reverse(result);

    -- if negative and doesn't divide evenly, round quotient down
    if divSign == -1 and this.sign ~= 0 then
        local carry = 1;
        local i = 1;
        while carry ~= 0 do
            local sum = (result[i] or 0) + carry;
            if sum >= 256 then
                sum = sum - 256;
                carry = 1;
            else
                carry = 0;
            end
            result[i] = sum;
            i = i + 1;
        end
    end

    -- if remainder is negative, add divisor to make it positive
    if not ignoreRemainder then
        if sign ~= otherSign then
            this = this:Add(another);
        end
    end
    if otherSign == -1 then
        this.sign = -1;
    end

    -- last steps
    table_copy(another.bytes, result);
    another.sign = divSign;
    another:Rstrip();

    if another.bytes[1] == nil then
        another.sign = 0;
    end

    return another, this;
end

function bigint:Div(other)
    local quotient, remainder = self:DivWithRemainder(other, true);
    return quotient;
end

function bigint:Mod(other)
    local quotient, remainder = self:DivWithRemainder(other);
    return remainder;
end

--##### BITWISE OPERATORS #####--

function bigint:Shr(n)
    if self.sign == 0 or n == 0 then
        return self;
    end

    -- shift whole bytes
    local shiftBytes = math_floor(n / 8);
    local byteCount = #self.bytes;
    if shiftBytes >= byteCount then
        return bigint.Zero;
    end
    local this = self:CopyIfImmutable();
    for i = shiftBytes + 1, byteCount, 1 do
        this.bytes[i - shiftBytes] = this.bytes[i];
    end
    for i = byteCount - shiftBytes + 1, byteCount, 1 do
        this.bytes[i] = nil;
    end
    byteCount = byteCount - shiftBytes;

    -- shift bits
    local shiftBits = n % 8;
    if shiftBits == 0 then
        return this;
    end

    local shiftNum = 2 ^ shiftBits;
    local unshiftNum = 2 ^ (8 - shiftBits);
    for i = 1, byteCount, 1 do
        local overflow = this.bytes[i] % shiftNum;
        this.bytes[i] = math_floor(this.bytes[i] / shiftNum);
        if i ~= 1 then
            this.bytes[i - 1] = this.bytes[i - 1] + overflow * unshiftNum;
        end
    end
    
    -- strip zero
    if this.bytes[byteCount] == 0 then
        this.bytes[byteCount] = nil;
        if byteCount == 1 then
            this.sign = 0;
        end
    end
    return this;
end

function bigint:Shl(n)
    if self.sign == 0 or n == 0 then
        return self;
    end

    -- shift whole bytes
    local shiftBytes = math_floor(n / 8);
    local byteCount = #self.bytes;
    local this = self:CopyIfImmutable();
    for i = byteCount + 1, byteCount + shiftBytes, 1 do
        this.bytes[i] = 0;
    end
    for i = byteCount + shiftBytes, shiftBytes + 1, -1 do
        this.bytes[i] = this.bytes[i - shiftBytes];
    end
    for i = shiftBytes, 1, -1 do
        this.bytes[i] = 0;
    end
    byteCount = byteCount + shiftBytes;

    -- shift bits
    local shiftBits = n % 8;
    if shiftBits == 0 then
        return this;
    end

    local shiftNum = 2 ^ shiftBits;
    local unshiftNum = 2 ^ (8 - shiftBits);
    for i = byteCount, shiftBytes + 1, -1 do
        local overflow = math_floor(this.bytes[i] / unshiftNum);
        this.bytes[i] = (this.bytes[i] * shiftNum) % 256;
        if overflow ~= 0 then
            this.bytes[i + 1] = (this.bytes[i + 1] or 0) + overflow;
        end
    end

    return this;
end

function bigint:Bor(other)
    if other.sign == 0 then
        return self;
    end
    if self.sign == 0 then
        return other;
    end
    if self:CompareU(other) == 0 then
        if self.sign == other.sign then
            return self;
        else
            return self:Unm();
        end
    end

    local this;
    local count = #self.bytes;
    local otherCount = #other.bytes;
    if otherCount > count then
        count = otherCount;
    end
    for i = 1, count, 1 do
        local result = 0;
        local bit = 1;
        local byte = (this or self).bytes[i] or 0;
        local origByte = byte;
        local otherByte = other.bytes[i] or 0;
        for _ = 1, 8, 1 do
            if (byte % 2) == 1 or (otherByte % 2) == 1 then
                result = result + bit;
            end
            byte = math_floor(byte / 2);
            otherByte = math_floor(otherByte / 2);
            bit = bit * 2;
        end
        if result ~= origByte then
            if this == nil then
                -- lazy copy
                this = self:CopyIfImmutable();
            end
            this.bytes[i] = result;
        end
    end
    return this or self;
end

function bigint:Band(other)
    if self.sign == 0 then
        return self;
    end
    if other.sign == 0 then
        return other;
    end
    if self:CompareU(other) == 0 then
        if self.sign == other.sign then
            return self;
        else
            return self:Unm();
        end
    end

    local this;
    local count = #self.bytes;
    local otherCount = #other.bytes;
    if otherCount > count then
        count = otherCount;
    end
    for i = 1, count, 1 do
        local result = 0;
        local bit = 1;
        local byte = (this or self).bytes[i] or 0;
        local origByte = byte;
        local otherByte = other.bytes[i] or 0;
        for _ = 1, 8, 1 do
            if (byte % 2) == 1 and (otherByte % 2) == 1 then
                result = result + bit;
            end
            byte = math_floor(byte / 2);
            otherByte = math_floor(otherByte / 2);
            bit = bit * 2;
        end
        if result ~= origByte then
            if this == nil then
                -- lazy copy
                this = self:CopyIfImmutable();
            end
            this.bytes[i] = result;
        end
    end
    if this == nil then
        this = self;
    else
        this:Rstrip();
        if this.bytes[1] == nil then
            this.sign = 0;
        end
    end
    return this;
end

function bigint:Bxor(other)
    if other.sign == 0 then
        return self;
    end
    if self.sign == 0 then
        return other;
    end
    if self:CompareU(other) == 0 then
        return bigint.Zero;
    end

    local this = self:CopyIfImmutable();
    local count = #self.bytes;
    local otherCount = #other.bytes;
    if otherCount > count then
        count = otherCount;
    end
    for i = 1, count, 1 do
        local result = 0;
        local bit = 1;
        local byte = this.bytes[i] or 0;
        local origByte = byte;
        local otherByte = other.bytes[i] or 0;
        for _ = 1, 8, 1 do
            if (byte % 2) ~= (otherByte % 2) then
                result = result + bit;
            end
            byte = math_floor(byte / 2);
            otherByte = math_floor(otherByte / 2);
            bit = bit * 2;
        end
        this.bytes[i] = result;
    end
    this:Rstrip();
    if this.bytes[1] == nil then
        this.sign = 0;
    end
    return this;
end

function bigint:SetBits(...)
    local count = #arg;
    if count == 0 then
        return self;
    end

    local this;
    local byteCount = #self.bytes;
    for i = 1, count, 1 do
        local bit = arg[i] - 1;
        if bit >= 0 then
            local byteNum = math_floor(bit / 8) + 1;
            if byteNum > byteCount then
                if this == nil then
                    -- lazy copy
                    this = self:CopyIfImmutable();
                    if this.sign == 0 then
                        this.sign = 1;
                    end
                end
                for j = byteCount + 1, byteNum, 1 do
                    this.bytes[j] = 0;
                end
                byteCount = byteNum;
            end
            local byte = (this or self).bytes[byteNum];
            local bitNum = 2 ^ (bit % 8);
            if (byte / bitNum) % 2 < 1 then
                if this == nil then
                    -- lazy copy
                    this = self:CopyIfImmutable();
                    if this.sign == 0 then
                        this.sign = 1;
                    end
                end
                this.bytes[byteNum] = byte + bitNum;
            end
        end
    end
    return this or self;
end

function bigint:UnsetBits(...)
    if self.sign == 0 then
        return self;
    end
    local count = #arg;
    if count == 0 then
        return self;
    end

    local this;
    for i = 1, count, 1 do
        local bit = arg[i] - 1;
        if bit >= 0 then
            local byteNum = math_floor(bit / 8) + 1;
            local byte = (this or self).bytes[byteNum];
            if byte ~= nil then
                local bitNum = 2 ^ (bit % 8);
                if (byte / bitNum) % 2 >= 1 then
                    if this == nil then
                        -- lazy copy
                        this = self:CopyIfImmutable();
                    end
                    this.bytes[byteNum] = byte - bitNum;
                end
            end
        end
    end
    if this == nil then
        this = self;
    else
        this:Rstrip();
        if this.bytes[1] == nil then
            this.sign = 0;
        end
    end
    return this;
end

function bigint:GetBit(i)
    if i < 1 then
        return nil;
    end
    if self.sign == 0 then
        return 0;
    end

    i = i - 1;
    local byteNum = math_floor(i / 8) + 1;
    local byte = self.bytes[byteNum];
    if byte == nil or byte == 0 then
        return 0;
    end

    local bitNum = i % 8;
    return math_floor(byte / (2 ^ bitNum)) % 2;
end

function bigint:MaxBit()
    if self.sign == 0 then
        return 0;
    end

    local byteCount = #self.bytes;
    local byte = self.bytes[byteCount];
    local bitNum = (byteCount - 1) * 8;
    while byte >= 1 do
        bitNum = bitNum + 1;
        byte = byte / 2;
    end
    return bitNum + 1;
end

--##### EQUALITY OPERATORS #####--

-- compare unsigned
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

function bigint:CompareOp(other, op)
    return bigint_comparatorMap[op](self, other);
end

function bigint:Eq(other)
    return self:Compare(other) == 0;
end

function bigint:Lt(other)
    return self:Compare(other) == -1;
end

function bigint:Le(other)
    return self:Compare(other) <= 0;
end

function bigint:Gt(other)
    return self:Compare(other) == 1;
end

function bigint:Ge(other)
    return self:Compare(other) >= 0;
end

--##### CONVERSION #####--

function bigint:ToBytes()
    local bytes = table_copy(self.bytes);
    table_reverse(bytes);
    return string_char(unpack(bytes));
end

function bigint:ToNumber()
    local total = 0;
    for i = #self.bytes, 1, -1 do
        total = (total * 256) + self.bytes[i];
    end
    return total * self.sign;
end

-- fast hex base conversion
function bigint:ToHex(noPrefix)
    if self.sign == 0 then
        if noPrefix then
            return "0";
        else
            return "0x0";
        end
    end

    local bytes = table_copy(self.bytes);
    table_reverse(bytes);
    local result = string_format("%x" .. ("%02x"):rep(#bytes - 1), unpack(bytes));
    if not noPrefix then
        result = "0x" .. result;
    end
    if self.sign == -1 then
        result = "-" .. result;
    end
    return result;
end

-- fast bin base conversion
function bigint:ToBin(noPrefix)
    if self.sign == 0 then
        if noPrefix then
            return "0";
        else
            return "0b0";
        end
    end

    local t = {};
    local bytesCount = #self.bytes;
    for i = 1, bytesCount, 1 do
        local byte = self.bytes[i];
        local start = (i - 1) * 8 + 1;
        for j = start, start + 7, 1 do
            if byte == 0 then
                if i == bytesCount then
                    break;
                end
                t[j] = 0;
            else
                t[j] = byte % 2;
                byte = math_floor(byte / 2);
            end
        end
    end
    table_reverse(t);
    local result = table_concat(t);
    if not noPrefix then
        result = "0b" .. result;
    end
    if self.sign == -1 then
        result = "-" .. result;
    end
    return result;
end

function bigint:ToDec()
    return self:Base(10);
end

-- general base conversion
function bigint:ToBase(base)
    if base == 2 then
        return self:ToBin(true);
    elseif base == 16 then
        return self:ToHex(true);
    end

    if self.sign == 0 then
        return "0";
    end

    local result = {};
    for i = #self.bytes, 1, -1 do
        -- multiply by 256
        local carry = 0;
        local j = 1;
        while result[j] ~= nil or carry ~= 0 do
            local product = (result[j] or 0) * 256 + carry;
            result[j] = product % base;
            carry = math_floor(product / base);
            j = j + 1;
        end

        -- add byte
        j = 1;
        carry = self.bytes[i];
        while carry ~= 0 do
            local sum = (result[j] or 0) + carry;
            result[j] = sum % base;
            carry = math_floor(sum / base);
            j = j + 1;
        end
    end
    table_reverse(result);
    for i = #result, 1, -1 do
        result[i] = bigint_digits[result[i] + 1];
    end
    local result = table_concat(result);
    if self.sign == -1 then
        result = "-" .. result;
    end
    return result;
end

--##### METATABLE #####--

bigint_mt = {
    __index = bigint,
    __unm = bigint.Unm,
    __add = bigint.Add,
    __sub = bigint.Sub,
    __mul = bigint.Mul,
    __div = bigint.Div,
    __mod = bigint.Mod,
    __pow = bigint.Pow,
    __call = bigint.Construct,
};

--##### HELPERS #####--

bigint.Zero = bigint.New();
bigint.One = bigint.FromNumber(1);
bigint.NegOne = bigint.FromNumber(-1);
bigint.Two = bigint.FromNumber(2);

bigint_digits = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"};
bigint_comparatorMap = {
    ["="] = bigint.Eq,
    ["<"] = bigint.Lt,
    [">"] = bigint.Gt,
    ["<="] = bigint.Le,
    [">="] = bigint.Ge
};

function bigint:Copy()
    local copy = bigint.New();
    table_copy(copy.bytes, self.bytes);
    copy.sign = self.sign;
    --print("bigint:Copy()")
    return copy;
end

-- return a copy if immutable or self otherwise
-- if other is not nil, copy it instead
function bigint:CopyIfImmutable()
    if self.mutable then
        return self;
    else
        return self:Copy()
    end
end

function bigint:IsEven()
    if self.sign == 0 then
        return true;
    end
    return self.bytes[1] % 2 == 0;
end

function bigint:IsOne()
    return self.bytes[2] == nil and self.bytes[1] == 1;
end

function bigint:GetPowerOfTwo()
    if self.sign == 0 then
        return 0;
    end

    local i = 1;
    local power = 0;
    while self.bytes[i] ~= nil do
        local byte = self.bytes[i];
        for _ = 1, 8, 1 do
            if byte % 2 == 0 then
                power = power + 1;
            else
                return power;
            end
            byte = math_floor(byte / 2);
        end
        i = i + 1;
    end
    return 0;
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

    table_reverse(this.bytes);
    this:Rstrip();
    return this;
end

function bigint:Rstrip()
    local i = #self.bytes;
    while self.bytes[i] == 0 do
        self.bytes[i] = nil;
        i = i - 1;
    end
    if i == 0 then
        self.sign = 0;
    end
end

function table_reverse(t)
    local size = #t;
    local mid = #t / 2;
    for i = 1, mid, 1 do
        local j = size - i + 1;
        local tmp = t[i]
        t[i] = t[j];
        t[j] = tmp;
    end
    return t;
end

-- copy t2 into t1
-- or return copy of t1 if t2 is nil
function table_copy(t1, t2)
    if t2 == nil then
        return {unpack(t1)};
    else
        local size = #t1;
        local t2Size = #t2;
        if t2Size > size then
            size = t2Size;
        end
        for i = 1, size, 1 do
            t1[i] = t2[i];
        end
    end
end

return bigint;

end

function dprint(obj)
    local function rec(obj, t, visited)
        if type(obj) == "table" and not visited[obj] then
            visited[obj] = true;
            t[#t+1] = "{";
            local i = 1;
            while obj[i] ~= nil do
                rec(obj[i], t, visited);
                t[#t+1] = ", ";
                i = i + 1;
            end
            for k, v in pairs(obj) do
                if not (type(k) == "number" and k >= 1 and k < i) then
                    t[#t+1] = "[";
                    rec(k, t, visited);
                    t[#t+1] = "] = ";
                    rec(v, t, visited);
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
    rec(obj, t, {});
    print(table.concat(t));
end

return bigint_module();
