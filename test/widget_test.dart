import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:spideyhood/main.dart';

void main() {
  testWidgets('Spideyhood app initializes smoke test', (WidgetTester tester) async {
    final Uint8List mockPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        return ByteData.view(mockPng.buffer);
      },
    );

    await tester.pumpWidget(const SpideyhoodApp());
    expect(find.byType(SpideyhoodApp), findsOneWidget);
  });
}
