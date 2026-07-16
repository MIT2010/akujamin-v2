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
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final code = GoRouterState.of(context).pathParameters['code']!;
    final psychologist =
        GoRouterState.of(context).uri.queryParameters['psychologist'] ?? '';

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ChatCubit>()..getMessages(code)),
        BlocProvider.value(value: getIt<AuthCubit>()),
      ],
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
            Builder(
              builder: (context) {
                return IconButton(
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
                );
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
              // Real navigation now that `test` is migrated — same
              // route-string pattern feature_history's own "Lanjutkan
              // Tes" button already uses (§5, no direct package
              // dependency on feature_test). Found stale during the
              // 2026-07-14 GAPS.md compilation: this used to say "test
              // isn't migrated yet", which stopped being true once `test`
              // shipped — the placeholder was never revisited.
              onPressed: () {
                final code = GoRouterState.of(context).pathParameters['code']!;
                context.push('/test/$code');
              },
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
