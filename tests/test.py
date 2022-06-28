#!/usr/bin/env python3
import subprocess
import random
import inspect
import math
import sexp
import sys
from testutils import *

def findTestName():
    frame = inspect.currentframe()
    while frame.f_code.co_name not in testNames:
        frame = frame.f_back
    return frame.f_code.co_name

resultMap = {}

# ANSI color codes
ansiReset = "\u001b[0m"
ansiRed = "\u001b[31m"
ansiGreen = "\u001b[32m"
ansiYellow = "\u001b[33m"

def printError(msg):
    print(ansiRed + msg + ansiReset, file=sys.stderr)

def printWarning(msg):
    print(ansiYellow + msg + ansiReset)

def printSuccess(msg):
    print(ansiGreen + msg + ansiReset)

def checkTest(expected, result, expression=""):
    if expression != "":
        expression += " == "
    success = True
    testName = findTestName()
    if testName not in resultMap:
        resultMap[testName] = {"successes": 0, "failures": 0}

    if result.returncode != 0:
        printError(f"{testName} failure: {expression}{expected} => exit {result.returncode}")
        if result.stderr != "":
            printError(result.stderr.strip())
        success = False
    elif expected != result.stdout.strip():
        printError(f"{testName} failure: {expression}{expected} != {result.stdout.strip()}")
        success = False

    if success:
        resultMap[testName]["successes"] += 1
    else:
        resultMap[testName]["failures"] += 1

    return success

def runLuaWithTimeout(timeout, script, *args):
    return subprocess.run(["./" + script, *args], encoding="utf-8", capture_output=True, timeout=timeout)

def runLua(script, *args):
    return runLuaWithTimeout(1, script, *args);

def runTests(tests, iterations):
    global testNames
    testNames = []
    for test in tests:
        if type(test) == tuple:
            iterations = test[1]
            test = test[0]

        testNames.append(test.__name__)
        print("Running " + test.__name__)
        test(iterations)

        results = resultMap[test.__name__]
        successes = results["successes"]
        failures = results["failures"]
        msg = test.__name__ + f" result: {successes} / {successes+failures}"
        if failures == 0:
            printSuccess(msg)
        else:
            printWarning(msg)

def testFromStringHex(iterations):
    def test(n, strOverride=None):
        result = runLua("fromstring.lua", strOverride or hex(n))
        checkTest(hex(n), result)
    test(-1)
    test(0)
    test(0, "-0x0")
    test(1)
    test(256)
    test(-0xdeadbeef, "-0x00000000000deadbeef")
    for n in srandexpgen(iterations):
        test(n)

def testFromStringBin(iterations):
    def test(n, strOverride=None):
        result = runLua("fromstring.lua", strOverride or bin(n))
        checkTest(hex(n), result)
    test(-1)
    test(0)
    test(0, "-0b0")
    test(1)
    test(256)
    test(-0b1101010101011011101010101001, "-0b000000000000000001101010101011011101010101001")
    for n in srandexpgen(iterations):
        test(n)

def testFromStringBase(iterations):
    def test(n, base, strOverride=None):
        nstr = toBase(n, base)
        result = runLua("fromstring.lua", strOverride or nstr, str(base))
        checkTest(hex(n), result, nstr + " base " + str(base))
    for base in range(2, 36 + 1):
        test(-1, base)
        test(0, base)
        test(1, base)
        test(256, base)
        test(-0xdeadbeef, base, "-0000000000000000" + toBase(0xdeadbeef, base))
    for n, base in zip(srandexpgen(iterations), randgen(iterations, 2, 36 + 1)):
        test(n, base)

def testFromNumber(iterations):
    def test(n):
        result = runLua("fromnumber.lua", str(n))
        checkTest(hex(n), result)
    test(-1)
    test(0)
    test(1)
    test(256)
    precision = int(runLua("getprecision.lua").stdout)
    if precision == 32:
        mantissa = 24
        test(-0xdeadbe)
    else:
        mantissa = 53
        test(-0x1deadbeefdeadb)

    for n in srandexpgen(iterations, mantissa):
        test(n)

def testFromArray(iterations):
    def test(arr, littleEndian):
        arrStrs = [str(x) for x in arr]
        endianStr = "LE" if littleEndian else "BE"
        result = runLua("fromarray.lua", str(littleEndian), *arrStrs)
        checkTest(hex(byteArrayToInt(arr, littleEndian)), result, ",".join(arrStrs) + f" ({endianStr})")
    for endianness in [True, False]:
        test([], endianness)
        test([0], endianness)
        test([1], endianness)
        test([0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0], endianness)
    for n in randexpgen(iterations):
        endianness = random.choice([True, False])
        test(intToByteArray(n, endianness), endianness)

def testFromBytes(iterations):
    def test(arr, littleEndian):
        arrStrs = [str(x) for x in arr]
        endianStr = "LE" if littleEndian else "BE"
        result = runLua("frombytes.lua", str(littleEndian), *arrStrs)
        checkTest(hex(byteArrayToInt(arr, littleEndian)), result, ",".join(arrStrs) + f" ({endianStr})")
    for endianness in [True, False]:
        test([], endianness)
        test([0], endianness)
        test([1], endianness)
        test([0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0], endianness)
    for n in randexpgen(iterations):
        endianness = random.choice([True, False])
        test(intToByteArray(n, endianness), endianness)

def testAdd(iterations):
    def test(n1, n2):
        result = runLua("add.lua", hex(n1), hex(n2))
        checkTest(hex(n1 + n2), result, hex(n1) + " + " + hex(n2))
    test(0, 0)
    test(0, 123)
    test(123, 0)
    test(123, -123)
    test(-123, 123)
    for n1, n2 in zip(srandexpgen(iterations), srandexpgen(iterations)):
        test(n1, n2)

def testSub(iterations):
    def test(n1, n2):
        result = runLua("sub.lua", hex(n1), hex(n2))
        checkTest(hex(n1 - n2), result, hex(n1) + " - " + hex(n2))
    test(0, 0)
    test(0, 123)
    test(123, 0)
    test(123, -123)
    test(-123, 123)
    for n1, n2 in zip(srandexpgen(iterations), srandexpgen(iterations)):
        test(n1, n2)

def testMul(iterations):
    def test(n1, n2):
        result = runLua("mul.lua", hex(n1), hex(n2))
        checkTest(hex(n1 * n2), result, hex(n1) + " * " + hex(n2))
    test(0, 0)
    test(0, 123)
    test(123, 0)
    test(1, 123)
    test(123, 1)
    for n1, n2 in zip(srandexpgen(iterations), srandexpgen(iterations)):
        test(n1, n2)

def testDiv(iterations):
    def test(n1, n2):
        result = runLua("div.lua", hex(n1), hex(n2))
        checkTest(hex(intdiv(n1, n2)), result, hex(n1) + " / " + hex(n2))
    test(0, 0)
    test(1, 1)
    test(-1, 1)
    test(-1, -1)
    test(1, -1)
    test(0, 123)
    test(0, -123)
    test(123, 0)
    test(1, 123)
    test(123, 1)
    test(0xdeadbeef, 2)
    test(-0xdeadbeef, 0x5000)
    test(-0xdeadbeef, 0xdeadbeef)
    for n1, n2 in zip(srandexpgen(iterations), srandexpgen(iterations)):
        test(n1, n2)

def testMod(iterations):
    def test(n1, n2):
        result = runLua("mod.lua", hex(n1), hex(n2))
        checkTest(hex(intmod(n1, n2)), result, hex(n1) + " % " + hex(n2))
    test(0, 0)
    test(1, 1)
    test(-1, 1)
    test(-1, -1)
    test(1, -1)
    test(0, 123)
    test(0, -123)
    test(123, 0)
    test(1, 123)
    test(123, 1)
    test(0xdeadbeef, 2)
    test(-0xdeadbeef, 0x5000)
    test(-0xdeadbeef, 0xdeadbeef)
    for n1, n2 in zip(srandexpgen(iterations), srandexpgen(iterations)):
        test(n1, n2)

def testPow(iterations):
    def test(n1, n2):
        result = runLua("pow.lua", hex(n1), hex(n2))
        checkTest(hex(intpow(n1, n2)), result, hex(n1) + " pow " + hex(n2))
    test(0, 123)
    test(0, -1)
    test(-1, 4)
    test(1, 123)
    test(123, 1)
    test(123, 0)
    test(-123, 1)
    test(-123, 0)
    test(-123, -1)
    test(0x100, 0x100)
    test(0xdeadbeef, 0x100)
    test(0xdeadbeef, -1)
    for n1, n2 in zip(srandexpgen(iterations), randgen(iterations, -4, 65)):
        test(n1, n2)

def testToBase(iterations):
    def test(n, base):
        result = runLua("tobase.lua", hex(n), str(base))
        checkTest(toBase(n, base), result, hex(n) + " base " + str(base))
    for base in range(2, 36 + 1):
        test(0, base)
        test(1, base)
        test(-1, base)
    for n, base in zip(srandexpgen(iterations), randgen(iterations, 2, 36 + 1)):
        test(n, base)

def testToNumber(iterations):
    def test(n):
        result = runLua("tonumber.lua", hex(n))
        checkTest(str(n), result)
    test(0)
    test(1)
    test(-1)
    test(255)
    test(256)
    precision = int(runLua("getprecision.lua").stdout)
    if precision == 32:
        mantissa = 24
        test(-0xdeadbe)
    else:
        mantissa = 53
        test(-0x1deadbeefdeadb)
    for n in srandexpgen(iterations, mantissa):
        test(n)

def testToBytes(iterations):
    def test(n, littleEndian, size=None):
        arr = intToByteArray(n, littleEndian, size)
        arrStr = ",".join([str(x) for x in arr])
        endianStr = "LE" if littleEndian else "BE"
        result = runLua("tobytes.lua", hex(n), str(size) if size else "", str(littleEndian))
        checkTest(arrStr, result, hex(n) + f" to {size} bytes ({endianStr})")
    for endianness in [False, True]:
        test(0, endianness)
        test(1, endianness)
        test(-1, endianness)
        test(0, endianness, 0)
        test(0, endianness, 10)
    for n in srandexpgen(iterations):
        test(n, random.choice([True, False]), random.randrange(16))

def testBxor(iterations):
    def test(n1, n2):
        result = runLua("bxor.lua", hex(n1), hex(n2))
        checkTest(hex(ubxor(n1, n2)), result, hex(n1) + " ^ " + hex(n2))
    test(0, 0)
    test(1, 1)
    test(-1, 1)
    test(-1, -1)
    test(1, -1)
    test(0, 123)
    test(0, -123)
    test(123, 0)
    test(1, 123)
    test(123, 1)
    test(0xdeadbeef, 2)
    test(-0xdeadbeef, 0x5000)
    test(-0xdeadbeef, 0xdeadbeef)
    for n1, n2 in zip(srandexpgen(iterations), srandexpgen(iterations)):
        test(n1, n2)

def testBand(iterations):
    def test(n1, n2):
        result = runLua("band.lua", hex(n1), hex(n2))
        checkTest(hex(uband(n1, n2)), result, hex(n1) + " & " + hex(n2))
    test(0, 0)
    test(1, 1)
    test(-1, 1)
    test(-1, -1)
    test(1, -1)
    test(0, 123)
    test(0, -123)
    test(123, 0)
    test(1, 123)
    test(123, 1)
    test(0xdeadbeef, 2)
    test(-0xdeadbeef, 0x5000)
    test(-0xdeadbeef, 0xdeadbeef)
    for n1, n2 in zip(srandexpgen(iterations), srandexpgen(iterations)):
        test(n1, n2)

def testBor(iterations):
    def test(n1, n2):
        result = runLua("bor.lua", hex(n1), hex(n2))
        checkTest(hex(ubor(n1, n2)), result, hex(n1) + " | " + hex(n2))
    test(0, 0)
    test(1, 1)
    test(-1, 1)
    test(-1, -1)
    test(1, -1)
    test(0, 123)
    test(0, -123)
    test(123, 0)
    test(1, 123)
    test(123, 1)
    test(0xdeadbeef, 2)
    test(-0xdeadbeef, 0x5000)
    test(-0xdeadbeef, 0xdeadbeef)
    for n1, n2 in zip(srandexpgen(iterations), srandexpgen(iterations)):
        test(n1, n2)

def testShl(iterations):
    def test(n, shift):
        result = runLua("shl.lua", hex(n), str(shift))
        checkTest(hex(ushl(n, shift)), result, hex(n) + " << " + str(shift))
    test(0, 0)
    test(1, 0)
    test(0, 1)
    test(1, 1)
    test(0xdeadbeef, 7)
    test(0xdeadbeef, 8)
    test(0xdeadbeef, 9)
    test(0xdeadbeef, 15)
    test(0xdeadbeef, 16)
    test(0xdeadbeef, 17)
    test(0xdeadbeef, -17)
    for n1, n2 in zip(srandexpgen(iterations), randgen(iterations, 65)):
        test(n1, n2)

def testShr(iterations):
    def test(n, shift):
        result = runLua("shr.lua", hex(n), str(shift))
        checkTest(hex(ushr(n, shift)), result, hex(n) + " >> " + str(shift))
    test(0, 0)
    test(1, 0)
    test(0, 1)
    test(1, 1)
    test(-1, 1)
    test(0xdeadbeef, 7)
    test(0xdeadbeef, 8)
    test(0xdeadbeef, 9)
    test(0xdeadbeef, 15)
    test(0xdeadbeef, 16)
    test(0xdeadbeef, 17)
    test(0xdeadbeef, -17)
    for n1, n2 in zip(srandexpgen(iterations), randgen(iterations, 65)):
        test(n1, n2)

def testSetBits(iterations):
    def test(n, bits):
        bitlist = [str(bit + 1) for bit in bits]
        result = runLua("setbits.lua", hex(n), *bitlist)
        checkTest(hex(setbits(n, bits)), result, hex(n) + " set bits " + ",".join(bitlist))
    test(0, [0])
    test(1, [0])
    test(1, [64])
    test(0, [])
    for n in srandexpgen(iterations):
        bits = list(randgen(random.randrange(0, 8), 0, 65))
        test(n, bits)

def testUnsetBits(iterations):
    def test(n, bits):
        bitlist = [str(bit + 1) for bit in bits]
        result = runLua("unsetbits.lua", hex(n), *bitlist)
        checkTest(hex(unsetbits(n, bits)), result, hex(n) + " unset bits " + ",".join(bitlist))
    test(0, [0])
    test(1, [0])
    test(1, [64])
    test(0, [])
    test(0, [1])
    test(1, [1])
    test(0xdeadbeef, [])
    for n in srandexpgen(iterations):
        bits = list(randgen(random.randrange(0, 8), 0, 65))
        test(n, bits)

def testGetBit(iterations):
    def test(n, bit):
        result = runLua("getbit.lua", hex(n), str(bit + 1))
        checkTest(str(getbit(n, bit)), result, hex(n) + " bit " + str(bit))
    test(0, 0)
    test(1, 0)
    test(1, 1)
    test(1, 65)
    for n, bit in zip(srandexpgen(iterations), randgen(iterations, 0, 65)):
        test(n, bit)

def testCompare(iterations):
    ops = {
        "==": lambda x, y: x == y,
        "<": lambda x, y: x < y,
        ">": lambda x, y: x > y,
        "<=": lambda x, y: x <= y,
        ">=": lambda x, y: x >= y,
    }
    def test(op, n1, n2):
        result = runLua("compare.lua", op, hex(n1), hex(n2))
        checkTest(str(ops[op](n1, n2)).lower(), result, hex(n1) + f" {op} " + hex(n2))
    for op in ops:
        test(op, 0, 0)
        test(op, 1, 0)
        test(op, 0, 1)
        test(op, 1, 1)
        test(op, -1, 0)
        test(op, 0, -1)
        test(op, -1, -1)
        test(op, 0xdeadbeef, 0xdeadbeef)
        test(op, -0xdeadbeef, 0xdeadbeef)
        test(op, 0xdeadbeef, -0xdeadbeef)
        test(op, -0xdeadbeef, -0xdeadbeef)
    for n1, n2 in zip(srandexpgen(iterations), srandexpgen(iterations)):
        test(random.choice(list(ops)), n1, n2)

def testCastSigned(iterations):
    def test(n, size):
        result = runLua("castsigned.lua", hex(n), str(size))
        actual = str(castSigned(n, size))
        checkTest(actual, result, hex(n) + f" cast signed, size=" + str(size))
    test(0, 0)
    test(0, 1)
    test(0, 8)
    test(1, 1)
    test(1, 8)
    test(-1, 1)
    test(-1, 8)
    test((2 ** 32) - 1, 4)
    for n in srandexpgen(iterations):
        byteCount = math.ceil(n.bit_length() / 8)
        test(n, random.randrange(byteCount, 16))

def testCastUnsigned(iterations):
    def test(n, size):
        result = runLua("castunsigned.lua", hex(n), str(size))
        actual = str(castUnsigned(n, size))
        checkTest(actual, result, hex(n) + f" cast unsigned, size=" + str(size))
    test(0, 0)
    test(0, 1)
    test(0, 8)
    test(1, 1)
    test(1, 8)
    test(-1, 1)
    test(-1, 8)
    test((2 ** 32) - 1, 4)
    for n in srandexpgen(iterations):
        byteCount = math.ceil(n.bit_length() / 8)
        test(n, random.randrange(byteCount, 16))

def testLog2(iterations):
    def test(n):
        result = runLua("log2.lua", hex(n))
        checkTest(hex(int(math.log2(n))), result, hex(n) + " log2 ")
    test(1)
    test(2)
    test(256)
    test(0x10000000)
    for n in randexpgen(iterations):
        test(n + 1)

def testRandgen(iterations):
    for i in range(iterations):
        s = sexp.randgensexp(1, 10)
        sfmt = sexp.formatsexp(s)
        result = runLuaWithTimeout(10, "sexp.lua", sfmt)
        checkTest(hex(sexp.executesexp(s)), result, sfmt)

testsToRun = [
    testFromStringHex,
    testFromStringBin,
    testFromStringBase,
    testFromNumber,
    testFromArray,
    testFromBytes,
    testToBase,
    testToNumber,
    testToBytes,
    testAdd,
    testSub,
    testMul,
    testDiv,
    testMod,
    testPow,
    testLog2,
    testBxor,
    testBand,
    testBor,
    testShl,
    testShr,
    testCompare,
    testSetBits,
    testUnsetBits,
    testGetBit,
    testCastSigned,
    testCastUnsigned,
    testRandgen,
]

iterations = 1000
if len(sys.argv) >= 2:
    iterations = int(sys.argv[1])
runTests(testsToRun, iterations)

totalSuccesses = 0
totalFailures = 0
for resultItem in resultMap.values():
    totalSuccesses += resultItem["successes"]
    totalFailures += resultItem["failures"]
msg = f"Total result: {totalSuccesses} / {totalFailures+totalSuccesses}"
if totalFailures == 0:
    printSuccess(msg)
else:
    printWarning(msg)
    sys.exit(1)
