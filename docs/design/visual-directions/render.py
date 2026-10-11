"""Render the type/color study and check its presentations in local Chrome."""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

root = Path(__file__).resolve().parent
prototype = (root.parent / 'expedition-prototype' / 'index.html').as_uri()

with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe', headless=True)
    page = browser.new_page(viewport={'width':1300, 'height':1450}, device_scale_factor=1)
    errors = []
    failed = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('requestfailed', lambda request: failed.append(request.url))

    def ready(target):
        target.locator('.screen').wait_for()
        target.evaluate('document.fonts.ready')
        for img in target.locator('.art img').all():
            img.evaluate('img => img.decode()')

    page.goto((root/'index.html').as_uri())
    for view in ['camp','dispatch','return','away']:
        page.locator(f'[data-view={view}]').click()
        expect(page.locator(f'[data-view={view}]')).to_have_attribute('aria-pressed','true')
        page.evaluate('document.fonts.ready')
        for frame in page.frames[1:]:
            ready(frame)
            assert frame.evaluate('state.view') == view
            assert not frame.evaluate('document.documentElement.scrollWidth > innerWidth')
        page.screenshot(path=str(root/f'{view}.png'),full_page=True)

    for treatment,title_font,body_font in [('survey','SurveyTitle','SurveyText'),('night','NightTitle','NightText'),('woodcut','WoodcutTitle','Body')]:
        for width in [390,320]:
            page.set_viewport_size({'width':width,'height':844})
            for view in ['camp','dispatch','return','away']:
                page.goto(prototype+f'?treatment={treatment}&view={view}&embed=1')
                ready(page)
                assert page.evaluate('document.documentElement.dataset.treatment') == treatment
                assert not page.evaluate('document.documentElement.scrollWidth>innerWidth'), (treatment,width,view)
                assert not page.locator('.screen').evaluate('el=>el.scrollWidth>el.clientWidth'), (treatment,width,view)
                expect(page.locator('.action-area button').first).to_be_in_viewport()
                if page.locator('.scroll').count():
                    sizes=page.locator('.scroll').evaluate('el=>[el.clientHeight,el.scrollHeight]')
                    print(treatment, width, view, sizes)
                    if width==390: assert sizes[1]<=sizes[0]+1, (treatment,view,sizes)
                assert page.evaluate(f'document.fonts.check("600 28px {title_font}")')
                assert page.evaluate(f'document.fonts.check("400 17px {body_font}")')

        # Check the themed disclosure and sheet states, followed by the same loop.
        page.set_viewport_size({'width':1200,'height':950})
        page.goto(prototype+f'?treatment={treatment}')
        ready(page)
        page.locator('[data-group=party] summary').click()
        page.locator('[data-loadout=odrin]').click()
        expect(page.locator('[role=dialog]')).to_be_visible()
        page.locator('#phone').screenshot(path=str(root/f'{treatment}-equipment.png'))
        page.keyboard.press('Escape')
        page.locator('[data-action=plan]').click()
        page.locator('[data-minutes="15"]').click()
        expect(page.locator('#dispatch')).to_be_disabled()
        expect(page.locator('.warning')).to_be_visible()
        page.locator('[data-minutes="25"]').click()
        page.locator('[data-step=destination]').click()
        page.locator('[data-job=survey]').click()
        assert page.evaluate('forecast().yields') == [149,44,10]
        page.locator('#phone').screenshot(path=str(root/f'{treatment}-orders.png'))
        page.locator('#dispatch').click()
        page.locator('#finish-demo').click()
        page.locator('[data-action=camp]').click()
        page.locator('[data-action=upgrade]').click()
        expect(page.locator('[data-action=confirm-upgrade]')).to_be_visible()
        page.locator('[data-action=confirm-upgrade]').click()
        assert page.evaluate('state.facilities.forge') == 2

    # Plain entry uses the approved launch direction; cream remains an archive.
    page.goto(prototype)
    ready(page)
    assert page.evaluate('document.documentElement.dataset.treatment') == 'night'
    page.goto(prototype+'?treatment=cream')
    ready(page)
    assert page.evaluate('document.documentElement.dataset.treatment') is None
    assert page.locator('.phone').evaluate('el=>getComputedStyle(el).backgroundColor') == 'rgb(242, 238, 225)'
    assert not errors, errors
    assert not failed, failed
    print('PASS: three treatments, four states, 320/390px widths, fonts loaded, modal/disclosure/dispatch/spend interactions, Night Watch default, cream archive preserved.')
    browser.close()
