#!/usr/bin/env python3
"""Prepare food product photos for a catalog.

This script removes the background from downloaded food images, crops the food
item, and places it on a plate in a 350x350 output.

Usage:
    python3 process_food_images.py --input downloaded_images --output plated_images
"""

from __future__ import annotations

import argparse
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

try:
    from rembg import remove
except ImportError:  # pragma: no cover - handled at runtime
    remove = None

TARGET_SIZE = 350
MAX_FOOD_SIZE = 260
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif"}


def list_images(folder: Path) -> list[Path]:
    if not folder.exists():
        raise FileNotFoundError(f"Folder ne postoji: {folder}")

    files = [
        path for path in folder.rglob("*")
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    ]
    return sorted(files)


def remove_background_from_image(image_path: Path) -> Image.Image:
    if remove is None:
        raise RuntimeError(
            "'rembg' nije instaliran. Pokreni: pip install -r requirements.txt"
        )

    with image_path.open("rb") as source:
        input_bytes = source.read()

    output_bytes = remove(input_bytes)
    if not output_bytes:
        raise RuntimeError(f"Nisam uspio ukloniti pozadinu za sliku: {image_path}")

    image = Image.open(BytesIO(output_bytes)).convert("RGBA")
    return image


def repair_food_mask(image: Image.Image) -> Image.Image:
    """Fill small holes and smooth out the food mask so partially cut items look complete."""
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").convert("L")

    if alpha.getbbox() is None:
        return rgba

    # Morphological closing: dilate to fill tiny gaps and then erode slightly to keep shape.
    dilated = alpha.filter(ImageFilter.MaxFilter(7))
    closed = dilated.filter(ImageFilter.MinFilter(5))

    # Slightly smooth the alpha mask so the food contour looks natural.
    smooth = closed.filter(ImageFilter.GaussianBlur(1.0))
    repaired = smooth.point(lambda value: 255 if value > 20 else 0)
    rgba.putalpha(repaired)
    return rgba


def crop_to_food(image: Image.Image, padding: int = 8) -> Image.Image:
    repaired = repair_food_mask(image)
    alpha = repaired.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return repaired

    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(repaired.width - 1, right + padding)
    bottom = min(repaired.height - 1, bottom + padding)
    return repaired.crop((left, top, right + 1, bottom + 1)).copy()


def resize_to_fit(image: Image.Image, max_size: int) -> Image.Image:
    width, height = image.size
    if width <= 0 or height <= 0:
        return image

    scale = min(max_size / width, max_size / height, 1.0)
    if scale >= 1.0:
        return image

    new_size = (max(1, int(width * scale)), max(1, int(height * scale)))
    return image.resize(new_size, Image.Resampling.LANCZOS)


def create_plate(food_image: Image.Image, size: int = TARGET_SIZE) -> Image.Image:
    plate = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse((40, 70, size - 40, size - 30), fill=(0, 0, 0, 90))
    plate = Image.alpha_composite(plate, shadow)

    plate_base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    plate_draw = ImageDraw.Draw(plate_base)
    plate_draw.ellipse((0, 0, size, size), fill=(247, 242, 236, 255))
    plate_draw.ellipse((30, 30, size - 30, size - 30), fill=(255, 255, 255, 30))
    plate = Image.alpha_composite(plate, plate_base)

    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rim_draw = ImageDraw.Draw(rim)
    rim_draw.ellipse((8, 8, size - 8, size - 8), outline=(198, 183, 167, 255), width=12)
    plate = Image.alpha_composite(plate, rim)

    food = resize_to_fit(food_image, MAX_FOOD_SIZE)
    x = (size - food.width) // 2
    y = max(18, (size - food.height) // 2 - 8)
    plate.paste(food, (x, y), food)
    return plate


def save_png(image: Image.Image, target_path: Path) -> Path:
    target_path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGBA").save(target_path, format="PNG")
    return target_path


def process_image(input_path: Path, output_dir: Path) -> Path:
    cleaned = remove_background_from_image(input_path)
    food = crop_to_food(cleaned)
    plated = create_plate(food)

    output_dir.mkdir(parents=True, exist_ok=True)
    output_name = f"{input_path.stem}_plated.png"
    final_path = output_dir / output_name
    index = 2
    while final_path.exists():
        final_path = output_dir / f"{input_path.stem}_plated_{index}.png"
        index += 1

    plated.save(final_path)
    return final_path


def process_image_with_folders(input_path: Path, clean_dir: Path, plated_dir: Path) -> tuple[Path, Path]:
    cleaned = remove_background_from_image(input_path)
    food = crop_to_food(cleaned)

    clean_path = clean_dir / f"{input_path.stem}_clean.png"
    index = 2
    while clean_path.exists():
        clean_path = clean_dir / f"{input_path.stem}_clean_{index}.png"
        index += 1
    save_png(food, clean_path)

    plated = create_plate(food)
    plated_path = plated_dir / f"{input_path.stem}_plated.png"
    index = 2
    while plated_path.exists():
        plated_path = plated_dir / f"{input_path.stem}_plated_{index}.png"
        index += 1
    save_png(plated, plated_path)

    return clean_path, plated_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Uklanja pozadinu sa slike hrane i stavlja je na tanjir 350x350."
    )
    parser.add_argument(
        "--input",
        type=Path,
        required=True,
        help="Putanja do foldera sa slikama (npr. downloaded_images)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("plated_images"),
        help="Gde da se snime finalne slike",
    )
    args = parser.parse_args()

    try:
        images = list_images(args.input)
        if not images:
            print(f"Nije pronađena nijedna slika u folderu: {args.input}")
            return 1

        print(f"Pronađeno {len(images)} slika. Obrada u toku...")
        for image_path in images:
            try:
                output_path = process_image(image_path, args.output)
                print(f"OK: {image_path.name} -> {output_path}")
            except Exception as exc:  # pragma: no cover - debug output
                print(f"GREŠKA: {image_path.name}: {exc}")

        print(f"\nGotovo. Finalne slike su u: {args.output.resolve()}")
        return 0
    except Exception as exc:
        print(f"Greška: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
