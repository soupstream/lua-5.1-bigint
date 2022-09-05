# Lua 5.1 Bigint

An implementation of arbitrary length integers in pure Lua.

## Features:

- Implements arithmetic operators: addition, subtraction, multiplication, division, power, unary minus, log2
- Implements bitwise operators: and, or, xor, not, shift left, shift right, set bits, unset bits, get bit, 2's complement
- Implements all comparison operators
- Construct from Lua number, string with base, array of bytes, string of bytes
- Convert to Lua number, string with base, string of bytes, little-endian string of bytes
- Reasonably fast
- Compatible with Lua 5.1+

## Example usage:

```lua
bigint = require("bigint")

-- implementation of the 64-bit FNV-1 hash function

local fnvOffsetBasis = bigint("0xcbf29ce484222325")
local fnvPrime = bigint("0x100000001b3")
local maxValue64 = bigint("0x10000000000000000")
function fnv1(str)
    local hash = fnvOffsetBasis
    for i = 1, #str, 1 do
        local byte = str:byte(i)
        hash = hash * fnvPrime
        hash = hash % maxValue64
        hash = hash:Bxor(byte)
        -- or in Lua 5.3+:
        -- hash = hash ~ byte
    end
    return hash
end

print(fnv1("data to hash"):ToHex())
-- output: 0xc86b139d989958e4
```

## Reference

The available methods are listed below. Parameters of type bigint can also be converted implicitly from other types.

Constructors:

- `bigint(val: any, [base: number = 10]): bigint`: chooses from one of the following constructors based on the type of `val`
- `bigint.FromString(val: string, [base: number = 10]): bigint`: constructs from a string representation of a number (supports 0x and 0b prefixes)
- `bigint.FromNumber(val: number): bigint`: constructs from a native Lua number
- `bigint.FromArray(val: array, [littleEndian: bool = false]): bigint`: constructs from an array of bytes
- `bigint.FromBytes(val: string, [littleEndian: bool = false]): bigint`: constructs from a string of bytes

Converters:

- `bigint:ToBytes([size: number], [littleEndian: bool = false]): string`: converts to a string of bytes
- `bigint:ToNumber(): number`: converts to a native Lua number
- `bigint:ToHex([noPrefix: bool = false]): string`: converts to a hexadecimal string
- `bigint:ToBin([noPrefix: bool = false]): string`: converts to a binary string
- `bigint:ToBase(base: number): string`: converts to a string with the specified base

Arithmetic operators:

- `bigint:Add(val: bigint): bigint`: add (`+`)
- `bigint:Sub(val: bigint): bigint`: subtract (`-`)
- `bigint:Mul(val: bigint): bigint`: multiply (`*`)
- `bigint:Div(val: bigint): bigint`: divide (`/` or `//` 5.3+)
- `bigint:DivWithRemainder(val: bigint): bigint, bigint`: divide and return both quotient and remainder
- `bigint:Mod(val: bigint): bigint`: modulo (`%`)
- `bigint:Pow(val: bigint): bigint`: power (`^`)
- `bigint:Unm(): bigint`: unary minus (`-`)
- `bigint:Log2(): bigint`: log base 2
- `bigint:Abs(): bigint`: absolute value

Bitwise operators:

- `bigint:Shr(val: bigint): bigint`: shift right (`>>` 5.3+)
- `bigint:Shl(val: bigint): bigint`: shift left (`<<` 5.3+)
- `bigint:Band(val: bigint): bigint`: bitwise and (`&` 5.3+)
- `bigint:Bor(val: bigint): bigint`: bitwise or (`|` 5.3+)
- `bigint:Bxor(val: bigint): bigint`: bitwise xor (`~` 5.3+)
- `bigint:Bnot([size: number]): bigint`: bitwise not (`~` 5.3+)
- `bigint:SetBits(bits: number...): bigint`: sets bits to 1 at the given indices (starting at 1)
- `bigint:UnsetBits(bits: number...): bigint`: sets bits to 0 at the given indices
- `bigint:GetBit(bit: bigint): number`: returns the value of the bit at the index
- `bigint:CastUnsigned(size: bigint): bigint`: converts a signed value with `size` bytes to its unsigned 2's complement representation
- `bigint:CastSigned(size: bigint): bigint`: converts an unsigned value with `size` bytes to its signed 2's complement representation

Comparison operators:

- `bigint:Compare(val: bigint): number`: returns -1 if smaller, 0 if equal, and 1 if larger
- `bigint:CompareU(val: bigint): number`: like `Compare` but ignores sign
- `bigint:CompareOp(val: bigint, op: string): bool`: performs one of the below comparisons matching `op`
- `bigint:Eq(val: bigint): bool`: equal (`==`)
- `bigint:Ne(val: bigint): bool`: not equal (`~=`)
- `bigint:Lt(val: bigint): bool`: less than (`<`)
- `bigint:Le(val: bigint): bool`: less than or equal (`<=`)
- `bigint:Gt(val: bigint): bool`: greater than (`>`)
- `bigint:Ge(val: bigint): bool`: greater than or equal (`>=`)

Constants:

- `bigint.Zero`
- `bigint.One`
- `bigint.NegOne`
- `bigint.MaxNumber`: the highest integer that can be represented accurately by native Lua numbers

Misc:

- `bigint.IsBigInt(val: any): bool`: returns `true` if `val` is a bigint
- `bigint:Copy(): bigint`: returns a copy of the bigint
- `bigint:IsEven(): bool`: efficiently determine whether bigint is even
- `bigint:IsOne(): bool`: efficiently determine whither bigint equals one

## Testing

Run `python test.py [iterations = 1000]` in the `tests` directory to perform tests.
