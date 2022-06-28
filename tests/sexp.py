#!/usr/bin/env python3
import sys
import random
import json
from testutils import *

unopMap = {
    "-": lambda x: -x,
    "abs": lambda x: -x,
}
binopMap = {
    "+": lambda x, y: x + y,
    "-": lambda x, y: x - y,
    "*": lambda x, y: x * y,
    "/": intdiv,
    "%": intmod,
    "&": uband,
    "|": ubor,
    "^": ubxor,
    "pow": intpow,
    "<<": ushl,
    ">>": ushr,
}
comparatorMap = {
    "==": lambda x, y: x == y,
    "~=": lambda x, y: x != y,
    "<": lambda x, y: x < y,
    ">": lambda x, y: x > y,
    "<=": lambda x, y: x <= y,
    ">=": lambda x, y: x >= y,
}
opMapMap = {
    1: unopMap,
    2: binopMap
}
largeOperators = ["pow", "<<", ">>"]

def executesexp(sexp):
    symbol = sexp[0]
    operands = [executesexp(o) if type(o) == list else o for o in sexp[1:]]
    op = opMapMap[len(operands)][symbol]
    return op(*operands)

def randgensexp(mindepth=1, maxdepth=3, largeOperator=False):
    imax = len(binopMap) + len(unopMap)
    if mindepth <= 0:
        imax += 1
    if maxdepth <= 0 or largeOperator:
        i = imax + 1
    else:
        i = random.randrange(imax)

    if i < len(unopMap):
        op = random.choice(list(unopMap))
        return [op, randgensexp(mindepth - 1, maxdepth - 1, op in largeOperators)]
    elif i - len(unopMap) < len(binopMap):
        op = random.choice(list(binopMap))
        return [op, randgensexp(mindepth - 1, maxdepth - 1, op in largeOperators), randgensexp(mindepth - 1, maxdepth - 1, op in largeOperators)]
    else:
        if largeOperator:
            return random.randrange(256)
        else:
            return srandexp(64)

def formatsexp(sexp):
    out = "{"
    for i in range(len(sexp)):
        if i == 0:
            out += f'"{sexp[i]}"'
        elif type(sexp[i]) == list:
            out += formatsexp(sexp[i])
        else:
            out += f'"{hex(sexp[i])}"'
        if i < len(sexp) - 1:
            out += ", "
    out += "}"
    return out

if __name__ == "__main__":
    if len(sys.argv) > 1:
        s = sys.argv[1].replace("{", "[").replace("}", "]")
        s = json.loads(s)
    else:
        s = randgensexp()
    print(formatsexp(s))
    print(hex(executesexp(s)))
