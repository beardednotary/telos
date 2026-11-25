import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/services/backup.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/services/review_prompt.dart';
import 'package:telos/state/guild_controller.dart';

/// Counts the requests, so when Telos asks can be asserted without the
/// App Store.
class FakeReviewPrompt implements ReviewPrompt {
  int requests = 0;
  bool fail = false;

  @override
  Future<void> request() async {
    requests++;
    if (fail) throw Exception('no App Store here');
  }
}

void main() {
  late FakeReviewPrompt review;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    review = FakeReviewPrompt();
  });

  Future<GuildController> boot() async {
    final c = GuildController(Persistence(), reviewPrompt: review);
    await c.boot();
    c.g.onboarded = true;
    addTearDown(c.dispose);
    return c;
  }

  Future<void> run(GuildController c, {bool recalled = false}) async {
    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    await c.finishRun(recalled: recalled);
    await c.dismissDebrief();
  }

  test('asks after the second full run, not the first', () async {
    final c = await boot();
    await run(c);
    expect(review.requests, 0);
    await run(c);
    expect(review.requests, 1);
    expect(c.g.reviewPrompts, 1);
  });

  test('a recall never brings the prompt, even past a milestone', () async {
    final c = await boot();
    await run(c);
    await run(c, recalled: true);
    await run(c, recalled: true);
    expect(review.requests, 0);
    // The next full run is the second, and that report asks.
    await run(c);
    expect(review.requests, 1);
  });

  test('asks once more at the twelfth full run, then never again', () async {
    final c = await boot();
    for (var i = 0; i < 11; i++) {
      await run(c);
    }
    expect(review.requests, 1);
    await run(c);
    expect(review.requests, 2);
    for (var i = 0; i < 10; i++) {
      await run(c);
    }
    expect(review.requests, 2);
  });

  test('a guild already past the second run is asked at its next one',
      () async {
    final c = await boot();
    for (var i = 0; i < 5; i++) {
      await run(c);
    }
    // Saves from before the prompt existed have no count.
    c.g.reviewPrompts = 0;
    review.requests = 0;
    await run(c);
    expect(review.requests, 1);
  });

  test('a refused prompt does not stop the report closing', () async {
    final c = await boot();
    review.fail = true;
    await run(c);
    await run(c);
    expect(review.requests, 1);
    expect(c.pendingDebrief, isNull);
    // Counted all the same: a broken prompt is not retried every run.
    expect(c.g.reviewPrompts, 1);
  });

  test('the count survives a restart and a backup', () async {
    final c = await boot();
    await run(c);
    await run(c);

    final again = GuildController(Persistence(), reviewPrompt: review);
    await again.boot();
    addTearDown(again.dispose);
    expect(again.g.reviewPrompts, 1);
    expect(Backup.decode(Backup.encode(c.g))!.reviewPrompts, 1);
  });
}
