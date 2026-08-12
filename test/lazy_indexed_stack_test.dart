import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/core/services/presence_service.dart';
import 'package:pawdo/core/widgets/lazy_indexed_stack.dart';

void main() {
  testWidgets('tabs build only when first selected and preserve their state', (
    tester,
  ) async {
    final built = <int>[];
    late StateSetter changeIndex;
    var index = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            changeIndex = setState;
            return LazyIndexedStack(
              index: index,
              builders: List.generate(
                3,
                (tab) => (_) {
                  built.add(tab);
                  return Text('Pestaña $tab');
                },
              ),
            );
          },
        ),
      ),
    );

    expect(built, [0]);
    changeIndex(() => index = 2);
    await tester.pump();
    expect(built, [0, 2]);
    changeIndex(() => index = 0);
    await tester.pump();
    expect(built, [0, 2]);
  });

  test('presence heartbeat stays inside the three-minute freshness window', () {
    expect(PresenceService.heartbeatInterval, const Duration(minutes: 2));
    expect(
      PresenceService.heartbeatInterval,
      lessThan(const Duration(minutes: 3)),
    );
  });
}
