#!/usr/bin/env python3
"""Draws the controller button icons for console mode into godot/assets/ui/pad/:
xbox_*.png (A B X Y letters in their colours) and ps_*.png (cross, circle, square, triangle),
plus the shoulder buttons, triggers, sticks, the two middle buttons and the D-pad for both.
They are generic, flat icons (no logos). Needs Pillow. Usage: python3 tools/make-pad-icons.py"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot')
OUT = os.path.join(ROOT, 'assets', 'ui', 'pad')
FONT = os.path.join(ROOT, 'fonts', 'Inter-Bold.ttf')
SS = 4                      # drawn 4x and scaled down for clean edges
DARK = (24, 24, 28, 255)
RING = (255, 255, 255, 60)
WHITE = (245, 245, 247, 255)

def canvas(w, h):
    im = Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)

def save(im, name, w, h):
    im.resize((w, h), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))

def text_center(d, box, txt, size, col):
    f = ImageFont.truetype(FONT, size * SS)
    x0, y0, x1, y1 = d.textbbox((0, 0), txt, font=f)
    cx = (box[0] + box[2]) / 2; cy = (box[1] + box[3]) / 2
    d.text((cx - (x1 - x0) / 2 - x0, cy - (y1 - y0) / 2 - y0), txt, font=f, fill=col)

def face(name, col, draw_mark):
    # a dark round button with a thin coloured ring and the mark in its colour
    s = 64
    im, d = canvas(s, s)
    d.ellipse((2 * SS, 2 * SS, (s - 2) * SS, (s - 2) * SS), fill=DARK, outline=col[:3] + (200,), width=3 * SS)
    draw_mark(d, s * SS, col)
    save(im, name, s, s)

def letter(ch):
    return lambda d, S, col: text_center(d, (0, 0, S, S), ch, 30, col)

def cross(d, S, col):
    m = S * 0.32; w = int(S * 0.075)
    d.line((m, m, S - m, S - m), fill=col, width=w); d.line((S - m, m, m, S - m), fill=col, width=w)

def circle(d, S, col):
    m = S * 0.3
    d.ellipse((m, m, S - m, S - m), outline=col, width=int(S * 0.07))

def square(d, S, col):
    m = S * 0.32
    d.rectangle((m, m, S - m, S - m), outline=col, width=int(S * 0.065))

def triangle(d, S, col):
    cx = S / 2; top = S * 0.28; bot = S * 0.68; hw = S * 0.22
    d.line((cx, top, cx + hw, bot, cx - hw, bot, cx, top), fill=col, width=int(S * 0.065), joint='curve')

def pill(name, txt, w=88, h=52, filled=False):
    im, d = canvas(w, h)
    r = 14 * SS
    d.rounded_rectangle((2 * SS, 2 * SS, (w - 2) * SS, (h - 2) * SS), r, fill=WHITE if filled else DARK, outline=RING if not filled else None, width=2 * SS)
    text_center(d, (0, 0, w * SS, h * SS), txt, 22 if len(txt) <= 2 else (17 if len(txt) <= 5 else 14), DARK if filled else WHITE)
    save(im, name, w, h)

def trigger(name, txt):
    # a trigger: a rounded tab, flat at the bottom
    w, h = 76, 56
    im, d = canvas(w, h)
    d.rounded_rectangle((4 * SS, 2 * SS, (w - 4) * SS, (h - 2) * SS), 18 * SS, fill=DARK, outline=RING, width=2 * SS)
    d.rectangle((4 * SS, (h - 16) * SS, (w - 4) * SS, (h - 2) * SS), fill=DARK)
    d.line((4 * SS, (h - 2) * SS, (w - 4) * SS, (h - 2) * SS), fill=RING, width=2 * SS)
    text_center(d, (0, 0, w * SS, h * SS), txt, 21, WHITE)
    save(im, name, w, h)

def stick(name, txt):
    s = 64
    im, d = canvas(s, s)
    d.ellipse((2 * SS, 2 * SS, (s - 2) * SS, (s - 2) * SS), fill=DARK, outline=RING, width=2 * SS)
    d.ellipse((12 * SS, 12 * SS, (s - 12) * SS, (s - 12) * SS), outline=(255, 255, 255, 110), width=2 * SS)
    text_center(d, (0, 0, s * SS, s * SS), txt, 19, WHITE)
    save(im, name, s, s)

def dpad(name, which):
    s = 64
    im, d = canvas(s, s)
    a = 22 * SS; b = 42 * SS; e0 = 4 * SS; e1 = (s - 4) * SS
    arms = {'up': (a, e0, b, a + 2), 'down': (a, b - 2, b, e1), 'left': (e0, a, a + 2, b), 'right': (b - 2, a, e1, b)}
    for k, r in arms.items():
        d.rounded_rectangle(r, 5 * SS, fill=WHITE if k == which else DARK, outline=RING, width=2 * SS)
    d.rectangle((a, a, b, b), fill=DARK)
    save(im, name, s, s)

def menu_btn(name):
    s = 64
    im, d = canvas(s, s)
    d.ellipse((2 * SS, 2 * SS, (s - 2) * SS, (s - 2) * SS), fill=DARK, outline=RING, width=2 * SS)
    for y in (24, 32, 40):
        d.line((21 * SS, y * SS, 43 * SS, y * SS), fill=WHITE, width=3 * SS)
    save(im, name, s, s)

def view_btn(name):
    s = 64
    im, d = canvas(s, s)
    d.ellipse((2 * SS, 2 * SS, (s - 2) * SS, (s - 2) * SS), fill=DARK, outline=RING, width=2 * SS)
    d.rounded_rectangle((18 * SS, 20 * SS, 38 * SS, 36 * SS), 3 * SS, outline=WHITE, width=3 * SS)
    d.rounded_rectangle((26 * SS, 28 * SS, 46 * SS, 44 * SS), 3 * SS, fill=DARK, outline=WHITE, width=3 * SS)
    save(im, name, s, s)

def main():
    os.makedirs(OUT, exist_ok=True)
    # face buttons
    face('xbox_a', (108, 192, 74, 255), letter('A'))
    face('xbox_b', (232, 78, 64, 255), letter('B'))
    face('xbox_x', (64, 140, 222, 255), letter('X'))
    face('xbox_y', (240, 196, 50, 255), letter('Y'))
    face('ps_a', (134, 170, 236, 255), cross)
    face('ps_b', (236, 108, 108, 255), circle)
    face('ps_x', (226, 140, 210, 255), square)
    face('ps_y', (80, 202, 162, 255), triangle)
    for st, names in (('xbox', ('LB', 'RB', 'LT', 'RT', 'LS', 'RS')), ('ps', ('L1', 'R1', 'L2', 'R2', 'L3', 'R3'))):
        pill(st + '_lb', names[0]); pill(st + '_rb', names[1])
        trigger(st + '_lt', names[2]); trigger(st + '_rt', names[3])
        stick(st + '_ls', names[4]); stick(st + '_rs', names[5])
        for k in ('up', 'down', 'left', 'right'):
            dpad(st + '_' + k, k)
        dpad(st + '_dpad', None)
    menu_btn('xbox_menu'); view_btn('xbox_view')
    pill('ps_menu', 'OPTIONS', 112, 52); pill('ps_view', 'CREATE', 104, 52)
    print('icons in', os.path.relpath(OUT))

if __name__ == '__main__':
    main()
