import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/theme/liquid_glass.dart';
import '../../../core/models/chat_models.dart';

/// A live tile for one tool invocation: spinner while it runs, green when it
/// lands, red when it fails or is denied. Arguments and output are one tap away.
class ToolCallCard extends StatefulWidget {
  const ToolCallCard({super.key, required this.call, this.result});

  final ToolCall call;
  final ToolResult? result;

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final result = widget.result;
    final running = result == null;

    return GlassCard(
      alpha: 0.05,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                _StatusIcon(running: running, error: result?.isError ?? false),
                const SizedBox(width: 10),
                Text(
                  call.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (call.args.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _argSummary(call.args),
                      style: const TextStyle(color: kSecondaryText, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ] else
                  const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: kSecondaryText,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            if (call.args.isNotEmpty)
              _codeBlock('Arguments', const JsonEncoder.withIndent('  ').convert(call.args)),
            if (result != null) ...[
              const SizedBox(height: 8),
              _codeBlock('Output', result.content),
            ],
          ],
        ],
      ),
    );
  }

  String _argSummary(Map<String, dynamic> args) {
    final entry = args.entries.first;
    return '${entry.key}: ${entry.value}';
  }

  Widget _codeBlock(String label, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: kSecondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: glassFill(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: SelectableText(
              body,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: kPrimaryText,
                  height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.running, required this.error});

  final bool running;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (running) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.8, color: kAccent),
      );
    }
    return Icon(
      error ? Icons.close_rounded : Icons.check_rounded,
      size: 16,
      color: error ? kDanger : kSuccess,
    );
  }
}
