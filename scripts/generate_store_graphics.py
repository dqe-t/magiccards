import math
import os
from typing import List, Tuple
from PIL import Image, ImageDraw, ImageFont, ImageFilter


def draw_golden_star(draw: ImageDraw.ImageDraw, cx: float, cy: float, outer_r: float) -> None:
    inner_r: float = outer_r * 0.44
    pts: List[Tuple[float, float]] = []
    for i in range(10):
        angle: float = -math.pi / 2.0 + i * (math.pi / 5.0)
        r: float = outer_r if i % 2 == 0 else inner_r
        pts.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    draw.polygon(pts, fill=(255, 200, 35), outline=(225, 140, 15))


def create_app_icon_512(output_path: str) -> None:
    size: int = 512
    img: Image.Image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw: ImageDraw.ImageDraw = ImageDraw.Draw(img)

    margin: int = 24
    box_rect: Tuple[int, int, int, int] = (margin, margin, size - margin, size - margin)
    corner_r: int = 96

    shadow: Image.Image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw: ImageDraw.ImageDraw = ImageDraw.Draw(shadow)
    shadow_rect: Tuple[int, int, int, int] = (margin + 4, margin + 12, size - margin + 4, size - margin + 12)
    shadow_draw.rounded_rectangle(shadow_rect, radius=corner_r, fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    img.alpha_composite(shadow)

    draw.rounded_rectangle(box_rect, radius=corner_r, fill=(255, 255, 255, 255), outline=(225, 225, 230, 255), width=4)

    icon_src: str = os.path.join("assets", "images", "icons", "app_icon.png")
    if os.path.exists(icon_src):
        src_img: Image.Image = Image.open(icon_src).convert("RGBA")
        inner_sz: int = 400
        src_resized: Image.Image = src_img.resize((inner_sz, inner_sz), Image.Resampling.LANCZOS)
        offset: int = (size - inner_sz) // 2
        img.alpha_composite(src_resized, (offset, offset))

    img.save(output_path, "PNG")
    print(f"Generated 512x512 icon: {output_path}")


def make_card_sprite(symbol: str, font_path: str, border_col: Tuple[int, int, int], angle: float) -> Image.Image:
    cw: int = 116
    ch: int = 156
    pad: int = 24
    canvas: Image.Image = Image.new("RGBA", (cw + pad * 2, ch + pad * 2), (0, 0, 0, 0))

    # Drop shadow
    sh_draw: ImageDraw.ImageDraw = ImageDraw.Draw(canvas)
    sh_draw.rounded_rectangle(
        (pad + 3, pad + 6, pad + cw + 3, pad + ch + 6),
        radius=16,
        fill=(0, 0, 0, 45)
    )
    canvas = canvas.filter(ImageFilter.GaussianBlur(5))

    draw: ImageDraw.ImageDraw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (pad, pad, pad + cw, pad + ch),
        radius=16,
        fill=(255, 255, 255, 255),
        outline=(border_col[0], border_col[1], border_col[2], 255),
        width=4
    )
    card_font: ImageFont.FreeTypeFont = ImageFont.truetype(font_path, 72)
    bbox = card_font.getbbox(symbol)
    tw: int = bbox[2] - bbox[0]
    th: int = bbox[3] - bbox[1]
    tx: int = pad + (cw - tw) // 2 - bbox[0]
    ty: int = pad + (ch - th) // 2 - bbox[1]
    draw.text((tx, ty), symbol, font=card_font, fill=(25, 25, 32, 255))

    return canvas.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)


def create_feature_graphic_1024x500(output_path: str) -> None:
    width: int = 1024
    height: int = 500
    img: Image.Image = Image.new("RGBA", (width, height), (255, 255, 255, 255))
    draw: ImageDraw.ImageDraw = ImageDraw.Draw(img)

    # Soft subtle vertical gradient background
    for y in range(height):
        ratio: float = y / float(height)
        r: int = int(255 - ratio * 5)
        g: int = int(255 - ratio * 4)
        b: int = int(255 - ratio * 2)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    font_path: str = os.path.join("assets", "fonts", "segoeuib.ttf")
    if not os.path.exists(font_path):
        font_path = os.path.join("assets", "fonts", "calibrib.ttf")

    title_font: ImageFont.FreeTypeFont = ImageFont.truetype(font_path, 33)
    badge_font: ImageFont.FreeTypeFont = ImageFont.truetype(font_path, 14)
    bullet_font: ImageFont.FreeTypeFont = ImageFont.truetype(font_path, 16)

    # Top header bar: Two languages side by side
    top_y: int = 34
    fr_box_w: int = 456
    box_h: int = 84
    fr_box_x: int = 40

    # Left Title Box: LES CARTES MAGIQUES (French)
    draw.rounded_rectangle(
        (fr_box_x, top_y, fr_box_x + fr_box_w, top_y + box_h),
        radius=18,
        fill=(248, 250, 254, 255),
        outline=(215, 222, 235, 255),
        width=2
    )
    draw.rounded_rectangle((fr_box_x + 18, top_y + 12, fr_box_x + 92, top_y + 34), radius=7, fill=(228, 236, 255, 255))
    draw.text((fr_box_x + 26, top_y + 14), "FRANÇAIS", font=badge_font, fill=(35, 80, 210, 255))

    fr_text: str = "LES CARTES MAGIQUES"
    rainbow_fr = [
        (230, 50, 50), (245, 125, 30), (225, 175, 20),
        (45, 175, 75), (40, 135, 225), (130, 65, 210), (210, 50, 150)
    ]
    cur_x: float = float(fr_box_x + 18)
    for i, ch in enumerate(fr_text):
        col = rainbow_fr[i % len(rainbow_fr)]
        draw.text((cur_x, top_y + 38), ch, font=title_font, fill=col)
        bbox = title_font.getbbox(ch)
        cur_x += (bbox[2] - bbox[0]) if ch != " " else 10.0

    # Right Title Box: MAGIC CARDS (English) - Next to French
    en_box_w: int = 456
    en_box_x: int = fr_box_x + fr_box_w + 32
    draw.rounded_rectangle(
        (en_box_x, top_y, en_box_x + en_box_w, top_y + box_h),
        radius=18,
        fill=(248, 250, 254, 255),
        outline=(215, 222, 235, 255),
        width=2
    )
    draw.rounded_rectangle((en_box_x + 18, top_y + 12, en_box_x + 86, top_y + 34), radius=7, fill=(255, 234, 234, 255))
    draw.text((en_box_x + 26, top_y + 14), "ENGLISH", font=badge_font, fill=(205, 45, 45, 255))

    en_text: str = "MAGIC CARDS"
    rainbow_en = [
        (40, 135, 225), (45, 175, 75), (225, 175, 20),
        (245, 125, 30), (230, 50, 50), (130, 65, 210), (210, 50, 150)
    ]
    cur_x = float(en_box_x + 18)
    for i, ch in enumerate(en_text):
        col = rainbow_en[i % len(rainbow_en)]
        draw.text((cur_x, top_y + 38), ch, font=title_font, fill=col)
        bbox = title_font.getbbox(ch)
        cur_x += (bbox[2] - bbox[0]) if ch != " " else 10.0

    # Bottom Section: Left = French features, Middle = English features, Right = Cards + Lion
    mid_y: int = top_y + box_h + 36
    fr_bullets = [
        "Lettres (noms & sons phonétiques)",
        "Chiffres de 1 à 20",
        "Récompenses vidéo d'animaux",
        "6 profils & 100% sans publicité"
    ]
    en_bullets = [
        "Letters (names & phonics sounds)",
        "Numbers from 1 to 20",
        "Real animal video celebrations",
        "6 profiles & 100% kid-safe / ad-free"
    ]

    for idx, fb in enumerate(fr_bullets):
        by: int = mid_y + idx * 36
        draw_golden_star(draw, float(fr_box_x + 14), float(by + 11), 9.5)
        draw.text((fr_box_x + 32, by), fb, font=bullet_font, fill=(45, 50, 65, 255))

    en_col_x: int = 376
    for idx, eb in enumerate(en_bullets):
        by = mid_y + idx * 36
        draw_golden_star(draw, float(en_col_x + 14), float(by + 11), 9.5)
        draw.text((en_col_x + 32, by), eb, font=bullet_font, fill=(45, 50, 65, 255))

    # Bottom decorative cards on left-center below bullets
    card_a: Image.Image = make_card_sprite("A", font_path, (245, 165, 35), 11.0)
    card_7: Image.Image = make_card_sprite("7", font_path, (55, 150, 235), -9.0)
    img.alpha_composite(card_a, (160, 290))
    img.alpha_composite(card_7, (285, 295))

    # Cute Lion illustration on the right side (x = 680..985)
    lion_path: str = os.path.join("assets", "images", "animals", "score_9_lion.png")
    if os.path.exists(lion_path):
        lion_raw: Image.Image = Image.open(lion_path).convert("RGBA")
        # Smoothly make white background transparent so it composites cleanly
        pixels = lion_raw.load()
        lw, lh = lion_raw.size
        for py in range(lh):
            for px in range(lw):
                r_v, g_v, b_v, a_v = pixels[px, py]
                lum: float = 0.299 * r_v + 0.587 * g_v + 0.114 * b_v
                if lum >= 245.0:
                    pixels[px, py] = (255, 255, 255, 0)
                elif lum >= 230.0:
                    alpha_scale: float = (245.0 - lum) / 15.0
                    pixels[px, py] = (r_v, g_v, b_v, int(a_v * alpha_scale))

        target_h: int = 320
        aspect: float = float(lw) / float(lh)
        target_w: int = int(round(target_h * aspect))
        lion_resized: Image.Image = lion_raw.resize((target_w, target_h), Image.Resampling.LANCZOS)
        lion_x: int = width - target_w - 42
        lion_y: int = height - target_h - 18
        img.alpha_composite(lion_resized, (lion_x, lion_y))

        # Sparkle stars arc above the lion
        arc_stars = [
            (lion_x + 30, lion_y + 18, 12.0),
            (lion_x + target_w // 2, lion_y - 6, 15.0),
            (lion_x + target_w - 30, lion_y + 18, 12.0),
        ]
        for sx, sy, sr in arc_stars:
            draw_golden_star(draw, float(sx), float(sy), sr)

    # Subtle outer frame
    draw.rectangle([(0, 0), (width - 1, height - 1)], outline=(220, 220, 228, 255), width=1)

    rgb_out: Image.Image = img.convert("RGB")
    rgb_out.save(output_path, "PNG")
    print(f"Generated 1024x500 feature graphic: {output_path}")


def main() -> None:
    out_dir: str = "play_store_assets"
    os.makedirs(out_dir, exist_ok=True)
    create_app_icon_512(os.path.join(out_dir, "icon_512x512.png"))
    create_feature_graphic_1024x500(os.path.join(out_dir, "feature_graphic_1024x500.png"))


if __name__ == "__main__":
    main()
