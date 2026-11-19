#!/usr/bin/env python3
"""Génère les graphismes de Bunny Adventure (illustrations cartoon ombrées).
Usage : python3 tools/make_art.py assets
Dépendances : numpy, pillow, opencv-python-headless
"""
import math, os, random, sys
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageChops

OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else "assets"
ONLY = set(sys.argv[2:])  # pour ne régénérer que certains éléments


def rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


# ---------------------------------------------------------------- toile ---
class Cv:
    def __init__(self, w, h, s=4):
        self.w, self.h, self.s = w, h, s
        self.px = np.zeros((h * s, w * s, 4), np.float32)

    def mask(self):
        return Image.new("L", (self.w * self.s, self.h * self.s), 0)

    def over(self, x0, y0, col, a):
        reg = self.px[y0:y0 + a.shape[0], x0:x0 + a.shape[1]]
        da = reg[..., 3:4]
        sa = a[..., None]
        oa = sa + da * (1 - sa)
        rgbo = (col * sa + reg[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
        reg[..., :3] = rgbo
        reg[..., 3:4] = oa

    def rotate(self, deg, cx, cy):
        m = cv2.getRotationMatrix2D((cx * self.s, cy * self.s), deg, 1.0)
        pm = self.px.copy()
        pm[..., :3] *= pm[..., 3:4]
        pm = cv2.warpAffine(pm, m, (self.w * self.s, self.h * self.s), flags=cv2.INTER_LINEAR)
        a = pm[..., 3:4]
        pm[..., :3] = pm[..., :3] / np.maximum(a, 1e-6)
        self.px = pm

    def image(self, k=1.0):
        w, h = int(round(self.w * k)), int(round(self.h * k))
        pm = self.px.copy()
        pm[..., :3] *= pm[..., 3:4]
        pm = cv2.resize(pm, (w, h), interpolation=cv2.INTER_AREA)
        a = pm[..., 3:4]
        pm[..., :3] = pm[..., :3] / np.maximum(a, 1e-6)
        out = np.clip(pm * 255 + 0.5, 0, 255).astype(np.uint8)
        return Image.fromarray(out, "RGBA")


# --------------------------------------------------------------- formes ---
def spline(pts, n=10, closed=False):
    P = list(pts)
    if closed:
        P = [P[-1]] + P + [P[0], P[1]]
    else:
        P = [P[0]] + P + [P[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for j in range(n):
            t = j / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t +
                                    (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 +
                                    (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    if not closed:
        out.append(tuple(pts[-1]))
    return out


def M_poly(cv, pts, smooth=False):
    m = cv.mask()
    if smooth:
        pts = spline(pts, 10, True)
    ImageDraw.Draw(m).polygon([(x * cv.s, y * cv.s) for x, y in pts], fill=255)
    return m


def M_ell(cv, cx, cy, rx, ry, rot=0.0):
    r = math.radians(rot)
    c, s = math.cos(r), math.sin(r)
    pts = []
    for i in range(72):
        a = 2 * math.pi * i / 72
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return M_poly(cv, pts)


def M_stroke(cv, pts, width, smooth=True):
    m = cv.mask()
    d = ImageDraw.Draw(m)
    P = spline(pts, 10) if smooth and len(pts) > 2 else pts
    P = [(x * cv.s, y * cv.s) for x, y in P]
    d.line(P, fill=255, width=int(width * cv.s), joint="curve")
    r = width * cv.s / 2
    for x, y in (P[0], P[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return m


def U(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.lighter(out, m)
    return out


def SUB(a, b):
    return ImageChops.subtract(a, b)


def AND(a, b):
    return ImageChops.multiply(a, b)


# -------------------------------------------------------------- peinture ---
LIGHT = np.array([-0.55, -0.70, 0.62], np.float32)
LIGHT /= np.linalg.norm(LIGHT)


def paint(cv, m, col, col2=None, sigma=8.0, k=1.0, outline=3.0, ocol="#4a3228",
          spec=0.25, ambient=0.5, tint=(0.80, 0.78, 1.0), alpha=1.0, gdir=(0.0, 1.0), light=None):
    s = cv.s
    bb = m.getbbox()
    if bb is None:
        return
    pad = int((outline * 1.4 + sigma * 3.0) * s) + 4
    x0, y0 = max(bb[0] - pad, 0), max(bb[1] - pad, 0)
    x1, y1 = min(bb[2] + pad, m.width), min(bb[3] + pad, m.height)
    mc = np.asarray(m.crop((x0, y0, x1, y1)), np.float32) / 255.0
    if outline > 0:
        sg = outline * s / 1.86
        dil = (cv2.GaussianBlur(mc, (0, 0), sg) > 0.031).astype(np.float32)
        cv.over(x0, y0, rgb(ocol), dil * alpha)
    h, w = mc.shape
    c1 = rgb(col)
    if col2 is None:
        base = np.ones((h, w, 3), np.float32) * c1
    else:
        c2 = rgb(col2)
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        cx, cy = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
        ln = max(((bb[2] - bb[0]) * abs(gdir[0]) + (bb[3] - bb[1]) * abs(gdir[1])), 1)
        t = (((xx - cx) * gdir[0] + (yy - cy) * gdir[1]) / ln + 0.5).clip(0, 1)[..., None]
        base = c1 * (1 - t) + c2 * t
    hf = cv2.GaussianBlur(mc, (0, 0), sigma * s)
    gy, gx = np.gradient(hf)
    kk = k * sigma * s * 1.4
    nx, ny = -gx * kk, -gy * kk
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + 1.0)
    nx, ny, nz = nx * inv, ny * inv, inv
    L = LIGHT if light is None else np.array(light, np.float32) / np.linalg.norm(light)
    f = ((nx * L[0] + ny * L[1] + nz * L[2]) / L[2]).clip(0, 1.5)
    shade = ambient + (1 - ambient) * f
    colr = base * shade[..., None]
    sh = (1 - f).clip(0, 1)[..., None]
    colr = colr * (1 + (np.array(tint, np.float32) - 1) * sh * 0.9)
    hl = (f - 1.04).clip(0, 1) ** 1.4 * spec * 2.2
    colr = colr + hl[..., None]
    cv.over(x0, y0, colr.clip(0, 1), mc * alpha)


def flat(cv, m, col, alpha=1.0, blur=0.0):
    bb = m.getbbox()
    if bb is None:
        return
    s = cv.s
    pad = int(blur * s * 3) + 4
    x0, y0 = max(bb[0] - pad, 0), max(bb[1] - pad, 0)
    x1, y1 = min(bb[2] + pad, m.width), min(bb[3] + pad, m.height)
    mc = np.asarray(m.crop((x0, y0, x1, y1)), np.float32) / 255.0
    if blur > 0:
        mc = cv2.GaussianBlur(mc, (0, 0), blur * s)
    cv.over(x0, y0, rgb(col) if isinstance(col, str) else np.array(col, np.float32), mc * alpha)


def save(img, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    img.save(os.path.join(OUT_DIR, name), optimize=True)
    print("ok", name, img.size)


def sheet(frames, cols):
    fw, fh = frames[0].size
    rows = (len(frames) + cols - 1) // cols
    sh = Image.new("RGBA", (fw * cols, fh * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sh.paste(f, ((i % cols) * fw, (i // cols) * fh))
    return sh


def want(name):
    return (not ONLY) or name in ONLY


# ================================================================ LAPIN ===
FUR = ("#fffaf3", "#eedcc8")
FUR_D = ("#f4e6d6", "#d9c0aa")
OL = "#5a4036"
PINK = ("#ffc6d2", "#ff93ab")

STAGES = {
    1: dict(bx=148, by=240, brx=62, bry=50, hx=202, hy=170, hrx=60, hry=54, ear=60, earw=18,
            thx=-22, thr=38, arm=22, scale=0.64),
    2: dict(bx=144, by=240, brx=68, bry=54, hx=206, hy=170, hrx=54, hry=49, ear=62, earw=17,
            thx=-24, thr=42, arm=24, scale=0.80),
    3: dict(bx=138, by=240, brx=78, bry=60, hx=210, hy=168, hrx=52, hry=47, ear=60, earw=17,
            thx=-26, thr=48, arm=29, scale=1.0),
}

POSES = {
    "idle0": dict(),
    "idle1": dict(bob=-3, breath=2, ear=4),
    "run0": dict(bob=-2, fx=24, ff=0, bx=-26, bf=12, ear=-22, lean=4),
    "run1": dict(bob=-8, fx=6, ff=16, bx=-6, bf=2, ear=-28, lean=5),
    "run2": dict(bob=-2, fx=-24, ff=0, bx=26, bf=0, ear=-22, lean=4),
    "run3": dict(bob=-8, fx=-4, ff=2, bx=2, bf=16, ear=-28, lean=5),
    "jump": dict(bob=-4, fx=34, ff=26, bx=-34, bf=40, ear=-42, lean=-8, stretch=1.07),
    "fall": dict(bob=0, fx=18, ff=6, bx=-10, bf=10, ear=18, lean=6, stretch=1.04),
    "attack": dict(bob=0, att=1, ear=-14, lean=-6),
    "hurt": dict(bob=2, ear=-58, lean=-16, eyes="x", fx=-10, bx=12),
}


def rabbit(stage, pose):
    st = STAGES[stage]
    p = dict(bob=0, breath=0, ear=0, fx=0, ff=0, bx=0, bf=0, lean=0, att=0, eyes="open", stretch=1.0)
    p.update(POSES[pose])
    cv = Cv(320, 320)
    G = 300  # sol
    bob = p["bob"]
    bx, by = st["bx"], st["by"] + bob
    brx, bry = st["brx"] + p["breath"], st["bry"] * (1.0 / p["stretch"] if p["stretch"] > 1 else 1.0)
    brx *= p["stretch"]
    hx, hy = st["hx"] + (p["stretch"] - 1) * 40, st["hy"] + bob + (3 if pose.startswith("run") else 0)

    # ombre portée douce
    flat(cv, M_ell(cv, bx + 10, G + 2, 100, 10), (0, 0, 0), 0.0)

    # queue
    tx, ty = bx - brx + 8, by - 8 + bob * 0.2
    paint(cv, M_ell(cv, tx, ty, 22, 21), "#ffffff", "#efe2d2", sigma=7, outline=3, ocol=OL, spec=0.3)

    # oreilles (derrière la tête)
    er = p["ear"]
    ex0, ey0 = hx - 6, hy - st["hry"] + 8
    for i, (dx, rot, shade) in enumerate(((-10, -8 + er * 0.9, True), (16, 10 + er, False))):
        ang = math.radians(rot)
        L = st["ear"]
        cxe = ex0 + dx + math.sin(ang) * L * 0.85
        cye = ey0 - math.cos(ang) * L * 0.85
        m = M_ell(cv, cxe, cye, st["earw"], L, rot)
        paint(cv, m, FUR[0], FUR[1] if not shade else FUR_D[1], sigma=7, outline=3, ocol=OL, spec=0.15,
              gdir=(0, 1))
        mi = M_ell(cv, cxe + math.sin(ang) * 4, cye - math.cos(ang) * 2, st["earw"] * 0.5, L * 0.78, rot)
        paint(cv, mi, PINK[0], PINK[1], sigma=5, outline=0, spec=0.1, ambient=0.6)

    # corps
    tuft = M_poly(cv, [(bx + brx - 22, by - 6), (bx + brx + 8, by + 10), (bx + brx - 4, by + 12),
                       (bx + brx + 2, by + 26), (bx + brx - 18, by + 24)], False)
    body = U(M_ell(cv, bx, by, brx, bry, -4), tuft)
    paint(cv, body, FUR[0], FUR[1], sigma=15, k=1.1, outline=3.2, ocol=OL, spec=0.25)
    # ventre clair
    flat(cv, AND(M_ell(cv, bx + 12, by + bry * 0.55, brx * 0.7, bry * 0.5), M_ell(cv, bx, by, brx - 3, bry - 3)),
         (1, 1, 1), 0.55, blur=5)

    # patte arrière (cuisse + pied)
    thx, thy = bx + st["thx"] + p["bx"] * 0.3, by + 16
    thigh = M_ell(cv, thx, thy, st["thr"], st["thr"] * 0.95)
    footx = thx + 34 + p["bx"]
    footy = G - 12 - p["bf"]
    foot = M_ell(cv, footx, footy, 40 * (st["thr"] / 38) ** 0.6, 13, -p["bf"] * 0.6)
    paint(cv, foot, FUR[0], FUR_D[1], sigma=6, outline=3, ocol=OL, spec=0.15)
    paint(cv, thigh, FUR[0], FUR_D[1], sigma=14, k=1.1, outline=3.2, ocol=OL, spec=0.25)
    # coussinet
    flat(cv, M_ell(cv, footx + 8, footy + 4, 14, 6, -p["bf"] * 0.6), PINK[1], 0.55, blur=1)

    # patte avant
    sx, sy = bx + brx * 0.55, by + 6
    if p["att"]:
        px_, py_ = hx + 78, hy + 26
        arm = M_stroke(cv, [(sx, sy), (sx + 40, sy - 6), (px_ - 12, py_ - 6)], st["arm"])
        paw = M_ell(cv, px_, py_, st["arm"] * 0.8, st["arm"] * 0.68, -12)
    else:
        px_ = sx + 16 + p["fx"]
        py_ = G - 10 - p["ff"]
        arm = M_stroke(cv, [(sx, sy), ((sx + px_) / 2 + 4, (sy + py_) / 2), (px_, py_ - 8)], st["arm"])
        paw = M_ell(cv, px_ + 4, py_, st["arm"] * 0.78, st["arm"] * 0.55)
    paint(cv, U(arm, paw), FUR[0], FUR_D[1], sigma=8, outline=3.2, ocol=OL, spec=0.2)

    # tête = crâne + museau + touffe de joue
    cheek = M_poly(cv, [(hx - 38, hy + 26), (hx - 20, hy + 52), (hx - 14, hy + 40), (hx - 4, hy + 58), (hx + 6, hy + 44),
                        (hx + 6, hy + 20)], False)
    skull = M_ell(cv, hx, hy, st["hrx"], st["hry"], -4)
    muzzle = M_ell(cv, hx + st["hrx"] * 0.68, hy + st["hry"] * 0.36, st["hrx"] * 0.5, st["hry"] * 0.44, 8)
    head = U(skull, muzzle, cheek)
    paint(cv, head, FUR[0], FUR[1], sigma=14, k=1.15, outline=3.4, ocol=OL, spec=0.3)

    # intérieur d'oreille (haut de tête, léger dégradé)
    # joue rose
    cxk, cyk = hx + st["hrx"] * 0.38, hy + st["hry"] * 0.46
    flat(cv, M_ell(cv, cxk, cyk, 15, 10), (1.0, 0.55, 0.65), 0.55, blur=4)

    # œil
    ex, ey = hx + st["hrx"] * 0.42, hy - st["hry"] * 0.08
    erx, ery = st["hrx"] * 0.27, st["hry"] * 0.40
    if p["eyes"] == "x":
        m = M_stroke(cv, [(ex - 9, ey - 9), (ex + 9, ey + 9)], 4.5, False)
        m2 = M_stroke(cv, [(ex - 9, ey + 9), (ex + 9, ey - 9)], 4.5, False)
        flat(cv, U(m, m2), "#3a2420")
    else:
        paint(cv, M_ell(cv, ex, ey, erx, ery), "#ffffff", "#eef0f5", sigma=5, outline=2.4, ocol=OL, spec=0.0, ambient=0.75)
        ix, iy = ex + 3, ey + 2
        paint(cv, M_ell(cv, ix, iy, erx * 0.74, ery * 0.76), "#a8683a", "#4a2a18", sigma=5, outline=0, spec=0.0, ambient=0.8)
        flat(cv, M_ell(cv, ix + 1, iy + 1, erx * 0.42, ery * 0.46), "#1a0f0c")
        flat(cv, M_ell(cv, ix - 4, iy - 6, erx * 0.26, erx * 0.26), "#ffffff")
        flat(cv, M_ell(cv, ix + 5, iy + 6, erx * 0.12, erx * 0.12), "#ffffff", 0.9)
        # paupière / cil
        flat(cv, M_stroke(cv, [(ex - erx, ey - ery * 0.55), (ex, ey - ery * 1.02), (ex + erx * 0.9, ey - ery * 0.6)], 2.6), OL, 0.9)

    # nez, bouche, moustaches
    nxp, nyp = hx + st["hrx"] * 0.68 + st["hrx"] * 0.40, hy + st["hry"] * 0.30
    paint(cv, M_ell(cv, nxp, nyp, 8.5, 6.5), "#ff9bb0", "#e8607f", sigma=3, outline=1.8, ocol="#7a3a4a", spec=0.5, ambient=0.7)
    flat(cv, M_stroke(cv, [(nxp - 2, nyp + 7), (nxp - 5, nyp + 14), (nxp - 13, nyp + 15)], 2.2), "#7a4a44", 0.9)
    flat(cv, M_stroke(cv, [(nxp - 2, nyp + 7), (nxp + 1, nyp + 14), (nxp + 6, nyp + 14)], 2.2), "#7a4a44", 0.9)
    for dy, a in ((-4, -10), (4, 0), (12, 12)):
        flat(cv, M_stroke(cv, [(nxp - 12, nyp + dy), (nxp + 18, nyp + dy + a * 0.6), (nxp + 38, nyp + dy + a)], 1.8), "#8a7468", 0.85)

    # accessoires de stade
    if stage == 3:
        # bandeau doré + gemme
        pts = [(hx - st["hrx"] * 0.55, hy - st["hry"] * 0.78), (hx, hy - st["hry"] * 1.02), (hx + st["hrx"] * 0.55, hy - st["hry"] * 0.66)]
        paint(cv, M_stroke(cv, pts, 8), "#ffd966", "#d8962a", sigma=3, outline=2.2, ocol="#6a4410", spec=0.5)
        gx_, gy_ = pts[1][0] + 10, pts[1][1] + 3
        paint(cv, M_ell(cv, gx_, gy_, 6.5, 7.5), "#ff6a7a", "#b01f3a", sigma=3, outline=1.6, ocol="#5a1020", spec=0.8)
    if stage >= 2:
        sc = "#e84a4a" if stage == 2 else "#3d8cf0"
        sc2 = "#b52a2a" if stage == 2 else "#2460b8"
        kx, ky = hx - 26, hy + st["hry"] * 0.98
        flap = 6 * math.sin(len(pose) * 1.7) + (12 if pose.startswith("run") else 0)
        L = 40 if stage == 2 else 60
        tail = [(kx - 4, ky - 4), (kx - L * 0.5, ky + flap * 0.3 - 6), (kx - L, ky + flap + 2),
                (kx - L + 8, ky + flap + 20), (kx - L * 0.45, ky + 14), (kx, ky + 12)]
        paint(cv, M_poly(cv, tail, True), sc, sc2, sigma=4, outline=2.8, ocol="#3a1a1a", spec=0.2)
        paint(cv, M_ell(cv, kx, ky + 4, 17, 11, -10), sc, sc2, sigma=4, outline=2.8, ocol="#3a1a1a", spec=0.35)
        paint(cv, M_ell(cv, kx + 18, ky + 9, 14, 8, 20), sc, sc2, sigma=4, outline=2.8, ocol="#3a1a1a", spec=0.3)

    if p["lean"]:
        cv.rotate(-p["lean"], 160, G)
    return cv.image(st["scale"])


def hry_f(st):
    return st["hry"]


def make_rabbits():
    for stage in (1, 2, 3):
        name = "rabbit%d.png" % stage
        if not want(name):
            continue
        frames = [rabbit(stage, n) for n in ("idle0", "idle1", "run0", "run1", "run2", "run3", "jump", "fall", "attack", "hurt")]
        save(sheet(frames, 5), name)



# ============================================================ ENNEMIS ===
def limb(cv, pts, w, c1, c2, ocol, paw=True, sigma=6):
    m = M_stroke(cv, pts, w)
    if paw:
        x, y = pts[-1]
        m = U(m, M_ell(cv, x + w * 0.25, y, w * 0.85, w * 0.5))
    paint(cv, m, c1, c2, sigma=sigma, outline=3.0, ocol=ocol, spec=0.15)


def dog(kind, ph):
    cv = Cv(360, 260)
    G = 246
    OLD = "#3a2214"
    lunge = kind == "lunge"
    sw = [math.sin(ph) * 30, math.sin(ph + math.pi) * 30]
    lf = [max(0, math.cos(ph)) * 14, max(0, math.cos(ph + math.pi)) * 14]
    if lunge:
        sw = [46, -48]
        lf = [34, 34]
    by = 150 - (14 if lunge else 0)
    # pattes lointaines
    for x0, i in ((112, 1), (232, 0)):
        pts = [(x0, by + 30), (x0 + sw[i] * 0.5, by + 70 - lf[i] * 0.3), (x0 + sw[i], G - 8 - lf[i])]
        limb(cv, pts, 22, "#a56c3a", "#6b4020", OLD)
    # queue
    tw = math.sin(ph * 2) * 8
    paint(cv, M_stroke(cv, [(84, by - 10), (56, by - 40 + tw), (50, by - 78 + tw)], 17), "#c98d52", "#8f5a30", sigma=5, outline=3, ocol=OLD)
    # corps
    body = U(M_ell(cv, 170, by, 94, 52, -3 if not lunge else -10), M_ell(cv, 226, by + 8, 52, 50))
    paint(cv, body, "#d39a5c", "#8a5530", sigma=18, k=1.1, outline=3.4, ocol=OLD, spec=0.25)
    flat(cv, AND(M_ell(cv, 190, by + 44, 80, 22), M_ell(cv, 170, by, 90, 50)), "#f6dcae", 0.7, blur=5)
    # taches
    flat(cv, AND(M_ell(cv, 150, by - 30, 40, 22, 10), M_ell(cv, 170, by, 90, 50)), "#6b3f20", 0.55, blur=3)
    # pattes proches
    for x0, i in ((130, 0), (252, 1)):
        pts = [(x0, by + 30), (x0 + sw[i] * 0.5, by + 72 - lf[i] * 0.3), (x0 + sw[i], G - 8 - lf[i])]
        limb(cv, pts, 25, "#d39a5c", "#9b6335", OLD)
    # collier
    paint(cv, M_stroke(cv, [(244, by - 36), (262, by + 4), (264, by + 24)], 15), "#e84040", "#a82020", sigma=3, outline=2.6, ocol="#3a1010", spec=0.4)
    paint(cv, M_ell(cv, 266, by + 34, 9, 9), "#ffd966", "#d8962a", sigma=3, outline=2.2, ocol="#6a4410", spec=0.6)
    # oreille
    hx, hy = 282, by - 34
    paint(cv, M_poly(cv, [(hx - 26, hy - 36), (hx - 6, hy - 52), (hx + 8, hy - 20), (hx - 14, hy + 30), (hx - 38, hy + 6)], True),
          "#9b6335", "#5b341c", sigma=7, outline=3, ocol=OLD, spec=0.15)
    # tête + museau
    skull = M_ell(cv, hx, hy, 50, 44, -6)
    snout = M_ell(cv, hx + 40, hy + 18, 38, 26, 10)
    paint(cv, U(skull, snout), "#d39a5c", "#8a5530", sigma=13, k=1.1, outline=3.4, ocol=OLD, spec=0.3)
    flat(cv, AND(M_ell(cv, hx + 44, hy + 26, 38, 18, 8), U(skull, snout)), "#f6dcae", 0.8, blur=3)
    # bouche et dents
    mo = 26 if lunge else 6
    flat(cv, M_stroke(cv, [(hx + 74, hy + 28), (hx + 44, hy + 34 + mo * 0.2), (hx + 20, hy + 30 + mo * 0.1)], 4), "#3a1a10")
    if lunge:
        paint(cv, M_poly(cv, [(hx + 74, hy + 30), (hx + 30, hy + 32), (hx + 40, hy + 30 + mo), (hx + 70, hy + 30 + mo * 0.8)], True), "#7a1f2a", "#3a0a12", sigma=4, outline=2.4, ocol=OLD)
    for tx in (hx + 40, hx + 54, hx + 66):
        flat(cv, M_poly(cv, [(tx - 5, hy + 32), (tx + 5, hy + 32), (tx, hy + 46 + (6 if lunge else 0))]), "#ffffff")
    # nez
    paint(cv, M_ell(cv, hx + 76, hy + 12, 13, 10, -8), "#3a3a42", "#101014", sigma=3, outline=1.8, ocol="#000000", spec=0.7, ambient=0.8)
    # œil en colère
    ex, ey = hx + 14, hy - 8
    paint(cv, M_ell(cv, ex, ey, 12, 13), "#ffffff", "#f0f0f5", sigma=4, outline=2.4, ocol=OLD, spec=0, ambient=0.8)
    flat(cv, M_ell(cv, ex + 3, ey + 2, 7, 8), "#2a1408")
    flat(cv, M_ell(cv, ex + 1, ey - 2, 2.5, 2.5), "#ffffff")
    flat(cv, M_stroke(cv, [(ex - 18, ey - 14), (ex + 14, ey - 3)], 6, False), "#3a2214")
    # moustaches
    if lunge:
        cv.rotate(8, 180, G)
    return cv.image(0.5)


def fox(kind, ph):
    cv = Cv(380, 260)
    G = 246
    OLD = "#4a2010"
    lunge = kind == "lunge"
    sw = [math.sin(ph) * 32, math.sin(ph + math.pi) * 32]
    lf = [max(0, math.cos(ph)) * 16, max(0, math.cos(ph + math.pi)) * 16]
    if lunge:
        sw = [52, -54]
        lf = [40, 40]
    by = 150 - (16 if lunge else 0)
    OR = ("#f58a2a", "#c85a14")
    for x0, i in ((112, 1), (236, 0)):
        pts = [(x0, by + 26), (x0 + sw[i] * 0.5, by + 66 - lf[i] * 0.3), (x0 + sw[i], G - 8 - lf[i])]
        limb(cv, pts, 19, "#d86e1e", "#7a3a10", OLD)
    # queue touffue
    tw = math.sin(ph * 2) * 6
    tail = [(92, by + 4), (50, by + 10 + tw), (14, by - 26 + tw), (8, by - 70 + tw), (40, by - 86 + tw),
            (70, by - 56 + tw), (96, by - 28)]
    paint(cv, M_poly(cv, tail, True), "#ff9a3a", "#c85a14", sigma=14, k=1.1, outline=3.4, ocol=OLD, spec=0.3)
    tip = AND(M_ell(cv, 28, by - 82 + tw, 34, 24, -30), M_poly(cv, tail, True))
    flat(cv, tip, "#fffaf0", 1.0)
    # corps
    body = U(M_ell(cv, 172, by, 90, 38, -3), M_ell(cv, 232, by + 4, 46, 40))
    paint(cv, body, OR[0], OR[1], sigma=16, k=1.1, outline=3.4, ocol=OLD, spec=0.3)
    flat(cv, AND(M_ell(cv, 232, by + 26, 44, 26), body), "#fff6e6", 0.95, blur=2)
    for x0, i in ((130, 0), (254, 1)):
        pts = [(x0, by + 26), (x0 + sw[i] * 0.5, by + 66 - lf[i] * 0.3), (x0 + sw[i], G - 8 - lf[i])]
        limb(cv, pts, 21, "#f58a2a", "#a84a10", OLD)
        # chaussette sombre
        flat(cv, AND(M_stroke(cv, [(pts[1][0], pts[1][1] + 10), pts[2]], 26), M_ell(cv, pts[2][0] + 5, pts[2][1] - 10, 22, 30)), "#2a1810", 0.95)
    # oreilles
    hx, hy = 286, by - 30
    for ox, h_ in ((-22, 64), (10, 70)):
        ear = M_poly(cv, [(hx + ox - 16, hy - 24), (hx + ox + 2, hy - 24 - h_), (hx + ox + 22, hy - 20)], False)
        paint(cv, ear, OR[0], OR[1], sigma=7, outline=3.2, ocol=OLD, spec=0.2)
        flat(cv, AND(M_poly(cv, [(hx + ox - 8, hy - 26), (hx + ox + 2, hy - 24 - h_ * 0.72), (hx + ox + 14, hy - 24)], False), ear), "#2a1810", 0.95)
    # tête + museau pointu
    skull = M_ell(cv, hx, hy, 42, 36, -5)
    snout = M_poly(cv, [(hx + 10, hy - 14), (hx + 78, hy + 18), (hx + 74, hy + 30), (hx + 14, hy + 34)], True)
    paint(cv, U(skull, snout), OR[0], OR[1], sigma=11, k=1.1, outline=3.4, ocol=OLD, spec=0.3)
    flat(cv, AND(M_poly(cv, [(hx - 10, hy + 10), (hx + 78, hy + 22), (hx + 70, hy + 33), (hx + 10, hy + 40), (hx - 22, hy + 30)], True), U(skull, snout)), "#fff6e6", 0.95, blur=1)
    paint(cv, M_ell(cv, hx + 76, hy + 20, 9, 8), "#33333c", "#08080c", sigma=3, outline=1.6, ocol="#000", spec=0.7, ambient=0.8)
    mo = 16 if lunge else 0
    flat(cv, M_stroke(cv, [(hx + 70, hy + 32 + mo * 0.4), (hx + 34, hy + 36 + mo * 0.3)], 3.4), "#3a1a10")
    if lunge:
        for tx in (hx + 44, hx + 58):
            flat(cv, M_poly(cv, [(tx - 4, hy + 34), (tx + 4, hy + 34), (tx, hy + 46)]), "#ffffff")
    # œil rusé
    ex, ey = hx + 20, hy - 6
    paint(cv, M_ell(cv, ex, ey, 11, 8, 16), "#ffe36a", "#e0a820", sigma=3, outline=2.2, ocol=OLD, spec=0.3, ambient=0.8)
    flat(cv, M_ell(cv, ex + 2, ey, 2.6, 7, 14), "#1a0e08")
    flat(cv, M_stroke(cv, [(ex - 16, ey - 11), (ex + 12, ey - 3)], 5.4, False), "#2a1408")
    if lunge:
        cv.rotate(8, 190, G)
    return cv.image(0.5)


def bird(frame):
    cv = Cv(300, 240)
    OLD = "#14305a"
    ang = [-78, -22, 34, -22][frame]
    bob = [0, 4, 8, 4][frame]
    # queue
    for a, L in ((-8, 62), (4, 70), (16, 60)):
        r = math.radians(a)
        x1, y1 = 100 - L * math.cos(r), 140 + bob + L * math.sin(r) * -0.2 + a * 0.4
        paint(cv, M_stroke(cv, [(112, 134 + bob), (x1, y1)], 18), "#2d6fd8", "#16408f", sigma=5, outline=2.8, ocol=OLD)
    # aile lointaine
    def wing(a, scale, far):
        r = math.radians(a)
        rx, ry = 140, 112 + bob
        tx, ty = rx + math.cos(r) * 118 * scale - 30, ry + math.sin(r) * 118 * scale
        nx, ny = -math.sin(r), math.cos(r)
        w = 34
        pts = [(rx - 24, ry), (rx + (tx - rx) * 0.45 + nx * w, ry + (ty - ry) * 0.45 + ny * w), (tx, ty),
               (rx + (tx - rx) * 0.45 - nx * w * 0.6, ry + (ty - ry) * 0.45 - ny * w * 0.6)]
        c1, c2 = ("#3a7fe0", "#1d4fa8") if far else ("#4a92f0", "#2a63c0")
        paint(cv, M_poly(cv, pts, True), c1, c2, sigma=9, outline=3, ocol=OLD, spec=0.3, gdir=(math.cos(r), math.sin(r)))
    wing(ang - 18, 0.9, True)
    # corps
    paint(cv, M_ell(cv, 150, 126 + bob, 64, 52, -8), "#5aa0f5", "#2a63c0", sigma=18, k=1.1, outline=3.4, ocol=OLD, spec=0.35)
    flat(cv, AND(M_ell(cv, 168, 152 + bob, 46, 28), M_ell(cv, 150, 126 + bob, 62, 50, -8)), "#d8ecff", 0.9, blur=4)
    wing(ang, 1.0, False)
    # pattes
    for x0 in (140, 160):
        flat(cv, M_stroke(cv, [(x0, 172 + bob), (x0 - 4, 196 + bob), (x0 + 8, 200 + bob)], 5), "#f0a030")
    # crête
    for dx, h in ((-12, 36), (4, 44), (20, 34)):
        paint(cv, M_poly(cv, [(190 + dx - 8, 66 + bob), (190 + dx + 4, 66 - h + bob), (190 + dx + 14, 70 + bob)], False), "#ff5a4a", "#c02a2a", sigma=4, outline=2.6, ocol="#5a1410", spec=0.3)
    # tête
    paint(cv, M_ell(cv, 196, 92 + bob, 38, 35), "#6aaaf8", "#2f6fd0", sigma=11, k=1.1, outline=3.2, ocol=OLD, spec=0.4)
    # bec
    paint(cv, M_poly(cv, [(224, 82 + bob), (268, 100 + bob), (224, 110 + bob)], True), "#ffc040", "#e08a10", sigma=5, outline=2.8, ocol="#5a3408", spec=0.5)
    flat(cv, M_stroke(cv, [(226, 98 + bob), (258, 101 + bob)], 3), "#7a4408", 0.8)
    # œil
    paint(cv, M_ell(cv, 206, 86 + bob, 10, 11), "#ffffff", "#f0f0f5", sigma=4, outline=2.2, ocol=OLD, spec=0, ambient=0.8)
    flat(cv, M_ell(cv, 209, 88 + bob, 6, 7), "#10141e")
    flat(cv, M_ell(cv, 207, 85 + bob, 2.2, 2.2), "#ffffff")
    flat(cv, M_stroke(cv, [(188, 72 + bob), (218, 82 + bob)], 6, False), "#14305a")
    return cv.image(0.5)


def make_enemies():
    if want("dog.png"):
        fr = [dog("walk", k * math.pi / 2) for k in range(4)] + [dog("lunge", 0)]
        save(sheet(fr, 5), "dog.png")
    if want("fox.png"):
        fr = [fox("walk", k * math.pi / 2) for k in range(4)] + [fox("lunge", 0)]
        save(sheet(fr, 5), "fox.png")
    if want("bird.png"):
        save(sheet([bird(k) for k in range(4)], 4), "bird.png")



# ============================================================== DÉCORS ===
def ridge(W, base, comps):
    xs = np.arange(W + 1, dtype=np.float32)
    y = np.full(W + 1, base, np.float32)
    for a, f, ph in comps:
        y += a * np.sin(2 * np.pi * f * xs / W + ph)
    return y


def make_sky():
    W, H = 1024, 576
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top, mid, hor = rgb("#4a96eb"), rgb("#8cc8fa"), rgb("#ffeccf")
    g = np.where(t < 0.55, top + (mid - top) * (t / 0.55), mid + (hor - mid) * ((t - 0.55) / 0.45))
    img = np.ones((H, W, 3), np.float32) * g
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d2 = (xx - 800) ** 2 + (yy - 150) ** 2
    img += rgb("#fff2b8") * (np.exp(-d2 / (2 * 130 ** 2)) * 0.75)[..., None]
    img += rgb("#ffffff") * (np.exp(-d2 / (2 * 46 ** 2)) * 0.9)[..., None]
    sun = (np.clip((40 - np.sqrt(d2)) / 3, 0, 1))[..., None]
    img = img * (1 - sun) + rgb("#fffbe6") * sun
    base = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")
    cl = Cv(W, H, 2)
    for cx, cy, sc in ((150, 120, 1.0), (430, 80, 0.8), (640, 190, 1.2), (930, 70, 0.7), (300, 230, 0.9), (60, 250, 0.6)):
        parts = [(0, 0, 90, 32), (-52, 8, 56, 25), (56, 9, 60, 26), (0, -20, 54, 33), (-30, -10, 40, 26), (36, -16, 44, 29)]
        ms = [M_ell(cl, cx + px * sc, cy + py * sc, rx * sc, ry * sc) for px, py, rx, ry in parts]
        paint(cl, U(*ms), "#ffffff", "#cfe0f6", sigma=15 * sc, k=0.9, outline=0, spec=0, ambient=0.7, tint=(0.88, 0.92, 1.0))
    base.alpha_composite(cl.image())
    save(base.convert("RGB"), "bg_sky.png")


def tree_silhouette(cv, x, y, sc, c1, c2, oc):
    paint(cv, M_poly(cv, [(x - 4 * sc, y), (x - 3 * sc, y - 34 * sc), (x + 3 * sc, y - 34 * sc), (x + 4 * sc, y)]),
          "#7a5636", "#4a3220", sigma=3, outline=0, spec=0)
    for dx, dy, rx, ry in ((0, -52, 26, 24), (-18, -42, 18, 17), (18, -42, 19, 18), (0, -34, 30, 14)):
        paint(cv, M_ell(cv, x + dx * sc, y + dy * sc, rx * sc, ry * sc), c1, c2, sigma=8 * sc, outline=0, spec=0.1, ambient=0.55)


def make_hills():
    W, H = 1024, 320
    cv = Cv(W, H, 2)
    r = ridge(W, 170, [(34, 2, 0.4), (18, 5, 1.3), (8, 11, 2.2)])
    pts = [(x, r[x]) for x in range(0, W + 1, 4)] + [(W, H), (0, H)]
    paint(cv, M_poly(cv, pts), "#b7d7d0", "#8fb8b4", sigma=40, k=0.5, outline=0, spec=0, ambient=0.78)
    save(cv.image(), "bg_far.png")

    cv = Cv(W, H, 2)
    r = ridge(W, 200, [(30, 3, 1.0), (14, 7, 0.2), (7, 13, 2.8)])
    pts = [(x, r[x]) for x in range(0, W + 1, 4)] + [(W, H), (0, H)]
    paint(cv, M_poly(cv, pts), "#79c46a", "#3f9a4a", sigma=40, k=0.6, outline=0, spec=0, ambient=0.75)
    random.seed(7)
    for x in range(30, W, 62):
        xx = x + random.randint(-14, 14)
        sc = random.uniform(0.9, 1.5)
        for off in (-W, 0, W):
            tree_silhouette(cv, xx + off, r[int(min(max(xx, 0), W))] + 8, sc, "#58b05c", "#2f7a3c", "#1f5a2c")
    save(cv.image(), "bg_mid.png")


def grass_tile(h, soil_to, bottom=False, cap=None, name="ground_top.png"):
    """Bande d'herbe + terre, raccord horizontal parfait (période 256)."""
    P = 256
    cv = Cv(P * 3, h, 4)
    OLD = "#2a5a22"
    # terre
    top_y = 40
    if bottom:
        bpts = [(0, 0)]
        for x in range(0, P * 3 + 1, 8):
            bpts.append((x, soil_to + 8 * math.sin(2 * math.pi * 3 * x / P) + 5 * math.sin(2 * math.pi * 7 * x / P + 1)))
        pts = [(0, top_y)] + [(P * 3, top_y)] + [(P * 3, soil_to)] + [(x, y) for x, y in reversed(bpts[1:])] + [(0, soil_to)]
    else:
        pts = [(0, top_y), (P * 3, top_y), (P * 3, h), (0, h)]
    soil = M_poly(cv, pts)
    paint(cv, soil, "#8a5a36", "#5c3820", sigma=20, k=0.45, outline=0, spec=0, ambient=0.8, gdir=(0, 1))
    rnd = random.Random(5)
    for k in range(22):
        x = rnd.uniform(0, P)
        y = rnd.uniform(top_y + 22, (soil_to if bottom else h) - 14)
        rx, ry = rnd.uniform(5, 11), rnd.uniform(4, 8)
        for off in (0, P, 2 * P):
            m = AND(M_ell(cv, x + off, y, rx, ry, rnd.uniform(-30, 30)), soil)
            paint(cv, m, "#c4a27a", "#8f6e4a", sigma=3, outline=1.6, ocol="#4a2e18", spec=0.3, ambient=0.7)
    # herbe : bord inférieur festonné + dessus
    bump = []
    for x in range(0, P * 3 + 1, 4):
        bump.append((x, top_y + 12 + 10 * (0.5 + 0.5 * math.sin(2 * math.pi * 4 * x / P)) + 4 * math.sin(2 * math.pi * 9 * x / P)))
    tops = [(x, 18 + 3 * math.sin(2 * math.pi * 3 * x / P) + 2 * math.sin(2 * math.pi * 8 * x / P)) for x in range(0, P * 3 + 1, 4)]
    gm = M_poly(cv, tops + list(reversed(bump)))
    paint(cv, gm, "#93e052", "#3f9a2f", sigma=9, k=0.9, outline=3.0, ocol=OLD, spec=0.35, gdir=(0, 1))
    # brins d'herbe qui dépassent
    for k in range(34):
        x = (k * P / 34) + rnd.uniform(-3, 3)
        hh = rnd.uniform(10, 18)
        lean = rnd.uniform(-4, 4)
        for off in (0, P, 2 * P):
            xx = x + off
            yb = 18 + 3 * math.sin(2 * math.pi * 3 * xx / P) + 6
            blade = M_poly(cv, [(xx - 3.2, yb), (xx + lean, yb - hh), (xx + 3.2, yb)])
            paint(cv, blade, "#a8ee60", "#4aa832", sigma=2, outline=1.8, ocol=OLD, spec=0.2, ambient=0.75)
    img = cv.image().crop((P, 0, 2 * P, h))
    if cap:
        rr = Image.new("L", img.size, 0)
        ImageDraw.Draw(rr).rounded_rectangle([-40 if cap == "l" else 0, 0, img.size[0] + (40 if cap == "l" else 0) if cap == "l" else img.size[0] + 40, h],
                                             radius=30, fill=255)
    return img


def make_ground():
    if want("ground_top.png"):
        save(grass_tile(128, 128, False), "ground_top.png")
    if want("plat_m.png"):
        save(grass_tile(96, 78, True), "plat_m.png")
    if want("soil.png"):
        P = 256
        cv = Cv(P * 3, P * 3, 2)
        soil = M_poly(cv, [(0, 0), (P * 3, 0), (P * 3, P * 3), (0, P * 3)])
        paint(cv, soil, "#6a4228", "#563320", sigma=60, k=0.2, outline=0, spec=0, ambient=0.9)
        rnd = random.Random(11)
        for k in range(20):
            x, y = rnd.uniform(0, P), rnd.uniform(0, P)
            rx, ry = rnd.uniform(5, 11), rnd.uniform(4, 8)
            for ox in (0, P, 2 * P):
                for oy in (0, P, 2 * P):
                    paint(cv, M_ell(cv, x + ox, y + oy, rx, ry, rnd.uniform(-40, 40)), "#b89674", "#7e5e40", sigma=4,
                          outline=1.8, ocol="#3a2414", spec=0.3, ambient=0.7)
        save(cv.image().crop((P, P, 2 * P, 2 * P)), "soil.png")


def make_decor():
    if want("tree.png"):
        cv = Cv(300, 420)
        trunk = M_poly(cv, [(112, 412), (130, 380), (136, 250), (128, 200), (172, 200), (166, 250), (172, 380), (190, 412)], True)
        paint(cv, trunk, "#a87444", "#6a4226", sigma=9, k=0.9, outline=3.6, ocol="#2e1c10", spec=0.15)
        for y in (260, 300, 340):
            flat(cv, M_stroke(cv, [(140, y), (148, y + 14), (142, y + 28)], 3), "#4a2c18", 0.6)
        crowns = [(150, 120, 112, 88), (72, 150, 62, 56), (228, 150, 64, 58), (108, 66, 62, 52), (196, 70, 64, 54), (150, 176, 96, 40)]
        for cx, cy, rx, ry in crowns:
            paint(cv, M_ell(cv, cx, cy, rx, ry), "#84dc58", "#2f8a34", sigma=18, k=1.0, outline=3.4, ocol="#1c4e22", spec=0.35)
        rnd = random.Random(3)
        for k in range(24):
            ax, ay = rnd.uniform(60, 240), rnd.uniform(60, 190)
            flat(cv, M_ell(cv, ax, ay, rnd.uniform(8, 16), rnd.uniform(5, 9), rnd.uniform(-40, 40)), "#b4f27c", 0.45, blur=1)
        for ax, ay in ((96, 120), (170, 90), (214, 150), (130, 170), (60, 160), (190, 190)):
            paint(cv, M_ell(cv, ax, ay, 11, 11), "#ff6a5a", "#c01e2a", sigma=4, outline=2.2, ocol="#5a0e14", spec=0.8, ambient=0.7)
            flat(cv, M_stroke(cv, [(ax, ay - 10), (ax + 2, ay - 16)], 2.4), "#3a2410")
        save(cv.image(0.8), "tree.png")
    if want("bush.png"):
        cv = Cv(240, 140)
        for cx, cy, rx, ry in ((62, 92, 54, 42), (178, 92, 56, 42), (120, 72, 66, 56), (120, 104, 100, 30)):
            paint(cv, M_ell(cv, cx, cy, rx, ry), "#6fd058", "#2a7a30", sigma=14, outline=3.2, ocol="#1c4e22", spec=0.35)
        rnd = random.Random(9)
        for k in range(14):
            flat(cv, M_ell(cv, rnd.uniform(30, 210), rnd.uniform(40, 100), rnd.uniform(6, 12), rnd.uniform(4, 7), rnd.uniform(-40, 40)), "#a6ee78", 0.4, blur=1)
        for bx_, by_ in ((70, 70), (110, 56), (160, 74), (190, 98), (46, 100)):
            paint(cv, M_ell(cv, bx_, by_, 7, 7), "#ff7a9a", "#d02a5a", sigma=3, outline=1.8, ocol="#5a1030", spec=0.8, ambient=0.7)
        save(cv.image(0.8), "bush.png")
    if want("fence.png"):
        cv = Cv(220, 130)
        for y0 in (46, 80):
            paint(cv, M_poly(cv, [(8, y0), (212, y0), (212, y0 + 18), (8, y0 + 18)]), "#e0a868", "#a86c34", sigma=5, outline=3.2, ocol="#3a2010", spec=0.3)
            for gx in range(20, 210, 34):
                flat(cv, M_stroke(cv, [(gx, y0 + 5), (gx + 14, y0 + 7)], 1.8), "#7a4a24", 0.5)
        for x0 in (22, 104, 186):
            post = M_poly(cv, [(x0 - 14, 124), (x0 - 14, 36), (x0, 14), (x0 + 14, 36), (x0 + 14, 124)])
            paint(cv, post, "#f0b878", "#b47a3c", sigma=7, outline=3.4, ocol="#3a2010", spec=0.35)
            flat(cv, M_stroke(cv, [(x0 - 2, 44), (x0 - 2, 114)], 2), "#7a4a24", 0.45)
        save(cv.image(0.8), "fence.png")
    if want("flowers.png"):
        cv = Cv(160, 110)
        for x, h, c1, c2 in ((24, 56, "#ff7a8a", "#d02a4a"), (52, 74, "#ffe066", "#e0a010"), (84, 62, "#c8a0ff", "#7a4ad0"),
                             (114, 80, "#ff7a8a", "#d02a4a"), (138, 54, "#ffe066", "#e0a010")):
            flat(cv, M_stroke(cv, [(x, 106), (x + 3, 106 - h * 0.5), (x, 106 - h)], 4), "#2f8a34")
            flat(cv, M_ell(cv, x + 9, 106 - h * 0.35, 9, 4, -30), "#4ab04c")
            for a in range(5):
                ang = a * 72 + 10
                px_, py_ = x + 11 * math.cos(math.radians(ang)), 106 - h + 11 * math.sin(math.radians(ang))
                paint(cv, M_ell(cv, px_, py_, 9, 7, ang), c1, c2, sigma=3, outline=1.8, ocol="#4a2030", spec=0.4)
            paint(cv, M_ell(cv, x, 106 - h, 6.5, 6.5), "#fff0a0", "#e0a020", sigma=2.5, outline=1.6, ocol="#6a4410", spec=0.5)
        save(cv.image(0.8), "flowers.png")
    if want("cave.png"):
        cv = Cv(380, 340)
        dome = M_ell(cv, 190, 220, 176, 140)
        base = M_poly(cv, [(14, 336), (14, 250), (366, 250), (366, 336)])
        paint(cv, U(dome, base), "#a4a4b4", "#5e5e72", sigma=24, k=1.0, outline=3.8, ocol="#1c1c28", spec=0.3)
        rnd = random.Random(2)
        for k in range(16):
            cx, cy = rnd.uniform(40, 340), rnd.uniform(110, 300)
            if abs(cx - 190) < 80 and cy > 190:
                continue
            paint(cv, M_ell(cv, cx, cy, rnd.uniform(16, 32), rnd.uniform(12, 22), rnd.uniform(-30, 30)), "#b8b8c8", "#7a7a90", sigma=5,
                  outline=2.4, ocol="#1c1c28", spec=0.35, ambient=0.7)
        for cx, cy, rx, ry in ((120, 96, 56, 22), (200, 84, 70, 24), (270, 106, 54, 22), (60, 150, 36, 16), (330, 150, 34, 16)):
            paint(cv, M_ell(cv, cx, cy, rx, ry), "#7ed05a", "#3a8a36", sigma=6, outline=2.8, ocol="#1c4e22", spec=0.35)
        door = M_poly(cv, [(112, 340), (112, 250), (130, 196), (190, 172), (250, 196), (268, 250), (268, 340)], True)
        paint(cv, door, "#2a2036", "#08060e", sigma=22, k=0.6, outline=4.0, ocol="#12101a", spec=0, ambient=0.6)
        flat(cv, AND(M_ell(cv, 190, 300, 70, 56), door), "#ffcf70", 0.35, blur=14)
        save(cv.image(0.8), "cave.png")


def make_items():
    if want("coin.png"):
        cv = Cv(96, 96)
        paint(cv, M_ell(cv, 48, 48, 38, 38), "#ffe27a", "#e09a14", sigma=9, outline=3.6, ocol="#6a4410", spec=0.6, gdir=(0.4, 1))
        paint(cv, M_ell(cv, 48, 48, 27, 27), "#ffd04a", "#f0a818", sigma=6, outline=2.0, ocol="#a06a10", spec=0.3, gdir=(-0.4, -1))
        star = []
        for i in range(10):
            r_ = 17 if i % 2 == 0 else 7.5
            a = -math.pi / 2 + i * math.pi / 5
            star.append((48 + r_ * math.cos(a), 49 + r_ * math.sin(a)))
        paint(cv, M_poly(cv, star), "#fff0a0", "#ffc030", sigma=3, outline=1.6, ocol="#a06a10", spec=0.5)
        save(cv.image(), "coin.png")
    if want("carrot.png"):
        cv = Cv(96, 96)
        for dx, a in ((-12, -26), (0, 0), (12, 26)):
            paint(cv, M_ell(cv, 48 + dx + a * 0.15, 20, 7, 17, a), "#8be25a", "#2f9a34", sigma=4, outline=2.4, ocol="#1c4e22", spec=0.3)
        body = M_poly(cv, [(30, 30), (66, 30), (56, 60), (48, 90), (40, 60)], True)
        paint(cv, body, "#ffa23a", "#e0600c", sigma=8, outline=3.2, ocol="#6a2a08", spec=0.45)
        for y in (42, 54, 66):
            flat(cv, M_stroke(cv, [(40 + (y - 42) * 0.12, y), (54 - (y - 42) * 0.12, y + 2)], 2.4), "#a8420a", 0.7)
        save(cv.image(), "carrot.png")
    if want("tomato.png"):
        cv = Cv(96, 96)
        paint(cv, M_ell(cv, 48, 54, 36, 32), "#ff6a5a", "#c01e24", sigma=11, outline=3.4, ocol="#5a0e14", spec=0.8)
        for a in range(5):
            ang = -90 + (a - 2) * 40
            paint(cv, M_ell(cv, 48 + 13 * math.cos(math.radians(ang)), 28 + 8 * math.sin(math.radians(ang)) + 4, 12, 5, ang), "#7ed05a", "#2a8a30", sigma=2.5, outline=2, ocol="#1c4e22", spec=0.3)
        flat(cv, M_stroke(cv, [(48, 26), (50, 16)], 4), "#3a6a22")
        save(cv.image(), "tomato.png")
    if want("lettuce.png"):
        cv = Cv(96, 96)
        for cx, cy, rx, ry, c1, c2 in ((48, 58, 40, 30, "#6cc050", "#2a7a30"), (34, 52, 26, 26, "#8ae062", "#3a9a3a"),
                                      (62, 52, 26, 26, "#8ae062", "#3a9a3a"), (48, 46, 24, 26, "#b4f27c", "#58b448")):
            paint(cv, M_ell(cv, cx, cy, rx, ry), c1, c2, sigma=8, outline=3, ocol="#1c4e22", spec=0.35)
        for dx in (-12, 0, 12):
            flat(cv, M_stroke(cv, [(48 + dx, 66), (48 + dx * 0.6, 48), (48 + dx * 0.9, 34)], 2.4), "#e8ffc8", 0.6)
        save(cv.image(), "lettuce.png")
    cols = {"n": ("#ffa83a", "#e0600c", "#6a2a08"), "f": ("#ff8a3a", "#d02a0a", "#6a1408"),
            "i": ("#c8f0ff", "#5aa8e8", "#1c4468"), "e": ("#fff49a", "#f0b020", "#6a4a08")}
    for key, (c1, c2, oc) in cols.items():
        name = "carrot_%s.png" % key
        if not want(name):
            continue
        cv = Cv(128, 48)
        for dy, a in ((-8, -22), (0, 0), (8, 22)):
            paint(cv, M_ell(cv, 22, 24 + dy, 18, 6, a * 0.5), "#8be25a", "#2f9a34", sigma=3, outline=2.2, ocol="#1c4e22", spec=0.3)
        body = M_poly(cv, [(28, 8), (28, 40), (118, 25)], True)
        paint(cv, body, c1, c2, sigma=7, outline=3.0, ocol=oc, spec=0.55, gdir=(0, 1))
        for x in (50, 70, 88):
            flat(cv, M_stroke(cv, [(x, 16 + (x - 50) * 0.12), (x + 2, 32 - (x - 50) * 0.12)], 2.2), oc, 0.55)
        save(cv.image(), name)
    if want("glow.png"):
        N = 128
        yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
        d = np.sqrt((xx - N / 2) ** 2 + (yy - N / 2) ** 2) / (N / 2)
        a = np.clip(1 - d, 0, 1) ** 2.2
        out = np.zeros((N, N, 4), np.uint8)
        out[..., :3] = 255
        out[..., 3] = (a * 255).astype(np.uint8)
        save(Image.fromarray(out, "RGBA"), "glow.png")


if __name__ == "__main__":
    if want("rabbit1.png") or want("rabbit2.png") or want("rabbit3.png"):
        make_rabbits()
    make_enemies()
    if want("bg_sky.png"):
        make_sky()
    if want("bg_far.png") or want("bg_mid.png"):
        make_hills()
    make_ground()
    make_decor()
    make_items()
