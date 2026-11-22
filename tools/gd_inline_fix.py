#!/usr/bin/env python3
"""Expand GDScript 3 one-line suites that use ';' (`if x: a; b`) into real blocks.
In Godot 3 the ';' ends the inline suite, so `b` would run unconditionally."""
import re, sys

KW = re.compile(r'^(\s*)(if|elif|else|for|while|func)\b')

def scan(s):
    """Yield (index, char) for chars at bracket depth 0 and outside strings."""
    depth = 0; q = None; i = 0
    while i < len(s):
        ch = s[i]
        if q:
            if ch == '\\': i += 2; continue
            if ch == q: q = None
        elif ch in '"\'': q = ch
        elif ch == '#': return
        elif ch in '([{': depth += 1
        elif ch in ')]}': depth -= 1
        elif depth == 0: yield i, ch
        i += 1

def header_colon(s):
    for i, ch in scan(s):
        if ch == ':': return i
    return -1

def split_semis(s):
    parts = []; last = 0
    for i, ch in scan(s):
        if ch == ';': parts.append(s[last:i]); last = i + 1
    parts.append(s[last:])
    return [p.strip() for p in parts if p.strip()]

def strip_comment(s):
    for i, ch in scan(s + ' '):
        pass
    # find comment start outside strings
    q = None; i = 0
    while i < len(s):
        ch = s[i]
        if q:
            if ch == '\\': i += 2; continue
            if ch == q: q = None
        elif ch in '"\'': q = ch
        elif ch == '#': return s[:i].rstrip(), s[i:]
        i += 1
    return s, ''

def fix_line(line, ind_unit='\t'):
    m = KW.match(line)
    if not m: return [line]
    code, comment = strip_comment(line)
    c = header_colon(code)
    if c < 0: return [line]
    head = code[:c + 1]; body = code[c + 1:].strip()
    if not body: return [line]
    if m.group(2) == 'func' and '->' in head and False: pass
    stmts = split_semis(body)
    if len(stmts) < 2 and not KW.match(' ' + body if stmts else ''):
        return [line]
    if len(stmts) < 2:
        # nested inline control in a single statement: `else: if x: a; b`
        inner = fix_line(m.group(1) + ind_unit + stmts[0])
        if len(inner) == 1: return [line]
        return [head + (' ' + comment if comment else '')] + inner
    ind = m.group(1) + ind_unit
    out = [head + (' ' + comment if comment else '')]
    for st in stmts:
        out += fix_line(ind + st)
    return out

def main():
    total = 0
    for path in sys.argv[1:]:
        src = open(path).read().split('\n')
        res = []
        for ln in src:
            f = fix_line(ln)
            if len(f) > 1: total += 1
            res += f
        open(path, 'w').write('\n'.join(res))
    print('expanded', total, 'lines')

main()
