import 'package:flutter/material.dart';

import '../common/common.dart';
import 'parent_store.dart';

/// '추천 10개 채우기' 진행 카드 (3-1, 3-5). 모양은 공통 [GoalProgressCard]를 쓴다.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context) {
    return GoalProgressCard(
      title: '추천 ${ParentStore.goal}개 채우기',
      progress: progress,
      goal: ParentStore.goal,
      caption: '작은 메시지 하나가 아이의 든든한 힘이 돼요.',
    );
  }
}
