import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ongi_app/common/common.dart';
import 'package:ongi_app/common/component_gallery.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('컴포넌트가 오류 없이 그려진다', (tester) async {
    await tester.pumpWidget(_wrap(const ComponentGallery()));
    await tester.pump();

    expect(find.byType(ComponentGallery), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OngiButton은 누르면 콜백을 부르고 null이면 비활성이다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            OngiButton(label: '켜짐', onPressed: () => taps++),
            const OngiButton(label: '꺼짐', onPressed: null),
          ],
        ),
      ),
    );

    await tester.tap(find.text('켜짐'));
    await tester.tap(find.text('꺼짐'), warnIfMissed: false);

    expect(taps, 1);
    expect(tester.getSize(find.byType(TextButton).first).height, 52);
  });

  testWidgets('OngiTextField는 글자 수를 넘겨 입력되지 않고 오류를 보여 준다', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        OngiTextField(controller: controller, maxLength: 3, errorText: '오류 문구'),
      ),
    );

    await tester.enterText(find.byType(TextField), '가나다라');

    expect(controller.text, '가나다');
    expect(find.text('오류 문구'), findsOneWidget);
  });

  testWidgets('탭바와 입력 방식 탭은 누른 번호를 알려 준다', (tester) async {
    int? tab;
    int? segment;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            OngiSegmentedTabs(
              segments: const [
                OngiSegment(label: '음성'),
                OngiSegment(label: '글'),
              ],
              selectedIndex: 0,
              onChanged: (index) => segment = index,
            ),
            BottomTabBar(
              items: const [
                BottomTabItem(icon: LucideIcons.house, label: '홈'),
                BottomTabItem(icon: LucideIcons.settings, label: '설정'),
              ],
              currentIndex: 0,
              onTap: (index) => tab = index,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('글'));
    await tester.tap(find.text('설정'));

    expect(segment, 1);
    expect(tab, 1);
  });

  testWidgets('입력 방식 탭의 선택 표시는 틀 높이를 채운다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OngiSegmentedTabs(
          segments: const [
            OngiSegment(label: '음성'),
            OngiSegment(label: '글'),
          ],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      ),
    );

    final pill = find
        .ancestor(of: find.text('음성'), matching: find.byType(Container))
        .first;
    expect(tester.getSize(pill).height, 44);
  });

  testWidgets('TopNavBar는 콜백이 없는 버튼을 숨긴다', (tester) async {
    await tester.pumpWidget(_wrap(TopNavBar(title: '제목', onClose: () {})));

    expect(find.byIcon(LucideIcons.x), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowLeft), findsNothing);
  });

  testWidgets('Waveform은 애니메이션을 꺼도 그려지고 틀 크기를 지킨다', (tester) async {
    await tester.pumpWidget(_wrap(const Waveform.large(animate: false)));

    expect(tester.getSize(find.byType(Waveform)), const Size(200, 80));
    expect(tester.takeException(), isNull);
  });
}
