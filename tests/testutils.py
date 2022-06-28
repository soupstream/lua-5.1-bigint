import random

def randexp(minbits, maxbits=None):
    if maxbits == None:
        randbits = random.randrange(7, minbits)
        if randbits == 7:
            return random.randrange(256)
    else:
        randbits = random.randrange(minbits, maxbits)
    return random.randrange(2 ** randbits, 2 ** (randbits + 1))

def srandexp(minbits, maxbits=None):
    return randexp(minbits, maxbits) * random.choice([-1, 1])

def srandexpgen(n, minbits=64, maxbits=None):
    for i in range(n):
        yield srandexp(minbits, maxbits)

def randexpgen(n, minbits=64, maxbits=None):
    for i in range(n):
        yield randexp(minbits, maxbits)

def randgen(n, minValue, maxValue=None):
    for i in range(n):
        yield random.randrange(minValue, maxValue)

def sign(n):
    if n > 0:
        return 1
    elif n < 0:
        return -1
    else:
        return 0

def setbits(n, bits):
    s = sign(n) or 1
    n = abs(n)
    for bit in bits:
        mask = 1 << bit
        n |= mask
    return n * s

def unsetbits(n, bits):
    s = sign(n) or 1
    n = abs(n)
    for bit in bits:
        mask = 1 << bit
        if n & mask != 0:
            n ^= mask
    return n * s

def getbit(n, bit):
    n = abs(n)
    if n & (1 << bit) == 0:
        return 0
    else:
        return 1

def intdiv(n1, n2):
    if n2 == 0:
        return 0
    s = sign(n1) * sign(n2)
    n1 = abs(n1)
    n2 = abs(n2)
    return s * (n1 // n2)

def intmod(n1, n2):
    if n2 == 0:
        return 0
    return n1 % n2

def intpow(n1, n2):
    if n2 < 0:
        return 0
    return n1 ** n2

def ubxor(n1, n2):
    s = sign(n1) or 1
    n1 = abs(n1)
    n2 = abs(n2)
    return (n1 ^ n2) * s

def uband(n1, n2):
    s = sign(n1) or 1
    n1 = abs(n1)
    n2 = abs(n2)
    return (n1 & n2) * s

def ubor(n1, n2):
    s = sign(n1) or 1
    n1 = abs(n1)
    n2 = abs(n2)
    return (n1 | n2) * s

def ushr(n1, n2):
    if n2 < 0:
        return ushl(n1, -n2)
    s = sign(n1) or 1
    n1 = abs(n1)
    return (n1 >> n2) * s

def ushl(n1, n2):
    if n2 < 0:
        return ushr(n1, -n2)
    s = sign(n1) or 1
    n1 = abs(n1)
    return (n1 << n2) * s

def toBase(n, b):
    if n == 0:
        return "0"
    sign = ""
    if n < 0:
        n = -n
        sign = "-"
    digits = []
    chars = "0123456789abcdefghijklmnopqrstuvwxyz"
    while n:
        digits.append(chars[n % b])
        n //= b
    return sign + "".join(digits[::-1])

def byteArrayToInt(arr, littleEndian):
    if littleEndian:
        arr = reversed(arr)
    n = 0
    for b in arr:
        n *= 256
        n += b
    return n

def intToByteArray(n, littleEndian, size=None):
    arr = []
    n = abs(n)
    while n > 0:
        arr.append(n % 256)
        n = n // 256
    size = size or len(arr)
    if len(arr) <= size:
        arr += [0] * (size - len(arr))
    else:
        arr = arr[:size]
    if not littleEndian:
        arr.reverse()
    return arr

def castUnsigned(n, byteCount):
    if n < 0:
        return n + (2 ** (byteCount * 8))
    return n

def castSigned(n, byteCount):
    if n >= 2 ** (byteCount * 8 - 1):
        return n - (2 ** (byteCount * 8))
    return n
