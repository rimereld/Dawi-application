import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_scaffold_background.dart';

const _suggestedQuestions = [
  'Explain this document to me.',
  'What does this medical term mean?',
  'Summarize my latest analyses.',
  'What are my next appointments?',
  'Remind me about my medications.',
  'Prepare questions for my doctor.',
];

/// Conversational "AI Health Assistant" (spec section 20). If [documentId]
/// is provided, every reply is grounded in that document; otherwise the
/// backend grounds replies in a summary of active medications and
/// upcoming appointments.
class AiAssistantScreen extends StatefulWidget {
  final String? documentId;
  const AiAssistantScreen({super.key, this.documentId});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage(this.text, {this.isUser = false});
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await apiService.getChatHistory(documentId: widget.documentId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(history.map((m) => _ChatMessage(m['content'] ?? '', isUser: m['role'] == 'user')));
        if (_messages.isEmpty) {
          _messages.add(const _ChatMessage('Hello! How can I help you today?'));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.add(const _ChatMessage('Hello! How can I help you today?')));
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _send([String? presetText]) async {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text, isUser: true));
      _inputController.clear();
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final reply = await apiService.sendChatMessage(message: text, documentId: widget.documentId);
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(reply)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage("The AI assistant is temporarily unavailable: ${e.message}")));
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientScaffoldBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(children: [
                  const CircleAvatar(
                      radius: 16, backgroundColor: AppColors.primaryLight, child: Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.primary)),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Health Assistant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ]),
              ),
              if (_messages.length <= 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedQuestions
                        .map((q) => ActionChip(label: Text(q, style: const TextStyle(fontSize: 12)), onPressed: () => _send(q)))
                        .toList(),
                  ),
                ),
              Expanded(
                child: _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _messages.length + (_isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) return const _TypingIndicator();
                          return _MessageBubble(message: _messages[index]);
                        },
                      ),
              ),
              _ChatInputBar(controller: _inputController, onSend: () => _send(), enabled: !_isSending),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isUser ? AppColors.primary : Colors.white;
    final textColor = message.isUser ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
        ),
        child: Text(message.text, style: TextStyle(color: textColor, fontSize: 14.5, height: 1.35)),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  const _ChatInputBar({required this.controller, required this.onSend, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(hintText: 'Ask your Health Assistant...', fillColor: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: enabled ? onSend : null),
      ]),
    );
  }
}
