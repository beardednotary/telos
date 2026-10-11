"""Exercise the local prototype and render review images; no app state or network.

Run: python docs/design/expedition-prototype/render.py
Requires the already-installed Python Playwright package and local Chrome.
"""
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

directory = Path(__file__).resolve().parent
url = (directory / 'index.html').as_uri()

with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        headless=True,
    )
    page = browser.new_page(viewport={'width': 1300, 'height': 1150})
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))

    def ready():
        page.locator('.screen').wait_for()
        page.evaluate('document.fonts.ready')
        for img in page.locator('.art img').all():
            img.evaluate('img => img.decode()')

    def saved():
        return page.evaluate('({credits:state.credits, alloy:state.alloy, intel:state.intel, completed:state.completed, facilities:state.facilities, gear:state.gear})')

    def reset():
        page.locator('#reset-demo').click()
        ready()

    page.goto(url)
    ready()
    initial = saved()
    assert page.evaluate('forecast().base') == [165, 59, 6]
    assert page.evaluate('forecast().yields') == [149, 74, 5]
    assert page.evaluate("[...document.fonts].filter(f=>f.status==='loaded').map(f=>f.family)")
    expect(page.locator('details[open]')).to_have_count(0)

    # Identity changes are optional, reversible and independent of progression.
    assert page.evaluate('document.documentElement.dataset.treatment') == 'night'
    page.locator('[data-action=identity]').click()
    page.locator('#guild-name').fill('The <Ash> & Lantern')
    page.locator('[data-guild-sigil=compass]').click()
    expect(page.locator('#guild-name')).to_have_value('The <Ash> & Lantern')
    page.locator('#guild-name').fill('The Wayfarers')
    page.locator('#phone').screenshot(path=str(directory/'guild-identity.png'))
    page.locator('#guild-name').fill('The <Ash> & Lantern')
    page.locator('[data-action=save-identity]').click()
    expect(page.locator('.guild-heading button')).to_contain_text('The <Ash> & Lantern')
    assert page.evaluate('state.guild.sigil') == 'compass'
    assert saved() == initial
    assert page.evaluate('forecast().yields') == [149,74,5]
    page.locator('[data-action=identity]').click()
    page.locator('#guild-name').fill('Uncommitted name')
    page.locator('[data-guild-sigil=branch]').click()
    page.keyboard.press('Escape')
    expect(page.locator('[data-action=identity]')).to_be_focused()
    assert page.evaluate('state.guild') == {'name':'The <Ash> & Lantern','sigil':'compass'}
    page.locator('[data-action=identity]').click()
    page.locator('#guild-name').fill('   ')
    expect(page.locator('[data-action=save-identity]')).to_be_disabled()
    page.keyboard.press('Escape')
    reset()

    # Camp interaction cannot create earnings. Only one management section opens.
    page.locator('[data-group=party] summary').click()
    page.locator('[data-group=stores] summary').click()
    expect(page.locator('details[open]')).to_have_count(1)
    expect(page.locator('[data-group=party]')).not_to_have_attribute('open', '')
    assert saved() == initial
    page.locator('[data-action=projects]').click()
    page.locator('[data-project=archive]').click()
    expect(page.locator('.project h3')).to_have_text('Archive II')
    page.locator('[data-action=projects]').click()
    page.locator('[data-project=forge]').click()
    assert saved() == initial

    # Equipment comparison, exclusive ownership, keyboard trap, and focus restore.
    page.locator('[data-group=party] summary').click()
    page.locator('[data-loadout=odrin]').click()
    expect(page.locator('[role=dialog]')).to_be_visible()
    expect(page.locator('[data-equip=g3]')).to_contain_text('Slag Brace')
    page.locator('#phone').screenshot(path=str(directory / 'equipment.png'))
    page.keyboard.press('Tab')
    expect(page.locator('.close-sheet')).to_be_focused()
    page.keyboard.press('Shift+Tab')
    expect(page.locator('[data-action=done-equipment]')).to_be_focused()
    page.locator('[data-equip=g3]').click()
    assert page.evaluate('forecast().yields') == [151, 76, 5]
    assert saved() == initial
    page.keyboard.press('Escape')
    expect(page.locator('[data-loadout=odrin]')).to_be_focused()
    page.locator('[data-loadout=mira]').click()
    expect(page.locator('[data-equip=g3]')).to_have_count(0)
    page.locator('[data-slot="1"]').click()
    page.locator('[data-equip=g2]').click()
    page.locator('[data-action=done-equipment]').click()
    assert page.evaluate('new Set(Object.values(state.members).flatMap(m=>m.equipment.filter(Boolean))).size') == 3
    assert saved() == initial
    reset()

    # Duration never silently changes destination. Both real-world constraints hold.
    page.locator('[data-action=plan]').click()
    expect(page.locator('[data-group=time]')).to_have_attribute('open', '')
    page.locator('#intent').fill('Finish <methods> & check "figures"')
    page.locator('[data-minutes="15"]').click()
    expect(page.locator('#dispatch')).to_be_disabled()
    expect(page.locator('.warning')).to_contain_text('at least 25 minutes')
    assert page.evaluate('state.plan.sector') == 'blackstone'
    page.locator('[data-action=custom]').click()
    page.locator('#custom-minutes').fill('26')
    page.locator('#custom-minutes').press('Tab')
    expect(page.locator('#dispatch')).to_be_disabled()
    page.locator('#custom-minutes').fill('25')
    page.locator('#custom-minutes').press('Tab')
    expect(page.locator('#dispatch')).to_be_enabled()
    page.locator('[data-step=destination]').click()
    expect(page.locator('details[open]')).to_have_count(1)
    page.locator('[data-sector=cinder]').click()
    expect(page.locator('#dispatch')).to_be_disabled()
    page.locator('[data-sector=blackstone]').click()
    page.locator('[data-job=survey]').click()
    assert page.evaluate('forecast().yields') == [149, 44, 10]
    page.locator('[data-job=extraction]').click()
    page.locator('[data-step=squad]').click()
    page.locator('[data-member=mira]').click()
    page.locator('[data-member=odrin]').click()
    expect(page.locator('#dispatch')).to_be_disabled()
    page.locator('[data-member=mira]').click()
    page.locator('[data-member=odrin]').click()
    page.locator('[data-action=collapse]').click()
    expect(page.locator('details[open]')).to_have_count(0)
    page.locator('#phone').screenshot(path=str(directory / 'dispatch.png'))
    assert saved() == initial

    # Quiet committed session; completion occurs only through the external harness.
    plan = page.evaluate('structuredClone(state.plan)')
    page.locator('#dispatch').click()
    expect(page.locator('.clock')).to_have_text('25:00')
    expect(page.locator('.away-note strong')).to_have_text('Finish <methods> & check "figures"')
    assert page.evaluate('state.run.plan') == plan
    expect(page.locator('#phone button')).to_have_count(1)
    assert saved() == initial
    page.locator('#phone').screenshot(path=str(directory / 'away.png'))
    page.locator('[data-action=recall]').click()
    page.keyboard.press('Escape')
    expect(page.locator('[data-action=recall]')).to_be_focused()
    page.locator('#finish-demo').click()
    expect(page.locator('.relic h3')).to_have_text('Deep Lamp')
    assert saved()['credits'] == 245 and saved()['alloy'] == 92 and saved()['intel'] == 66
    assert saved()['completed'] == 1 and len(saved()['gear']) == 4
    expect(page.locator('#finish-demo')).to_be_disabled()
    after_finish = saved()
    page.evaluate('completeRun()')
    assert saved() == after_finish
    page.locator('[data-group=report] summary').click()
    expect(page.locator('.report-table')).to_contain_text('Extraction')
    page.locator('#phone').screenshot(path=str(directory / 'return-report.png'))
    page.locator('[data-action=camp]').click()

    # A 25-minute run funds the goal; spending is deducted exactly once.
    page.locator('[data-action=upgrade]').click()
    page.locator('[data-action=confirm-upgrade]').click()
    assert saved()['credits'] == 125 and saved()['alloy'] == 67
    assert saved()['facilities']['forge'] == 2
    expect(page.locator('[data-action=upgrade]')).to_have_count(0)
    assert page.evaluate('forecast().yields') == [149, 77, 5]
    page.locator('[data-group=party] summary').click()
    page.locator('[data-loadout=odrin]').click()
    page.locator('[data-slot="1"]').click()
    page.locator('[data-equip=g4]').click()
    page.locator('[data-action=done-equipment]').click()
    assert page.evaluate('forecast().yields') == [149, 82, 5]
    before_repeat = saved()
    page.locator('[data-action=repeat]').click()
    assert page.evaluate('state.run.plan') == plan
    assert page.evaluate('state.run.loadouts.odrin') == ['g2', 'g4']
    assert page.evaluate('state.run.forecast.yields') == [149, 82, 5]
    assert saved() == before_repeat
    page.locator('[data-action=recall]').click()
    page.locator('[data-action=confirm-recall]').click()
    assert saved() == before_repeat
    expect(page.locator('.notice')).to_contain_text('No time elapsed')

    # Other destinations return an appropriate item and destination name.
    for sector, minutes, item, title in [('mosswood', 15, 'Field Optic', 'the Verge'), ('cinder', 45, 'Cinder Key', 'the Archive')]:
        reset()
        page.locator('[data-action=plan]').click()
        page.locator(f'[data-minutes="{minutes}"]').click()
        page.locator('[data-step=destination]').click()
        page.locator(f'[data-sector={sector}]').click()
        page.locator('#dispatch').click()
        page.locator('#finish-demo').click()
        expect(page.locator('.relic h3')).to_have_text(item)
        expect(page.locator('.return-intro h2')).to_contain_text(title)

    # Mobile widths: no horizontal overflow, and the primary action stays visible.
    for width in [390, 320]:
        page.set_viewport_size({'width': width, 'height': 844})
        for view in ['camp', 'dispatch', 'away', 'return']:
            page.goto(url+f'?view={view}&embed=1')
            ready()
            assert not page.evaluate('document.documentElement.scrollWidth > innerWidth'), (width, view)
            assert not page.locator('.screen').evaluate('el=>el.scrollWidth>el.clientWidth'), (width, view)
            box = page.locator('.action-area').bounding_box()
            assert box['y']+box['height'] <= 844, (width, view, box)
            if page.locator('.scroll').count():
                scroll = page.locator('.scroll').evaluate('el=>({visible:el.clientHeight,content:el.scrollHeight})')
                print(f'{width}px {view}: {scroll}')
                if width == 390:
                    assert scroll['content'] <= scroll['visible']+1, (view, scroll)
        # Expanded panels remain scrollable and keep the footer in reach.
        page.goto(url+'?view=dispatch&embed=1')
        for group in ['time','destination','squad']:
            page.locator(f'[data-group={group}] summary').click()
            expect(page.locator('details[open]')).to_have_count(1)
            assert not page.locator('.scroll').evaluate('el=>el.scrollWidth>el.clientWidth'), (width, group)
            expect(page.locator('#dispatch')).to_be_in_viewport()

    page.set_viewport_size({'width':1300,'height':1150})
    page.goto((directory/'board.html').as_uri())
    page.evaluate('document.fonts.ready')
    for frame in page.frames[1:]:
        frame.locator('.screen').wait_for()
        frame.evaluate('document.fonts.ready')
        for img in frame.locator('.art img').all():
            img.evaluate('img=>img.decode()')
    page.screenshot(path=str(directory/'overview.png'), full_page=True)
    assert not errors, errors
    print('PASS: planning, gear ownership, 25-minute progression, one-time rewards, spending, recall, dialogs, 320/390px layouts; no JavaScript errors.')
    browser.close()
