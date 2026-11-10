import 'package:flutter/material.dart';

import '../api/endpoints.dart';
import '../common/common.dart';

/// 연결 주소 수정 창 (3-6 > 연결 주소). 저장하거나 기본값으로 되돌리면 true를 돌려준다.
Future<bool> showConnectionSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ConnectionSheet(),
  );
  return changed ?? false;
}

class _ConnectionSheet extends StatefulWidget {
  const _ConnectionSheet();

  @override
  State<_ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<_ConnectionSheet> {
  final _server = TextEditingController(text: Endpoints.serverUrl);
  final _board = TextEditingController(text: Endpoints.boardWsUrl);
  String? _serverError;
  String? _boardError;

  @override
  void dispose() {
    _server.dispose();
    _board.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _serverError = Endpoints.checkServer(_server.text);
      _boardError = Endpoints.checkBoard(_board.text);
    });
    if (_serverError != null || _boardError != null) return;
    final navigator = Navigator.of(context);
    await Endpoints.save(server: _server.text, board: _board.text);
    navigator.pop(true);
  }

  Future<void> _reset() async {
    final navigator = Navigator.of(context);
    await Endpoints.resetToDefault();
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppTextStyles.caption12.copyWith(
      color: AppColors.textSecondary,
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.s12,
            AppSpacing.screenHorizontal,
            AppSpacing.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetHandle()),
              const SizedBox(height: AppSpacing.s20),
              Text('연결 주소', style: AppTextStyles.subtitle18),
              const SizedBox(height: AppSpacing.s4),
              Text('시연 장소의 IP에 맞춰 바꿔요. 저장하면 시작 화면부터 다시 연결해요.', style: secondary),
              const SizedBox(height: AppSpacing.s20),
              Text('서버', style: AppTextStyles.label14),
              const SizedBox(height: AppSpacing.s8),
              OngiTextField(
                controller: _server,
                hintText: 'http://192.168.0.20:8000',
                errorText: _serverError,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text('온기 스피커(보드)', style: AppTextStyles.label14),
              const SizedBox(height: AppSpacing.s8),
              OngiTextField(
                controller: _board,
                hintText: 'ws://192.168.0.10:8765',
                errorText: _boardError,
              ),
              const SizedBox(height: AppSpacing.s24),
              OngiButton(label: '저장하기', onPressed: _save),
              const SizedBox(height: 10),
              OngiButton.secondary(label: '기본값으로 되돌리기', onPressed: _reset),
            ],
          ),
        ),
      ),
    );
  }
}
