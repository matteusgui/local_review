import 'package:flutter_test/flutter_test.dart';

/// Pumps [tester] repeatedly until a widget matching [finder] appears, or
/// [timeout] elapses. Prefer this over a fixed `Future.delayed` +
/// single `pump()` when waiting for real (non-fake-clock) async work
/// (e.g. background-isolate database opens, real dart:io) to complete —
/// it resolves as soon as the awaited work is done rather than waiting a
/// fixed, arbitrarily-chosen delay.
///
/// Must be called from inside `tester.runAsync()` when the work it's
/// waiting on performs real async I/O, same as the fixed-delay code this
/// helper replaces.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// Same idea as [pumpUntil], for the handful of sites where completion is
/// signalled by a plain Dart value (e.g. a captured callback result) rather
/// than by a widget appearing in the tree — so there is no meaningful
/// [Finder] to wait on.
Future<void> pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TestFailure('Timed out waiting for condition');
}
