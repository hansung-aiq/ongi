import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'common.dart';

/// 공통 컴포넌트 화면.
class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  int _segment = 0;
  int _tab = 0;
  bool _selected = true;
  int _choice = 0;
  int _step = 0;

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading20),
          const SizedBox(height: AppSpacing.s12),
          for (final child in children) ...[
            child,
            const SizedBox(height: AppSpacing.s12),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomTabBar(
        items: const [
          BottomTabItem(icon: LucideIcons.house, label: '홈'),
          BottomTabItem(icon: LucideIcons.messageCircle, label: '메시지'),
          BottomTabItem(icon: LucideIcons.settings, label: '설정'),
        ],
        currentIndex: _tab,
        onTap: (index) => setState(() => _tab = index),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.s16,
          ),
          children: [
            TopNavBar(title: '공통 컴포넌트', onBack: () {}, onClose: () {}),
            const SizedBox(height: AppSpacing.section),
            _section('글자', [
              Text('필요한 순간에 닿는', style: AppTextStyles.display40),
              Text('title/28 가장 익숙한 목소리', style: AppTextStyles.title28),
              Text('heading/20 가장 익숙한 목소리', style: AppTextStyles.heading20),
              Text('subtitle/18 가장 익숙한 목소리', style: AppTextStyles.subtitle18),
              Text('body/18 가장 익숙한 목소리', style: AppTextStyles.body18),
              Text('label/16 가장 익숙한 목소리', style: AppTextStyles.label16),
              Text('body/16 가장 익숙한 목소리', style: AppTextStyles.body16),
              Text('label/14 가장 익숙한 목소리', style: AppTextStyles.label14),
              Text('body/14 가장 익숙한 목소리', style: AppTextStyles.body14),
              Text('label/12 가장 익숙한 목소리', style: AppTextStyles.label12),
              Text('caption/12 가장 익숙한 목소리', style: AppTextStyles.caption12),
            ]),
            _section('버튼', [
              OngiButton(label: '시작하기', onPressed: () {}),
              const OngiButton(label: '시작하기', onPressed: null),
              OngiButton.secondary(label: '완료', onPressed: () {}),
              const OngiButton.secondary(label: '완료', onPressed: null),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  OngiPillButton(
                    label: '다시 듣기',
                    icon: LucideIcons.play,
                    onPressed: () {},
                  ),
                  OngiPillButton(label: '다시 녹음', onPressed: () {}),
                  const OngiPillButton(label: '비활성', onPressed: null),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  RoundIconButton(
                    icon: LucideIcons.mic,
                    tooltip: '녹음 시작',
                    size: 88,
                    iconSize: 32,
                    onPressed: () {},
                  ),
                  RoundIconButton(
                    icon: LucideIcons.square,
                    tooltip: '녹음 멈추기',
                    size: 64,
                    iconSize: 24,
                    onPressed: () {},
                  ),
                  RoundIconButton(
                    icon: LucideIcons.play,
                    tooltip: '다시 듣기',
                    onPressed: () {},
                  ),
                ],
              ),
            ]),
            _section('화면 틀', [
              GestureDetector(
                onTap: () => setState(() => _step = (_step + 1) % 4),
                child: StepDots(count: 4, current: _step),
              ),
              const PageHeading(
                title: '아이를 알려주세요.',
                description: '메시지에 담길 이름과 호칭이에요.',
              ),
              const PageHeading.situation(
                category: '친구 · 관계',
                title: '친구와 싸운 날',
                description: '민준이에게 전하고 싶은 마음을 남겨주세요.',
              ),
              const PageHeading(
                title: '첫 메시지를 남겼어요',
                description: '민준이가 필요한 순간,\n엄마의 목소리로 마음을 전해드릴게요.',
                centered: true,
              ),
              const HintRow(
                icon: LucideIcons.audioLines,
                text: '녹음한 목소리 그대로 민준이에게 들려드려요.\n조용한 곳에서 편하게 말해주세요.',
              ),
            ]),
            _section('칩·탭', [
              const Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  OngiChip(label: '전체 3', selected: true),
                  OngiChip(label: '학교 · 공부 2/6'),
                  OngiChip(label: '스피커 연결됨', dotColor: AppColors.accent),
                  OngiChip(label: '텍스트', icon: LucideIcons.type),
                ],
              ),
              OngiSegmentedTabs(
                segments: const [
                  OngiSegment(label: '음성 녹음', icon: LucideIcons.mic),
                  OngiSegment(label: '텍스트 입력', icon: LucideIcons.type),
                ],
                selectedIndex: _segment,
                onChanged: (index) => setState(() => _segment = index),
              ),
            ]),
            _section('입력창', [
              const OngiTextField(hintText: '이름을 입력해 주세요'),
              const OngiTextField(
                hintText: '이름을 입력해 주세요',
                errorText: '이름을 한 글자 이상 입력해 주세요.',
              ),
              const OngiTextField(hintText: '민준', enabled: false),
              const LabeledField(
                label: '자녀 이름',
                child: OngiTextField(hintText: '민준'),
              ),
              LabeledField(
                label: '아이가 부르는 호칭',
                child: OngiChoiceGroup(
                  options: const ['엄마', '아빠'],
                  selectedIndex: _choice,
                  onChanged: (index) => setState(() => _choice = index),
                ),
              ),
            ]),
            _section('카드', [
              SelectionCard(
                title: '지금부터',
                subtitle: '저장한 메시지를 바로 들을 수 있어요',
                selected: _selected,
                onTap: () => setState(() => _selected = !_selected),
              ),
              MessageCard(
                title: '학교 가기 싫은 날',
                category: '학교 · 공부',
                body: '민준아, 오늘은 학교에 가는 게 힘들구나. 네 마음을 엄마한테 천천히 말해줄래?',
                typeLabel: '텍스트',
                typeIcon: LucideIcons.type,
                date: '2026.10.05',
                onMore: () {},
              ),
              EmptySituationCard(
                title: '시험을 망친 날',
                subtitle: '노력만큼 결과가 나오지 않았을 때',
                onTap: () {},
              ),
              const GoalProgressCard(
                title: '추천 10개 채우기',
                progress: 1,
                goal: 10,
                caption: '작은 메시지 하나가 아이의 든든한 힘이 돼요.',
              ),
            ]),
            _section('하단 버튼 묶음', [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s16),
                  child: BottomActions(
                    children: [
                      OngiButton(label: '메시지 더 남기기', onPressed: () {}),
                      OngiButton.secondary(label: '홈으로', onPressed: () {}),
                    ],
                  ),
                ),
              ),
            ]),
            _section('상태 표시', [
              const ErrorNotice(message: '녹음을 저장하지 못했어요. 다시 시도해 주세요.'),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OngiLogo(size: 80),
                  ProfileAvatar(size: 96),
                  ProfileAvatar(size: 52),
                  ProfileAvatar(size: 28),
                ],
              ),
              const Center(child: MicHalo()),
              const Center(child: MicHalo(color: AppColors.micThinking)),
              const Center(child: Waveform.large()),
              const Center(child: Waveform.small()),
            ]),
          ],
        ),
      ),
    );
  }
}
