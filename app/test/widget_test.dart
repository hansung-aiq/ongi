import 'package:flutter_test/flutter_test.dart';
import 'package:ongi_app/main.dart';

void main() {
  testWidgets('앱이 뜨고 공통 버튼이 보인다', (tester) async {
    await tester.pumpWidget(const OngiApp());

    expect(find.text('온기'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
