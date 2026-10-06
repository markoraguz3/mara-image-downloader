import asyncio
import argparse
import mimetypes
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

from playwright.async_api import Error as PlaywrightError
from playwright.async_api import async_playwright


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


OUTPUT_ROOT = Path(os.environ.get("MARA_DATA_DIR", ".")) / "downloaded_images"
MAX_SCROLLS = 100


def show_progress(label: str, current: int, total: int) -> None:
    percent = int(current / total * 100) if total else 100
    width = 30
    filled = int(width * percent / 100)
    bar = "#" * filled + "-" * (width - filled)
    sys.stdout.write(f"\r{label} [{bar}] {percent:3d}% ({current}/{total})")
    sys.stdout.flush()
    if current >= total:
        sys.stdout.write("\n")


def safe_name(value: str) -> str:
    value = unquote(value).strip()
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", value)
    value = re.sub(r"\s+", " ", value).strip(" .")
    return value[:120] or "image"


def output_folder_for(url: str, page_title: str) -> Path:
    parsed = urlparse(url)
    page_name = safe_name(page_title or parsed.hostname or "web stranica")
    folder = OUTPUT_ROOT / page_name
    folder.mkdir(parents=True, exist_ok=True)
    return folder


async def load_lazy_images(page) -> None:
    stable_bottom_steps = 0
    previous_height = 0

    print("Ucitavam slike sa stranice. Skeniranje moze potrajati...")
    for _ in range(MAX_SCROLLS):
        await page.evaluate(
            """() => {
                window.scrollBy(0, Math.max(400, window.innerHeight * 0.8));
            }"""
        )
        await page.wait_for_timeout(700)
        updated = await page.evaluate(
            """() => ({
                height: document.documentElement.scrollHeight,
                bottom: window.scrollY + window.innerHeight,
                viewport: window.innerHeight
            })"""
        )

        at_bottom = updated["bottom"] >= updated["height"] - updated["viewport"] * 0.1
        if at_bottom and updated["height"] == previous_height:
            stable_bottom_steps += 1
        else:
            stable_bottom_steps = 0

        previous_height = updated["height"]
        if _ % 5 == 0 or stable_bottom_steps:
            print(f"Skeniranje stranice... korak {_ + 1} (maksimalno {MAX_SCROLLS})")
        if stable_bottom_steps >= 3:
            break

    await page.wait_for_timeout(1000)
    print("Skeniranje stranice zavrseno.")


async def collect_images(page) -> list[dict[str, str]]:
    return await page.locator("img").evaluate_all(
        """images => {
            const found = new Map();
            const pricePattern = /(?:\\d[\\d.,\\s]*\\s?(?:zł|pln|eur|usd|gbp|czk|sek|nok|dkk|lei|mdl|€|\\$|£)|(?:€|\\$|£)\\s?\\d)/i;

            for (const image of images) {
                const url = image.currentSrc || image.src ||
                    image.dataset.src || image.dataset.original;
                if (!url || !/^https?:/i.test(url)) continue;
                if (image.naturalWidth < 2 || image.naturalHeight < 2) continue;

                // Menu products are rendered as priced list/article cards. This
                // excludes restaurant branding, badges, and general page artwork.
                let menuItem = image.parentElement;
                for (let depth = 0; menuItem && depth < 10; depth++, menuItem = menuItem.parentElement) {
                    const isMenuCard = menuItem.tagName === "LI" ||
                        menuItem.tagName === "ARTICLE" ||
                        menuItem.getAttribute("role") === "listitem" ||
                        menuItem.getAttribute("role") === "article";
                    if (isMenuCard) break;
                }
                const menuText = menuItem?.innerText || "";
                if (!menuItem || menuText.length > 1200 || !pricePattern.test(menuText)) continue;

                if (!found.has(url)) {
                    let name = image.alt || image.getAttribute("title") ||
                        image.getAttribute("aria-label") || "";
                    name = name.replace(/\\s+-\\s+["“].*$/u, "").trim();
                    if (!name) {
                        for (let depth = 0; menuItem && depth < 5 && !name; depth++, menuItem = menuItem.parentElement) {
                            const heading = menuItem.querySelector("h1, h2, h3, h4, h5, [role='heading']");
                            if (heading?.innerText?.trim()) name = heading.innerText.trim();
                        }
                    }
                    if (!name) continue;
                    found.set(url, {
                        url,
                        name
                    });
                }
            }
            return [...found.values()];
        }"""
    )


async def wait_for_page_access(page) -> None:
    challenge_detected = False
    while True:
        if page.is_closed():
            raise PlaywrightError("Browser je zatvoren prije završetka učitavanja stranice.")

        page_state = await page.evaluate(
            """() => ({
                title: document.title || "",
                text: (document.body?.innerText || "").slice(0, 5000)
            })"""
        )
        content = f"{page_state['title']} {page_state['text']}".casefold()
        blocked = any(
            phrase in content
            for phrase in (
                "one more step",
                "automated security check",
                "please verify you are human",
                "recaptcha",
                "i'm not a robot",
            )
        )

        if not blocked:
            if challenge_detected:
                print("Sigurnosna provjera je zavrsena. Nastavljam automatski.")
            await page.wait_for_timeout(1500)
            return

        if not challenge_detected:
            print(
                "Stranica trazi CAPTCHA/sigurnosnu provjeru. "
                "Rijesite je u otvorenom browseru; program ce nastaviti sam."
            )
            challenge_detected = True
        await page.wait_for_timeout(2000)


def detect_image_extension(body: bytes, content_type: str, url: str) -> str | None:
    if body.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if body.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if body.startswith((b"GIF87a", b"GIF89a")):
        return ".gif"
    if body.startswith(b"BM"):
        return ".bmp"
    if len(body) >= 12 and body[:4] == b"RIFF" and body[8:12] == b"WEBP":
        return ".webp"
    if len(body) >= 12 and body[4:8] == b"ftyp" and body[8:12] in {b"avif", b"avis"}:
        return ".avif"

    normalized_type = content_type.split(";", 1)[0].strip().lower()
    known_types = {
        "image/jpeg": ".jpg",
        "image/jpg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
        "image/gif": ".gif",
        "image/avif": ".avif",
        "image/svg+xml": ".svg",
        "image/bmp": ".bmp",
    }
    if normalized_type in known_types:
        return known_types[normalized_type]

    if normalized_type.startswith("image/"):
        extension = mimetypes.guess_extension(normalized_type)
        if extension and extension != ".jpe":
            return extension

    parsed_path = unquote(urlparse(url).path)
    url_extension = Path(parsed_path).suffix.lower()
    allowed_extensions = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif", ".svg", ".bmp"}
    if url_extension in allowed_extensions:
        return url_extension

    return None


def image_filename(name: str, url: str, content_type: str, body: bytes) -> str | None:
    parsed_path = unquote(urlparse(url).path)
    url_filename = Path(parsed_path).name
    extension = detect_image_extension(body, content_type, url)
    if extension is None:
        return None

    base_name = safe_name(name.strip() or Path(url_filename).stem or "image")
    return f"{base_name}{extension}"


async def download_page_images(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("Unesi ispravan URL koji počinje sa http:// ili https://.")

    async with async_playwright() as playwright:
        print("Pokrecem browser...")
        browser = None
        browser_errors = []
        for browser_name, channel in (
            ("Microsoft Edge", "msedge"),
            ("Google Chrome", "chrome"),
            ("Playwright Chromium", None),
        ):
            launch_options = {"headless": False}
            if channel is not None:
                launch_options["channel"] = channel
            try:
                browser = await playwright.chromium.launch(**launch_options)
                print(f"Koristim browser: {browser_name}")
                break
            except PlaywrightError as error:
                browser_errors.append(f"{browser_name}: {error}")

        if browser is None:
            raise RuntimeError(
                "Nije moguće pokrenuti browser. Instalirajte Microsoft Edge ili Google Chrome. "
                "Playwright Chromium se može koristiti samo ako je već instaliran.\n"
                + "\n".join(browser_errors)
            )

        context = await browser.new_context()
        page = await context.new_page()

        try:
            print("Otvaram stranicu u browseru...")
            await page.goto(url, wait_until="domcontentloaded", timeout=60000)
            await wait_for_page_access(page)

            page_title = (await page.title()).strip()
            output_folder = output_folder_for(url, page_title)
            print(f"Folder odredista: {output_folder.resolve()}")
            await load_lazy_images(page)
            images = await collect_images(page)
            if not images:
                print("Nisu pronađene slike za preuzimanje.")
                return

            print(f"Pronađeno {len(images)} slika. Spremam u: {output_folder.resolve()}")
            print("Preuzimanje je pocelo. Molim sacekajte...")
            used_names: set[str] = set()
            downloaded = 0

            for index, image in enumerate(images, start=1):
                label = image["name"].strip() or "slika"
                print(f"\n[{index}/{len(images)}] Preuzimam: {label[:70]}")
                try:
                    response = await context.request.get(image["url"], timeout=30000)
                    if not response.ok:
                        print(f"Neuspješno preuzimanje (HTTP {response.status}): {image['url']}")
                        show_progress("Ukupan napredak", index, len(images))
                        continue

                    body = await response.body()
                    filename = image_filename(
                        image["name"],
                        image["url"],
                        response.headers.get("content-type", ""),
                        body,
                    )
                    if filename is None:
                        print(
                            "Preskacem odgovor koji nije prepoznat kao slika: "
                            f"{image['url']}"
                        )
                        show_progress("Ukupan napredak", index, len(images))
                        continue
                    stem, extension = Path(filename).stem, Path(filename).suffix
                    candidate = filename
                    number = 2
                    while candidate.casefold() in used_names or (output_folder / candidate).exists():
                        candidate = f"{stem}_{number}{extension}"
                        number += 1

                    (output_folder / candidate).write_bytes(body)
                    used_names.add(candidate.casefold())
                    downloaded += 1
                    print(f"Preuzeto: {candidate}")
                except (PlaywrightError, OSError) as error:
                    print(f"Greška za sliku {image['url']}: {error}")
                show_progress("Ukupan napredak", index, len(images))

            print(f"\nGotovo: preuzeto {downloaded} od {len(images)} slika.")
            print(f"Otvaram folder sa slikama: {output_folder.resolve()}")
            subprocess.Popen(["explorer.exe", str(output_folder.resolve())])
        finally:
            await browser.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Preuzmi slike proizvoda sa stranice.")
    parser.add_argument("url", nargs="?", help="Adresa stranice sa menijem")
    args = parser.parse_args()
    url = (args.url or input("Unesi link stranice: ")).strip()
    try:
        asyncio.run(download_page_images(url))
    except ValueError as error:
        print(f"Greška: {error}")
        return 1
    except RuntimeError as error:
        print(f"Greška: {error}")
        return 1
    except PlaywrightError as error:
        print(f"Playwright greška: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
