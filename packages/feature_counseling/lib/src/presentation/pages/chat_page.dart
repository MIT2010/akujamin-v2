import 'package:authentication/authentication.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/chat_message.dart';
import '../cubit/chat_cubit.dart';
import '../cubit/chat_state.dart';

/// Migrated from the old app's `counseling/presentation/pages/
/// chat_page.dart` — a single realtime chat thread with a psychologist.
///
/// "Mulai Tes Kedua" (shown once the old app's session ends) isn't wired
/// to a real destination here — `test` isn't migrated yet. Same explicit-
/// decision treatment as `feature_history`'s placeholder buttons:
/// `AppDialog.info` says so, rather than a dead button or a route that
/// 404s.
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final code = GoRouterState.of(context).pathParameters['code']!;
    final psychologist =
        GoRouterState.of(context).uri.queryParameters['psychologist'] ?? '';

    return BlocProvider(
      create: (_) => getIt<ChatCubit>()..getMessages(code),
      child: ChatView(psychologist: psychologist),
    );
  }
}

/// Split from [ChatPage] (left un-exported from the barrel) so widget
/// tests can drive it directly with a fake `ChatCubit` via
/// `BlocProvider.value` — same pattern as every other feature's page.
class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.psychologist});

  final String psychologist;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.psychologist)),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) => switch (state) {
                ChatInitial() || ChatLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                ChatLoadFailed(:final failure) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(failure.message),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Coba lagi',
                          onPressed: () {
                            final code = GoRouterState.of(
                              context,
                            ).pathParameters['code']!;
                            context.read<ChatCubit>().getMessages(code);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                ChatLoaded(:final messages) => ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: messages.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) => _MessageBubble(
                    message: messages[messages.length - 1 - index],
                  ),
                ),
              },
            ),
          ),
          BlocSelector<ChatCubit, ChatState, bool>(
            selector: (state) => state is ChatLoaded && state.ended,
            builder: (context, ended) {
              if (ended) return const _EndedBanner();
              return _MessageInput(controller: _controller);
            },
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: AppSpacing.xs,
          children: [
            Expanded(
              child: AppTextField(label: 'Tulis pesan', controller: controller),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () {
                final text = controller.text;
                if (text.trim().isEmpty) return;
                final userId = switch (context.read<AuthCubit>().state) {
                  AuthAuthenticated(:final user) => user.id,
                  _ => null,
                };
                if (userId == null) return;
                context.read<ChatCubit>().sendMessage(
                  message: text,
                  senderId: userId,
                );
                controller.clear();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EndedBanner extends StatelessWidget {
  const _EndedBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            const Text(
              'Konseling Selesai',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'Sesi konseling telah berakhir. Kamu bisa langsung melakukan '
              'tes kedua.',
            ),
            AppButton(
              label: 'Mulai Tes Kedua',
              onPressed: () => AppDialog.info(
                context,
                title: 'Belum tersedia',
                message: 'Fitur ini belum tersedia. Coba lagi nanti.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  bool get _isMine => message.senderType == 'participant';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: _isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: _isMine
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message.message),
                if (_isMine) ...[
                  const SizedBox(height: 2),
                  Text(
                    // Deliberately honest — only "mengirim..."/"terkirim",
                    // never a fabricated delivered/read receipt. See
                    // ChatMessage's doc comment for why.
                    switch (message.status) {
                      ChatMessageStatus.pending => 'Mengirim...',
                      ChatMessageStatus.sent => 'Terkirim',
                      ChatMessageStatus.failed => 'Gagal terkirim',
                    },
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
