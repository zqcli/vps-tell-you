import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'ledger_controller.dart';

/// The write committed, but the visible snapshot is stale until a read succeeds.
class RefreshFailureNotice extends StatelessWidget {
  const RefreshFailureNotice({super.key, required this.controller});
  final LedgerController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('写入已保存，显示内容暂未更新'),
          const InfoNote('请先重新读取本地台账，再继续修改。不要重复提交，原数据不会被清除。'),
          TextButton(
            onPressed: controller.busy
                ? null
                : () async {
                    try {
                      await controller.refresh();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('读取仍未完成，已保存的改动保留。请稍后重新读取。'),
                          ),
                        );
                      }
                    }
                  },
            child: const Text('重新读取'),
          ),
        ],
      ),
    ),
  );
}
