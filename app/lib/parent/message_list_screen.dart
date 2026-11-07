import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/server_models.dart';
import '../common/common.dart';
import '../config.dart';
import 'parent_store.dart';
import 'situation_info.dart';

/// 3-2 메시지 전체, 3-3 분류별 메시지.
/// [category]가 null이면 저장한 메시지만, 아니면 그 분류의 상황을 모두 보여 준다.
class MessageListScreen extends StatelessWidget {
  const MessageListScreen({
    super.key,
    required this.store,
    required this.category,
    required this.onCategoryChanged,
    required this.onWrite,
  });

  final ParentStore store;
  final String? category;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<Situation> onWrite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.s8,
            AppSpacing.screenHorizontal,
            0,
          ),
          child: TopNavBar(title: '메시지'),
        ),
        const SizedBox(height: AppSpacing.s24),
        _filters(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.s24,
              AppSpacing.screenHorizontal,
              AppSpacing.s24,
            ),
            children: [
              ...category == null ? _allCards() : _categoryCards(category!),
              const SizedBox(height: AppSpacing.s12),
              Text(
                '상황마다 하나의 메시지가 ${AppConfig.childNickname}를 기다리고 있어요.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption12.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filters() {
    return SizedBox(
      height: AppSizes.chipHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        children: [
          OngiChip(
            label: '전체 ${store.messages.length}',
            selected: category == null,
            onTap: () => onCategoryChanged(null),
          ),
          for (final c in store.categories) ...[
            const SizedBox(width: AppSpacing.s8),
            OngiChip(
              label:
                  '${categoryLabel(c)} ${store.savedIn(c)}/${store.situationsIn(c).length}',
              selected: category == c,
              onTap: () => onCategoryChanged(c),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _allCards() {
    if (store.messages.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
          child: Text(
            '아직 남긴 메시지가 없어요.\n분류를 골라 첫 메시지를 남겨 보세요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ];
    }
    return [
      for (final m in store.messages)
        _spaced(_messageCard(m, store.situation(m.situationId), full: true)),
    ];
  }

  List<Widget> _categoryCards(String category) {
    return [
      for (final s in store.situationsIn(category))
        _spaced(switch (store.messageFor(s.id)) {
          final m? => _messageCard(m, s, full: false),
          null => EmptySituationCard(title: s.name, onTap: () => onWrite(s)),
        }),
    ];
  }

  Widget _spaced(Widget card) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s12),
    child: card,
  );

  /// [full]이면 3-2 모양(분류 표시, 본문 여러 줄), 아니면 3-3 모양(본문 한 줄).
  Widget _messageCard(ParentMessage m, Situation? s, {required bool full}) {
    return MessageCard(
      title: s?.name ?? '상황 ${m.situationId}',
      category: full && s != null ? categoryLabel(s.category) : null,
      body: m.text,
      bodyMaxLines: full ? 3 : 1,
      typeLabel: m.isVoice ? '음성' : '텍스트',
      typeIcon: m.isVoice ? LucideIcons.mic : LucideIcons.type,
      statusLabel: m.delivered ? '전달됨' : '전달 대기',
      statusMuted: !m.delivered,
      date: _date(m.createdAt),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}.${_two(d.month)}.${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
