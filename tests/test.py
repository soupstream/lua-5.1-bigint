#!/usr/bin/env python3
import subprocess
import random
import inspect
import math
import sexp
from testutils import *

def findTestName():
    frame = inspect.currentframe()
    while frame.f_code.co_name not in testNames:
        frame = frame.f_back
    return frame.f_code.co_name

resultMap = {}

def checkTest(expected, result, expression=""):
    if expression != "":
        expression += " == "
    success = True
    testName = findTestName()
    if testName not in resultMap:
        resultMap[testName] = {"successes": 0, "failures": 0}

    if result.returncode != 0:
        print(f"{testName} failure: {expression}{expected} => exit {result.returncode}")
        if result.stderr != "":
            print(result.stderr.strip())
        success = False
    elif expected != result.stdout.strip():
        print(f"{testName} failure: {expression}{expected} != {result.stdout.strip()}")
        success = False

    if success:
        resultMap[testName]["successes"] += 1
    else:
        resultMap[testName]["failures"] += 1

    return success

def runLua(script, *args):
    return subprocess.run(["./" + script, *args], encoding="utf-8", capture_output=True, timeout=1)

def runTests(tests):
    global testNames
    testNames = []
    for test in tests:
        if type(test) == tuple:
            iterations = test[1]
            test = test[0]
        else:
            iterations = None

        testNames.append(test.__name__)
        print("Running " + test.__name__)
        if iterations == None:
            test()
        else:
            test(iterations)

        results = resultMap[test.__name__]
        successes = results["successes"]
        failures = results["failures"]
        print(test.__name__ + f" result: {successes} / {successes+failures}")

def testFromStringHex(iterations=1000):
    def test(n, strOverride=None):
        result = runLua("fromstring.lua", strOverride or hex(n))
        checkTest(hex(n), result)
    test(-1)
    test(0)
    test(0, "-0x0")
    test(1)
    test(256)
    for n in srandexpgen(iterations):
        test(n)

def testFromStringBin(iterations=1000):
    def test(n, strOverride=None):
        result = runLua("fromstring.lua", strOverride or bin(n))
        checkTest(hex(n), result)
    test(-1)
    test(0)
    test(0, "-0b0")
    test(1)
    test(256)
    for n in srandexpgen(iterations):
        test(n)

def testFromStringBase(iterations=1000):
    def test(n, base):
        nstr = toBase(n, base)
        result = runLua("fromstring.lua", nstr, str(base))
        checkTest(hex(n), result, nstr + " base " + str(base))
    for base in range(2, 36 + 1):
        test(-1, base)
        test(0, base)
        test(1, base)
        test(256, base)
    for n, base in zip(srandexpgen(iterations), randgen(iterations, 2, 36 + 1)):
        test(n, base)

def testAdd(iterations=1000):
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

def testSub(iterations=1000):
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

def testMul(iterations=1000):
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

def testDiv(iterations=1000):
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

def testMod(iterations=1000):
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

def testPow(iterations=1000):
    def test(n1, n2):
        result = runLua("pow.lua", hex(n1), hex(n2))
        checkTest(hex(intpow(n1, n2)), result, hex(n1) + " pow " + hex(n2))
    test(0, 123)
    test(0, -1)
    test(1, 123)
    test(123, 1)
    test(123, 0)
    test(0x100, 0x100)
    test(0xdeadbeef, 0x100)
    test(0xdeadbeef, -1)
    for n1, n2 in zip(srandexpgen(iterations), randgen(iterations, -4, 64)):
        test(n1, n2)

def testToBase(iterations=1000):
    def test(n, base):
        result = runLua("tobase.lua", hex(n), str(base))
        checkTest(toBase(n, base), result, hex(n) + " base " + str(base))
    for base in range(2, 36 + 1):
        test(0, base)
        test(1, base)
        test(-1, base)
    for n, base in zip(srandexpgen(iterations), randgen(iterations, 2, 36 + 1)):
        test(n, base)

def testBxor(iterations=1000):
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

def testBand(iterations=1000):
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

def testBor(iterations=1000):
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

def testShl(iterations=1000):
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
    for n1, n2 in zip(srandexpgen(iterations), randgen(iterations, 64)):
        test(n1, n2)

def testShr(iterations=1000):
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
    for n1, n2 in zip(srandexpgen(iterations), randgen(iterations, 64)):
        test(n1, n2)

def testSetBits(iterations=1000):
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

def testUnsetBits(iterations=1000):
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

def testGetBit(iterations=1000):
    def test(n, bit):
        result = runLua("getbit.lua", hex(n), str(bit + 1))
        checkTest(str(getbit(n, bit)), result, hex(n) + " bit " + str(bit))
    test(0, 0)
    test(1, 0)
    test(1, 1)
    test(1, 65)
    for n, bit in zip(srandexpgen(iterations), randgen(iterations, 0, 65)):
        test(n, bit)

def testCompare(iterations=1000):
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

def testRandgen(iterations=1000):
    for i in range(iterations):
        s = sexp.randgensexp(1, 10)
        sfmt = sexp.formatsexp(s)
        result = runLua("sexp.lua", sfmt)
        checkTest(hex(sexp.executesexp(s)), result, sfmt)

testsToRun = [
    testFromStringHex,
    testFromStringBin,
    testFromStringBase,
    testToBase,
    testAdd,
    testSub,
    testMul,
    testDiv,
    testMod,
    testPow,
    testBxor,
    testBand,
    testBor,
    testShl,
    testShr,
    testCompare,
    testSetBits,
    testUnsetBits,
    testGetBit,
    testRandgen,
]

runTests(testsToRun)