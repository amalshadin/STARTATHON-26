import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hapticsync/views/games/game_arena_screen.dart';
import 'package:hapticsync/views/root_scaffold.dart';

import '../lib/main.dart';

void main() {
  testWidgets('starts without login and opens the game arena', (tester) async {
    await tester.pumpWidget(const HapticSyncTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(RootScaffold), findsOneWidget);
    expect(find.text('Welcome Back'), findsNothing);

    await tester.tap(find.byIcon(Icons.gamepad_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(GameArenaScreen), findsOneWidget);
    expect(find.text('Piano Tiles'), findsOneWidget);
  });
}
