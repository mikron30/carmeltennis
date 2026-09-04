import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtk_flutter/booking_tokens.dart';
import 'package:gtk_flutter/widgets/recents_strip.dart';

void main() {
  Widget buildStrip({
    required String? selected,
    required ValueChanged<String> onSelect,
  }) {
    return MaterialApp(
      theme: ThemeData(extensions: const [BookingTokens.light]),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: RecentsStrip(
              recents: const [
                RecentPartner(label: 'נועה', value: 'נועה כהן'),
                RecentPartner(label: 'דני', value: 'דני לוי'),
              ],
              selected: selected,
              onSelect: onSelect,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('שותף is the default rightmost choice and replaces plus',
      (tester) async {
    String? selectedValue;
    await tester.pumpWidget(
      buildStrip(
        selected: null,
        onSelect: (value) => selectedValue = value,
      ),
    );

    expect(find.text('שותף'), findsOneWidget);
    expect(find.text('+'), findsNothing);
    expect(find.text('עם:'), findsNothing);
    expect(
      tester.getCenter(find.text('שותף')).dx,
      greaterThan(tester.getCenter(find.text('נועה')).dx),
    );

    Material? selectedMaterial;
    tester.element(find.text('שותף')).visitAncestorElements((element) {
      if (element.widget is Material) {
        selectedMaterial = element.widget as Material;
        return false;
      }
      return true;
    });
    expect(selectedMaterial?.color, BookingTokens.light.clay);

    await tester.tap(find.text('שותף'));
    expect(selectedValue, '');

    await tester.tap(find.text('נועה'));
    expect(selectedValue, 'נועה כהן');
  });
}
