"""Render the design study and exercise its disclosure/selection interactions.

Uses installed Playwright and Chrome; no downloads, network, or app state.
Run: python docs/design/camp-study/render.py
"""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

directory = Path(__file__).resolve().parent
with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe", headless=True
    )
    page = browser.new_page(viewport={"width": 1300, "height": 1200}, device_scale_factor=1)
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto((directory / "board.html").as_uri())
    page.evaluate("document.fonts.ready")
    for frame in page.frames[1:]:
        frame.evaluate("document.fonts.ready")
        frame.locator(".screen").wait_for()
        if frame.locator(".art img").count():
            frame.locator(".art img").evaluate("img => img.decode()")
        print("Initial layout:", frame.evaluate("({view: new URLSearchParams(location.search).get('view'), horizontalOverflow: document.documentElement.scrollWidth>innerWidth, contentScroll: document.querySelector('.scroll').scrollHeight>document.querySelector('.scroll').clientHeight})"))
    page.screenshot(path=str(directory / "overview.png"), full_page=True)

    page.goto((directory / "index.html").as_uri())
    page.evaluate("document.fonts.ready")
    page.locator('.art img').evaluate('img => img.decode()')
    expect(page.locator('details[open]')).to_have_count(0)
    page.locator('[data-group=party] summary').click()
    expect(page.locator('[data-group=party]')).to_have_attribute('open', '')
    page.locator('[data-group=stores] summary').click()
    expect(page.locator('[data-group=party]')).not_to_have_attribute('open', '')
    expect(page.locator('details[open]')).to_have_count(1)
    page.locator('.phone [data-view=dispatch]').click()
    expect(page.locator('[data-group=time]')).to_have_attribute('open', '')
    page.locator('#intent').fill('Finish the methods section')
    page.locator('[data-minutes="15"]').click()
    expect(page.locator('#dispatch')).to_be_disabled()
    expect(page.locator('.warning')).to_contain_text('at least 40 minutes')
    page.locator('[data-step=destination]').click()
    expect(page.locator('details[open]')).to_have_count(1)
    page.locator('[data-sector=mosswood]').click()
    expect(page.locator('#dispatch')).to_be_enabled()
    page.locator('[data-step=squad]').click()
    page.locator('[data-member=pike]').click()
    page.locator('[data-member=odrin]').click()
    expect(page.locator('#dispatch')).to_be_disabled()
    page.locator('[data-member=mira]').click()
    expect(page.locator('#dispatch')).to_be_enabled()
    page.locator('#dispatch').click()
    expect(page.locator('.clock')).to_have_text('15:00')
    expect(page.locator('.away-note strong')).to_have_text('Finish the methods section')
    page.locator('#recall').click()
    expect(page.locator('[role=dialog]')).to_be_visible()
    page.keyboard.press('Escape')
    expect(page.locator('[role=dialog]')).to_have_count(0)
    page.locator('.preview-nav [data-view=return]').click()
    expect(page.locator('details[open]')).to_have_count(0)
    page.locator('[data-group=report] summary').click()
    expect(page.locator('.report')).to_be_visible()
    page.locator('#phone').screenshot(path=str(directory / 'report-open.png'))

    for width in [390, 320]:
        page.set_viewport_size({"width": width, "height": 844})
        page.goto((directory / 'index.html').as_uri()+'?view=dispatch&embed=1')
        page.evaluate('document.fonts.ready')
        assert not page.evaluate('document.documentElement.scrollWidth>innerWidth'), f'Page overflow at {width}'
        assert not page.locator('.scroll').evaluate('el=>el.scrollWidth>el.clientWidth'), f'Screen overflow at {width}'
        expect(page.locator('#dispatch')).to_be_visible()
        if width == 390:
            page.locator('#phone').screenshot(path=str(directory / 'dispatch.png'))
    print('Accordion exclusivity, duration constraints, selection, dispatch, recall, report, and mobile widths passed.')
    print('JavaScript errors:', errors)
    assert not errors
    browser.close()
