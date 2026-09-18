import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/chat_models.dart';
import '../shell/shell_controller.dart';
import 'chat_controller.dart';
import 'widgets/approval_bar.dart';
import 'widgets/chat_input.dart';
import 'widgets/empty_state.dart';
import 'widgets/message_bubble.dart';
import 'widgets/mode_switcher.dart';
import 'widgets/thinking_indicator.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final showMenu = MediaQuery.of(context).size.width < 840;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(showMenu: showMenu),
            const Expanded(child: _MessageList()),
            const ApprovalBar(),
            const ThinkingIndicator(),
            const ChatInput(),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showMenu});

  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => context.read<ShellController>().openDrawer(),
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          const ModeSwitcher(),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList();

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final ScrollController _controller = ScrollController();
  int _count = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Keeps the latest turn in view without stealing scroll control from the
  /// user: only a change in message count triggers a jump.
  void _jumpToBottom(int count) {
    if (count == _count) return;
    _count = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, chat, _) {
        final streaming = chat.streamingText.isNotEmpty;
        final count = chat.messages.length + (streaming ? 1 : 0);

        if (chat.messages.isEmpty && !streaming) {
          return ChatEmptyState(error: chat.error);
        }
        _jumpToBottom(count);

        return ListView.builder(
          controller: _controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: count,
          itemBuilder: (context, index) {
            if (streaming && index == chat.messages.length) {
              return MessageBubble(
                message: ChatMessage(
                  id: '__streaming__',
                  role: ChatRole.assistant,
                  text: chat.streamingText,
                  createdAt: DateTime.now(),
                ),
                streaming: true,
              );
            }
            return MessageBubble(message: chat.messages[index]);
          },
        );
      },
    );
  }
}
