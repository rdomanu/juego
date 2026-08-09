import sys

path = sys.argv[1] if len(sys.argv) > 1 else "src/main/modo_construccion.gd"
src = open(path, encoding="utf-8").read()
depth = {"(": 0, "[": 0, "{": 0}
pairs = {")": "(", "]": "[", "}": "{"}
line = 1
in_str = None
i = 0
n = len(src)
while i < n:
    c = src[i]
    if c == "\n":
        line += 1
    if in_str:
        if c == "\\":
            i += 2
            continue
        if c == in_str:
            in_str = None
        i += 1
        continue
    if c == "#":
        j = src.find("\n", i)
        i = j if j != -1 else n
        continue
    if c == '"' or c == "'":
        in_str = c
        i += 1
        continue
    if c in depth:
        depth[c] += 1
    elif c in pairs:
        depth[pairs[c]] -= 1
        if depth[pairs[c]] < 0:
            print("Unbalanced close at line", line, "char", c)
    i += 1
print(depth)
