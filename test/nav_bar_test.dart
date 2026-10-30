import 'dart:io';
import 'dart:typed_data';

import 'package:financeapp/layout/walletLayoutPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    // Without the real font Ahem is used and every label is far too wide.
    final rubik = FontLoader('Rubik');
    for (final w in ['Regular', 'Bold', 'Light', 'Medium']) {
      rubik.addFont(File('lib/shared/styles/fonts/Rubik/Rubik-$w.ttf')
          .readAsBytes()
          .then((b) => ByteData.view(b.buffer)));
    }
    await rubik.load();
  });

  // Same surroundings as in Walletlayoutpage: 24px outside, 16px inside the glass.
  Widget bar(int selected) => MaterialApp(
        home: Scaffold(
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: WalletNavTabs(selectedIndex: selected, onTabChange: (_) {}),
            ),
          ),
        ),
      );

  for (final width in [320.0, 360.0, 411.0, 768.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('no overflow on a ${width.toInt()}dp screen, system font x$scale',
          (t) async {
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        for (var tab = 0; tab < 4; tab++) {
          await t.pumpWidget(bar(tab));
          // Frame by frame, so the half-expanded tab-switch animation is checked too.
          for (var i = 0; i < 6; i++) {
            await t.pump(const Duration(milliseconds: 100));
            expect(t.takeException(), isNull, reason: 'tab $tab, frame $i');
          }
        }
      });
    }
  }

  test('roomy screens keep the original 14px tab padding, narrow ones shrink it', () {
    const scaler = TextScaler.noScaling;
    expect(WalletNavTabs.tabPadding(1000, scaler), 14);
    expect(WalletNavTabs.tabPadding(280, scaler), lessThan(14));
    expect(WalletNavTabs.tabPadding(10, scaler), 4); // never below the floor
  });
}
