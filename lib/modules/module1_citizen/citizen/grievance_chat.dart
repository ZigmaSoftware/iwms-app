import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iwms_citizen_app/modules/module1_citizen/citizen/theme/citizen_pattern_background.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/theme/citizen_theme.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:iwms_citizen_app/data/models/grievance_ticket_model.dart';
import 'package:iwms_citizen_app/data/repositories/citizen_grievance_repository.dart';

/// Conversational grievance assistant for citizens.
/// Walks the citizen through category → sub-type → (location) → description,
/// then raises a real ticket on the backend and shows the ticket number.
class GrievanceChatScreen extends StatefulWidget {
  const GrievanceChatScreen({super.key});

  @override
  State<GrievanceChatScreen> createState() => _GrievanceChatScreenState();
}

enum _Stage {
  loading,
  menu,
  pickCategory,
  pickSubcategory,
  askLocation,
  askDescription,
  submitting,
  done,
}

class _Msg {
  final bool isUser;
  final String text;
  _Msg(this.isUser, this.text);
}

class _Reply {
  final String label;
  final VoidCallback onTap;
  _Reply(this.label, this.onTap);
}

class _GrievanceChatScreenState extends State<GrievanceChatScreen> {
  final _repo = CitizenGrievanceRepository();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<_Msg> _messages = [];
  List<_Reply> _replies = [];
  _Stage _stage = _Stage.loading;
  bool _typing = false;

  GrievanceMeta? _meta;
  GrievanceCategoryOption? _category;
  GrievanceSubcategoryOption? _subcategory;
  String? _location;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    _bot("👋 Hello! I'm here to help you raise a grievance about waste "
        "collection, bins, spillage, billing and more.");
    try {
      _meta = await _repo.fetchMeta();
    } catch (_) {
      _meta = const GrievanceMeta();
    }
    _showMenu();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _bot(String text) {
    setState(() => _messages.add(_Msg(false, text)));
    _scrollToBottom();
  }

  void _user(String text) {
    setState(() => _messages.add(_Msg(true, text)));
    _scrollToBottom();
  }

  Future<void> _botTyping(String text, {int ms = 450}) async {
    setState(() => _typing = true);
    await Future.delayed(Duration(milliseconds: ms));
    if (!mounted) return;
    setState(() => _typing = false);
    _bot(text);
  }

  void _setReplies(List<_Reply> r) {
    setState(() => _replies = r);
    _scrollToBottom();
  }

  // ---------------- conversation ----------------
  void _showMenu() {
    _stage = _Stage.menu;
    _setReplies([
      _Reply('📝 Raise a grievance', _startRaise),
      _Reply('🔍 Check my tickets', _goStatus),
    ]);
  }

  Future<void> _startRaise() async {
    _user('Raise a grievance');
    _setReplies([]);
    final cats = _meta?.categories ?? const [];
    if (cats.isEmpty) {
      await _botTyping('Sorry, no grievance categories are configured yet. '
          'Please try again later.');
      _showMenu();
      return;
    }
    await _botTyping('What is your grievance about?');
    _stage = _Stage.pickCategory;
    _setReplies([
      for (final c in cats) _Reply(c.name, () => _pickCategory(c)),
    ]);
  }

  Future<void> _pickCategory(GrievanceCategoryOption c) async {
    _user(c.name);
    _category = c;
    _subcategory = null;
    _location = null;
    _setReplies([]);
    final subs = _meta?.subFor(c.uniqueId) ?? const [];
    if (subs.isNotEmpty) {
      await _botTyping('Got it — ${c.name}. Which of these fits best?');
      _stage = _Stage.pickSubcategory;
      _setReplies([
        for (final s in subs) _Reply(s.name, () => _pickSubcategory(s)),
        _Reply('Not sure / skip', () => _pickSubcategory(null)),
      ]);
    } else {
      _afterSubcategory();
    }
  }

  Future<void> _pickSubcategory(GrievanceSubcategoryOption? s) async {
    _user(s?.name ?? 'Skip');
    _subcategory = s;
    _setReplies([]);
    _afterSubcategory();
  }

  Future<void> _afterSubcategory() async {
    if (_category?.requiresLocation == true) {
      _stage = _Stage.askLocation;
      await _botTyping('📍 Where is the issue? (area, street or landmark)');
    } else {
      _stage = _Stage.askDescription;
      await _botTyping('📝 Please describe the issue in a sentence or two.');
    }
  }

  Future<void> _submit(String description) async {
    _stage = _Stage.submitting;
    await _botTyping('⏳ Registering your grievance…', ms: 400);
    try {
      final ticket = await _repo.createTicket(
        categoryId: _category!.uniqueId,
        subcategoryId: _subcategory?.uniqueId,
        priorityId: _category!.defaultPriority,
        description: description,
        locationText: _location,
      );
      await _botTyping(
        '✅ Grievance registered!\n\n'
        '🎟️ Ticket: ${ticket.ticketNo}\n'
        '📂 ${ticket.categoryName ?? _category!.name}'
        '${ticket.subcategoryName != null ? ' › ${ticket.subcategoryName}' : ''}\n'
        '⚡ Priority: ${ticket.priorityCode ?? '-'}\n'
        '🏷️ Status: ${ticket.statusName ?? 'Submitted'}\n'
        '👥 Assigned to: ${ticket.assignedTeamName ?? 'Grievance Desk'}\n\n'
        'You can track progress any time from "Check my tickets".',
        ms: 600,
      );
      _stage = _Stage.done;
      _setReplies([
        _Reply('🔍 Track this ticket', () => _goTicket(ticket.uniqueId)),
        _Reply('📝 Raise another', _startRaise),
      ]);
    } catch (e) {
      await _botTyping('❌ Sorry, I could not register the grievance. '
          'Please try again.');
      _stage = _Stage.done;
      _setReplies([_Reply('🔁 Try again', _startRaise)]);
    }
  }

  void _goStatus() {
    _user('Check my tickets');
    context.push(AppRoutePaths.citizenGrievanceStatus);
    _showMenu();
  }

  void _goTicket(String id) {
    context.push('${AppRoutePaths.citizenGrievanceStatus}?ticket=$id');
  }

  // ---------------- input ----------------
  void _handleSend() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    if (_stage == _Stage.askLocation) {
      _user(text);
      _location = text;
      _stage = _Stage.askDescription;
      _botTyping('Thanks. 📝 Now please describe the issue.');
    } else if (_stage == _Stage.askDescription) {
      _user(text);
      _submit(text);
    } else {
      // free text outside a prompt → nudge to use options
      _user(text);
      _botTyping('Please pick an option below 👇');
      if (_stage == _Stage.menu) _showMenu();
    }
  }

  bool get _inputEnabled =>
      _stage == _Stage.askLocation || _stage == _Stage.askDescription;

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: CitizenColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Grievance Assistant'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(AppRoutePaths.citizenGrievanceStatus),
            icon: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
            label: const Text('Status', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: CitizenPatternBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  children: [
                    for (final m in _messages) _bubble(theme, m),
                    if (_typing) _typingBubble(theme),
                    if (_replies.isNotEmpty) _replyChips(),
                  ],
                ),
              ),
              const Divider(height: 1),
              _composer(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(ThemeData theme, _Msg m) {
    final bg = m.isUser
        ? CitizenColors.primary.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(m.isUser ? 18 : 4),
            bottomRight: Radius.circular(m.isUser ? 4 : 18),
          ),
        ),
        child: Text(m.text, style: theme.textTheme.bodyMedium),
      ),
    );
  }

  Widget _typingBubble(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 34,
          child: Text('•••', style: TextStyle(letterSpacing: 2)),
        ),
      ),
    );
  }

  Widget _replyChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in _replies)
            ActionChip(
              label: Text(r.label),
              onPressed: r.onTap,
              backgroundColor: Colors.white,
              side: BorderSide(color: CitizenColors.primary.withValues(alpha: 0.4)),
              labelStyle: TextStyle(
                color: CitizenColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _composer(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: _inputEnabled,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _inputEnabled
                    ? 'Type your answer…'
                    : 'Pick an option above',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _inputEnabled ? _handleSend : null,
            style: FilledButton.styleFrom(
              backgroundColor: CitizenColors.primary,
              padding: const EdgeInsets.all(14),
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
