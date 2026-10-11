"""Export the local design board. Requires the installed Playwright Python package.

Run from the repository root: python docs/design/render_review.py
Uses an installed Chromium browser in headless mode; downloads nothing.
"""

from pathlib import Path
from playwright.sync_api import sync_playwright


def main():
    directory = Path(__file__).resolve().parent
    browser_candidates = [
        Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
        Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
    ]
    executable = next((p for p in browser_candidates if p.is_file()), None)
    with sync_playwright() as playwright:
        options = {"headless": True}
        if executable:
            options["executable_path"] = str(executable)
        browser = playwright.chromium.launch(**options)
        page = browser.new_page(viewport={"width": 1680, "height": 1250}, device_scale_factor=1)
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto((directory / "review.html").as_uri())
        page.evaluate("document.fonts.ready")
        page.screenshot(path=str(directory / "review.png"), full_page=True)
        print("Fonts:", page.evaluate("Array.from(document.fonts).map(f => [f.family, f.status])"))
        print("Desktop screen content overflow:", page.locator(".content").evaluate_all(
            "els => els.map(el => ({overflow: el.scrollHeight > el.clientHeight, height: el.clientHeight, scroll: el.scrollHeight}))"
        ))
        page.select_option("#surface", "dark")
        page.screenshot(path=str(directory / "review-dark.png"), full_page=True)
        page.select_option("#type", "serif")
        page.evaluate("document.fonts.ready")
        print("Review controls:", page.locator("body").get_attribute("class"))
        page.set_viewport_size({"width": 390, "height": 844})
        print("Mobile horizontal overflow:", page.evaluate(
            "document.documentElement.scrollWidth > innerWidth"
        ))
        print("JavaScript errors:", errors)
        browser.close()


if __name__ == "__main__":
    main()
