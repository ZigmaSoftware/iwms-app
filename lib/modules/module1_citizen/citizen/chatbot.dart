import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/router/app_router.dart';

const List<String> _primaryQuickActions = [
  'Report issue',
  'Schedule pickup',
  'Payments',
  'Pickup status',
  'Waste tips',
  'Collector info',
  'Community alerts',
  'Feedback',
];

class ChatMessage {
  final String sender; // 'user' | 'bot'
  final String? text;
  final List<String>? options; // quick reply chips
  final bool typing;
  ChatMessage({
    required this.sender,
    this.text,
    this.options,
    this.typing = false,
  });
}

class GrievanceChatScreen extends StatefulWidget {
  const GrievanceChatScreen({super.key});

  @override
  State<GrievanceChatScreen> createState() => _GrievanceChatScreenState();
}

class _GrievanceChatScreenState extends State<GrievanceChatScreen> {
  final List<ChatMessage> messages = [
    ChatMessage(
      sender: 'bot',
      text:
          '👋 Hi! I’m your Waste Collection Assistant. I can help with complaints, pickups, bins, payments, or feedback.',
    ),
    ChatMessage(
      sender: 'bot',
      options: _primaryQuickActions,
    ),
  ];

  final TextEditingController _controller = TextEditingController();

  // Flow/context state
  String _flow = 'idle'; // idle|issue|schedule|bin|payments|feedback
  String _context = 'idle'; // awaiting_* or idle
  final Map<String, String> _form = {};
  int _ticketSeq = 1001;
  bool _inputEnabled = false;

  void _sendMessage([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    if (preset == null && !_inputEnabled) return;

    setState(() {
      if (preset != null) {
        // User clicked a quick action → typing stays off until bot asks for input
        _inputEnabled = false;
        _controller.clear();
      }

      messages.add(ChatMessage(sender: 'user', text: text));
      if (preset == null) {
        _controller.clear();
      }
    });
    _botResponse(text);
  }

  Future<void> _botResponse(String userInput) async {
    setState(() => messages.add(ChatMessage(sender: 'bot', typing: true)));
    await Future.delayed(const Duration(milliseconds: 650));

    final normalized = userInput.toLowerCase();

    // Global resets
    if (_containsAny(normalized, ['menu', 'main menu', 'home', 'go back'])) {
      _flow = 'idle';
      _context = 'idle';
      _form.clear();
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'What would you like to do?',
          options: _primaryQuickActions,
        ),
      );
      _disableInput();
      return;
    }

    // Handle awaited inputs first
    if (_context.startsWith('awaiting_')) {
      if (_context == 'awaiting_address') {
        _form['address'] = userInput;
        if (_flow == 'issue') {
          _context = 'awaiting_description';
          _replaceTypingWith(
            ChatMessage(
              sender: 'bot',
              text:
                  'Please describe the issue (optional). Type "skip" to continue.',
            ),
          );
          return;
        }
        if (_flow == 'schedule') {
          _context = 'awaiting_datetime';
          _replaceTypingWith(
            ChatMessage(
              sender: 'bot',
              text: 'Preferred date/time for pickup? (e.g., 18 Nov, 10–12am)',
            ),
          );
          return;
        }
        if (_flow == 'bin') {
          _context = 'awaiting_bin_size';
          _replaceTypingWith(
            ChatMessage(
              sender: 'bot',
              text: 'What bin size do you need?',
              options: const ['Small', 'Medium', 'Large', 'Go back'],
            ),
          );
          return;
        }
        if (_flow == 'payments') {
          _context = 'awaiting_account_id';
          _replaceTypingWith(
            ChatMessage(
              sender: 'bot',
              text: 'Please share your Account ID/Number.',
            ),
          );
          return;
        }
      } else if (_context == 'awaiting_description') {
        _form['description'] = normalized == 'skip' ? '' : userInput;
        final id = _nextId('ISS');
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text:
                '✅ Complaint submitted (Ticket $id).\nType: ${_form['issue_type']}\nAddress: ${_form['address']}\nWe’ll update you soon.',
            options: const ['Track request', 'New request', 'Main menu'],
          ),
        );
        _resetFlow();
        return;
      } else if (_context == 'awaiting_datetime') {
        _form['datetime'] = userInput;
        final id = _nextId('SCH');
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text:
                '📅 Pickup scheduled (Ref $id).\nType: ${_form['pickup_type']}\nWhen: ${_form['datetime']}\nAddress: ${_form['address']}',
            options: const ['Schedule another', 'Main menu'],
          ),
        );
        _resetFlow();
        return;
      } else if (_context == 'awaiting_bin_size') {
        final size = _matchOne(userInput, ['small', 'medium', 'large']);
        if (size == null) {
          _replaceTypingWith(
            ChatMessage(
              sender: 'bot',
              text: 'Please choose a size.',
              options: const ['Small', 'Medium', 'Large', 'Go back'],
            ),
          );
          return;
        }
        _form['bin_size'] = _capitalize(size);
        final id = _nextId('BIN');
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text:
                '🗑️ Bin request submitted (Ref $id).\nType: ${_form['bin_type']}\nSize: ${_form['bin_size']}\nAddress: ${_form['address']}',
            options: const ['New request', 'Main menu'],
          ),
        );
        _resetFlow();
        return;
      } else if (_context == 'awaiting_account_id') {
        _form['account'] = userInput;
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text:
                '💳 Account ${_form['account']} found.\nCurrent bill: ₹320 due 20 Nov.\nNeed a receipt or have payment issues?',
            options: const ['Get receipt', 'Payment issue', 'Main menu'],
          ),
        );
        _context = 'idle';
        return;
      } else if (_context == 'awaiting_feedback') {
        final id = _nextId('FDB');
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text:
                '🙏 Thanks for your feedback! (Ref $id)\nWe appreciate you helping us improve.',
            options: const ['Main menu'],
          ),
        );
        _resetFlow();
        return;
      } else if (_context == 'awaiting_track_id') {
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text:
                '🔎 Status for ${userInput.toUpperCase()}: In progress. We’ll notify you once resolved.',
            options: const ['Main menu'],
          ),
        );
        _resetFlow();
        return;
      }
    }

    if (_containsAny(
        normalized, ['pickup status', 'track pickup', 'pickup tracking'])) {
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text:
              'Your next pickup is scheduled for tomorrow morning. Reply with "Track request" if you need the ticket ID or "Main menu" for more options.',
          options: const ['Track request', 'Main menu'],
        ),
      );
      return;
    }

    if (_containsAny(
        normalized, ['waste tips', 'recycling tips', 'waste best practices'])) {
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text:
              'Tip of the day: Rinse recyclables, bundle loose items, and place them outside before 7am. Small habits keep the city tidy!',
          options: const ['Main menu'],
        ),
      );
      return;
    }

    if (_containsAny(normalized,
        ['collector info', 'collector details', 'collector contact'])) {
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text:
              'Your assigned collector is Ramesh (ID: C-17). He operates on the north-south corridor and is reachable via the in-app call button. Need anything else?',
          options: const ['Main menu'],
        ),
      );
      return;
    }

    if (_containsAny(
        normalized, ['community alerts', 'service alerts', 'city alerts'])) {
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text:
              'Alert: Due to the city marathon on Sunday, pickups in the old town area will run two hours earlier. Keep bins accessible by 5am.',
          options: const ['Main menu'],
        ),
      );
      return;
    }

    // Route by high-level intent or quick actions
    if (_containsAny(normalized, [
      'report issue',
      'complaint',
      'missed',
      'spill',
      'overflow',
      'broken bin',
      'staff'
    ])) {
      _flow = 'issue';
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Select the issue to report:',
          options: const [
            'Missed pickup',
            'Spillage/Overflow',
            'Broken bin',
            'Staff behavior',
            'Other',
            'Main menu'
          ],
        ),
      );
      return;
    }

    if (_containsAny(normalized,
        ['schedule pickup', 'pickup', 'bulk', 'garden', 'e-waste', 'ewaste'])) {
      _flow = 'schedule';
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'What type of pickup do you need?',
          options: const ['Bulk waste', 'Garden waste', 'E-waste', 'Main menu'],
        ),
      );
      return;
    }

    if (_containsAny(normalized, ['bin request', 'new bin', 'replace bin'])) {
      _flow = 'bin';
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Choose a bin service:',
          options: const ['New bin', 'Replace damaged bin', 'Main menu'],
        ),
      );
      return;
    }

    if (_containsAny(normalized, ['payment', 'bill', 'receipt'])) {
      _flow = 'payments';
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Payments help — choose an option:',
          options: const [
            'View current bill',
            'Payment issue',
            'Get receipt',
            'Main menu'
          ],
        ),
      );
      return;
    }

    if (_containsAny(normalized, ['feedback', 'suggestion'])) {
      _flow = 'feedback';
      _context = 'awaiting_feedback';
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'We’d love your feedback! Type your message and send.',
        ),
      );
      return;
    }

    // Sub-intents inside flows (selected via chips or typed)
    if (_flow == 'issue') {
      final issue = _matchOne(
        normalized,
        [
          'missed pickup',
          'spillage/overflow',
          'broken bin',
          'staff behavior',
          'other'
        ],
      );
      if (issue != null) {
        _form['issue_type'] = _pretty(issue);
        _context = 'awaiting_address';
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text: 'Please share the address for this issue.',
          ),
        );
        return;
      }
      if (_containsAny(normalized, ['track request'])) {
        _context = 'awaiting_track_id';
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text: 'Please provide your Ticket/Ref ID.',
          ),
        );
        return;
      }
    }

    if (_flow == 'schedule') {
      final type = _matchOne(
        normalized,
        ['bulk waste', 'garden waste', 'e-waste', 'ewaste'],
      );
      if (type != null) {
        _form['pickup_type'] = _pretty(type == 'ewaste' ? 'e-waste' : type);
        _context = 'awaiting_address';
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text: 'Great. What’s the pickup address?',
          ),
        );
        return;
      }
    }

    if (_flow == 'bin') {
      final kind = _matchOne(normalized, ['new bin', 'replace damaged bin']);
      if (kind != null) {
        _form['bin_type'] = _pretty(kind);
        _context = 'awaiting_address';
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text: 'Please share the delivery address.',
          ),
        );
        return;
      }
    }

    if (_flow == 'payments') {
      if (_containsAny(normalized, ['view current bill'])) {
        _context = 'awaiting_account_id';
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text: 'Please share your Account ID/Number.',
          ),
        );
        return;
      }
      if (_containsAny(normalized, ['get receipt'])) {
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text:
                '📨 Receipt sent to your registered email. Need anything else?',
            options: const ['Main menu'],
          ),
        );
        _resetFlow();
        return;
      }
      if (_containsAny(normalized, ['payment issue', 'failed', 'declined'])) {
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text:
                'If an amount was debited, it auto-refunds in 3–5 days. For urgent help, reply with "View current bill" or "Main menu".',
            options: const ['View current bill', 'Main menu'],
          ),
        );
        return;
      }
    }

    if (_containsAny(normalized, ['new request', 'schedule another'])) {
      _flow = 'idle';
      _context = 'idle';
      _form.clear();
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'What would you like to do next?',
          options: _primaryQuickActions,
        ),
      );
      _disableInput();
      return;
    }

    if (_containsAny(normalized, ['track request'])) {
      _context = 'awaiting_track_id';
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Please provide your Ticket/Ref ID.',
        ),
      );
      return;
    }

    // Fallback
    final fallbackOptions =
        _context.startsWith('awaiting_') ? null : _primaryQuickActions;
    _replaceTypingWith(
      ChatMessage(
        sender: 'bot',
        text: 'I didn’t catch that. Try a quick action below.',
        options: fallbackOptions,
      ),
    );
    if (fallbackOptions != null && fallbackOptions.isNotEmpty) {
      _disableInput();
    }
    _flow = 'idle';
    _context = 'idle';
  }

  // Helpers
  bool _containsAny(String text, List<String> keys) =>
      keys.any((k) => text.contains(k));

  String? _matchOne(String text, List<String> keys) {
    for (final k in keys) {
      if (text.contains(k)) return k;
    }
    return null;
  }

  void _replaceTypingWith(ChatMessage next) {
    final idx = messages.lastIndexWhere((m) => m.typing);
    final hasOptions = next.options?.isNotEmpty ?? false;

    setState(() {
      if (idx != -1) {
        messages[idx] = next;
      } else {
        messages.add(next);
      }

      // Disable typing only while options are being shown
      if (hasOptions) {
        _inputEnabled = false;
        _controller.clear();
      } else {
        // Enable typing only if bot message expects manual input
        final awaitingInput = _context.startsWith('awaiting_');
        _inputEnabled = awaitingInput;
      }
    });
  }

  void _disableInput() {
    setState(() {
      _inputEnabled = false;
      _controller.clear();
    });
  }

  void _resetFlow() {
    _flow = 'idle';
    _context = 'idle';
    _form.clear();
  }

  String _nextId(String prefix) => '$prefix${_ticketSeq++}';
  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  String _pretty(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final brand = Colors.green;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutePaths.citizenHome),
        ),
        title: const Text("Assistant 🤖"),
        backgroundColor: Colors.green,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isUser = msg.sender == 'user';

                  if (msg.typing) {
                    return _TypingBubble(color: Colors.grey[300]!);
                  }

                  final showOptions = msg.options != null &&
                      msg.options!.isNotEmpty &&
                      index == messages.length - 1;
                  final options = msg.options ?? const [];

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.text != null && msg.text!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? brand.withOpacity(0.12)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(msg.text ?? ''),
                          ),
                        if (showOptions)
                          Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(options.length,
                                    (optionIndex) {
                                  final option = options[optionIndex];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: optionIndex == options.length - 1
                                          ? 0
                                          : 8,
                                    ),
                                    child: ActionChip(
                                      label: Text(option),
                                      onPressed: () => _sendMessage(option),
                                      backgroundColor: Colors.grey[200],
                                      shape: StadiumBorder(
                                        side: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: _inputEnabled,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (_inputEnabled) _sendMessage();
                      },
                      decoration: InputDecoration(
                        fillColor: Colors.transparent,
                        hintText: _inputEnabled
                            ? "Type your message..."
                            : "Choose an option to start",
                        // border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: _inputEnabled ? Colors.green : Colors.grey,
                    ),
                    onPressed: _inputEnabled ? _sendMessage : null,
                  ),
                ],
              ),
            ),
         
         
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  final Color color;
  const _TypingBubble({required this.color});
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final v = (1 + (i * 0.2) + _c.value) % 1.0;
                final scale = 0.6 + 0.4 * (v < 0.5 ? v * 2 : (1 - v) * 2);
                return Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                  child: Transform.scale(
                    scale: scale,
                    child: const CircleAvatar(
                        radius: 3, backgroundColor: Colors.grey),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
