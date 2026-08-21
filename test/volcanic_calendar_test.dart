import 'package:flutter_test/flutter_test.dart';
import 'package:lavawake_rush/data/mutations.dart';
import 'package:lavawake_rush/data/volcanic_events.dart';

/// The weekly event rotates purely on the device clock, so these invariants are
/// the only thing standing between a player and an event that flips mid-run or
/// repeats two weeks running.
void main() {
  // A Monday, so the whole week can be walked from it.
  final monday = DateTime(2026, 8, 17);

  group('week numbering', () {
    test('holds still for all seven days and steps on Monday', () {
      final base = VolcanicCalendar.weekNumber(monday);
      for (var day = 0; day < 7; day++) {
        expect(
          VolcanicCalendar.weekNumber(monday.add(Duration(days: day))),
          base,
          reason: 'day +$day should stay inside week $base',
        );
      }
      expect(
        VolcanicCalendar.weekNumber(monday.add(const Duration(days: 7))),
        base + 1,
      );
    });

    test('never goes negative across a decade of weeks', () {
      for (var week = 0; week < 520; week++) {
        final at = monday.add(Duration(days: 7 * week));
        expect(VolcanicCalendar.weekNumber(at), greaterThanOrEqualTo(0));
      }
    });
  });

  group('rotation', () {
    test('consecutive weeks give distinct events until the cycle repeats', () {
      final count = VolcanicCalendar.events.length;
      final seen = <String>{};
      for (var week = 0; week < count; week++) {
        seen.add(VolcanicCalendar.current(monday.add(Duration(days: 7 * week))).id);
      }
      expect(seen.length, count);
    });

    test('the cycle closes on itself', () {
      final count = VolcanicCalendar.events.length;
      expect(
        VolcanicCalendar.current(monday.add(Duration(days: 7 * count))).id,
        VolcanicCalendar.current(monday).id,
      );
    });

    test('next() is the event that follows current()', () {
      expect(
        VolcanicCalendar.next(monday).id,
        VolcanicCalendar.current(monday.add(const Duration(days: 7))).id,
      );
    });

    test('every event id and quest id is unique', () {
      final eventIds = VolcanicCalendar.events.map((e) => e.id).toSet();
      expect(eventIds.length, VolcanicCalendar.events.length);

      final questIds = [
        for (final event in VolcanicCalendar.events)
          for (final quest in event.quests) quest.id,
      ];
      expect(questIds.toSet().length, questIds.length);
    });

    test('questById resolves every objective it can be handed', () {
      for (final event in VolcanicCalendar.events) {
        for (final quest in event.quests) {
          expect(VolcanicCalendar.questById(quest.id), same(quest));
        }
      }
      expect(VolcanicCalendar.questById('nothing_like_this'), isNull);
    });
  });

  group('countdown', () {
    test('always targets the coming Monday at midnight', () {
      for (var day = 0; day < 7; day++) {
        final at = monday.add(Duration(days: day, hours: 13, minutes: 30));
        final end = VolcanicCalendar.endsAt(at);
        expect(end.weekday, DateTime.monday);
        expect(end.hour, 0);
        expect(end.minute, 0);

        final left = VolcanicCalendar.remaining(at);
        expect(left.isNegative, isFalse);
        expect(left.inDays, lessThan(7));
      }
    });

    test('the week that ends is the week that was live', () {
      for (var day = 0; day < 7; day++) {
        final at = monday.add(Duration(days: day, hours: 9));
        // A moment before the deadline is still this week's event; a moment
        // after it is the next one.
        final end = VolcanicCalendar.endsAt(at);
        expect(
          VolcanicCalendar.current(end.subtract(const Duration(minutes: 1))).id,
          VolcanicCalendar.current(at).id,
        );
        expect(
          VolcanicCalendar.current(end).id,
          VolcanicCalendar.next(at).id,
        );
      }
    });

    test('formats without days once the week is nearly done', () {
      expect(VolcanicCalendar.formatRemaining(const Duration(days: 2, hours: 3)), '2D 3H 00M');
      expect(VolcanicCalendar.formatRemaining(const Duration(hours: 5, minutes: 7)), '5H 07M 00S');
      expect(VolcanicCalendar.formatRemaining(const Duration(minutes: 4, seconds: 9)), '04M 09S');
      expect(VolcanicCalendar.formatRemaining(Duration.zero), 'A MOMENT');

      expect(VolcanicCalendar.formatRemainingShort(const Duration(days: 3, hours: 8)), '3D 8H');
      expect(VolcanicCalendar.formatRemainingShort(const Duration(hours: 2, minutes: 5)), '2H 05M');
      expect(VolcanicCalendar.formatRemainingShort(Duration.zero), 'ENDING');
    });
  });

  group('modifiers', () {
    test('every event changes the run and leaves a playable state', () {
      final baseline = RunModifiers();
      for (final event in VolcanicCalendar.events) {
        final mods = RunModifiers();
        event.apply(mods);

        // Something must actually differ, or the event is cosmetic.
        final changed =
            mods.scrollSpeedMul != baseline.scrollSpeedMul ||
            mods.lootMul != baseline.lootMul ||
            mods.scoreMul != baseline.scoreMul ||
            mods.meltRateMul != baseline.meltRateMul ||
            mods.damageTakenMul != baseline.damageTakenMul ||
            mods.heatDecayMul != baseline.heatDecayMul ||
            mods.volleyShards != baseline.volleyShards;
        expect(changed, isTrue, reason: '${event.id} changes nothing');

        // Multipliers that reach zero or below would freeze or invert the run.
        expect(mods.scrollSpeedMul, greaterThan(0), reason: event.id);
        expect(mods.meltRateMul, greaterThan(0), reason: event.id);
        expect(mods.lootMul, greaterThan(0), reason: event.id);
        expect(mods.scoreMul, greaterThan(0), reason: event.id);
        expect(mods.damageTakenMul, greaterThan(0), reason: event.id);
        expect(mods.surgeCooldownMul, greaterThan(0), reason: event.id);
        expect(mods.volleyCooldownMul, greaterThan(0), reason: event.id);
        expect(mods.volleyShards, greaterThan(0), reason: event.id);
        expect(mods.reviveCharges, greaterThanOrEqualTo(0), reason: event.id);
      }
    });

    test('applying an event twice is not how it is used, but stays finite', () {
      for (final event in VolcanicCalendar.events) {
        final mods = RunModifiers();
        event.apply(mods);
        event.apply(mods);
        expect(mods.scrollSpeedMul.isFinite, isTrue, reason: event.id);
        expect(mods.lootMul.isFinite, isTrue, reason: event.id);
      }
    });
  });

  group('briefing content', () {
    test('every event is presentable and has objectives', () {
      for (final event in VolcanicCalendar.events) {
        expect(event.name.trim(), isNotEmpty, reason: event.id);
        expect(event.tagline.trim(), isNotEmpty, reason: event.id);
        expect(event.description.trim(), isNotEmpty, reason: event.id);
        expect(event.rules, isNotEmpty, reason: event.id);
        expect(event.quests, isNotEmpty, reason: event.id);
        for (final quest in event.quests) {
          expect(quest.target, greaterThan(0), reason: quest.id);
          expect(quest.reward, greaterThan(0), reason: quest.id);
        }
      }
    });
  });
}
