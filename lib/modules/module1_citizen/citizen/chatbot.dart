import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:iwms_citizen_app/core/network/auth_dio.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // ============================================================
  // Chat state 
  // ============================================================
  final List<ChatMessage> messages = [
    ChatMessage(
      sender: 'bot',
      text:
          '👋 Hi! I’m your Waste Collection Assistant. I can help with complaints, pickups, bins, payments, or feedback.',
    ),
    ChatMessage(
      sender: 'bot',
      text: 'Loading categories…',
      typing: true,
    ),
  ];

  final TextEditingController _controller = TextEditingController();

  // ============================================================
  // Backend categories
  // ============================================================
  List<dynamic> _mainCategories = [];
  List<dynamic> _subCategories = [];
  List<dynamic> _activeSubCategories = [];

  bool _categoriesLoaded = false;
  bool _loadingCategories = false;

  // ============================================================
  // Flow/context state
  // ============================================================
  String _flow = 'dynamic_issue'; // only dynamic flow
  String _context =
      'awaiting_main_category'; // awaiting_main_category|awaiting_sub_category|awaiting_details|awaiting_address
  final Map<String, String> _form = {};
  int _ticketSeq = 1001;

  bool _inputEnabled = false;
  bool _awaitingConfirmation = false;

  // ============================================================
  // INIT
  // ============================================================
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // ============================================================
  // API CALLS (same endpoints you gave)
  // ============================================================
  Future<List<dynamic>> _decodeToList(String body) async {
    final decoded = jsonDecode(body);

    if (decoded is List) return decoded;

    if (decoded is Map) {
      if (decoded['results'] is List) return decoded['results'];
      if (decoded['data'] is List) return decoded['data'];
      if (decoded['items'] is List) return decoded['items'];
    }

    throw Exception('Unexpected JSON format: ${decoded.runtimeType}');
  }

  Future<List<dynamic>> fetchMainCategories() async {
    final res = await http.get(
      Uri.parse('http://192.168.4.97:5000/api/mobile/main-category/'),
      headers: await authHeader(),
    );

    debugPrint('Main status: ${res.statusCode}');
    debugPrint('Main body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    return _decodeToList(res.body);
  }

  Future<List<dynamic>> fetchSubCategories() async {
    final res = await http.get(
      Uri.parse('http://192.168.4.97:5000/api/mobile/sub-category/'),
      headers: await authHeader(),
    );

    debugPrint('Sub status: ${res.statusCode}');
    debugPrint('Sub body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    return _decodeToList(res.body);
  }

  Future<void> _loadCategories() async {
    if (_loadingCategories) return;
    setState(() => _loadingCategories = true);

    try {
      final results = await Future.wait([
        fetchMainCategories(),
        fetchSubCategories(),
      ]);

      _mainCategories = results[0];
      _subCategories = results[1];

      _categoriesLoaded = true;
      _flow = 'dynamic_issue';
      _context = 'awaiting_main_category';
      _activeSubCategories = [];
      _form.clear();

      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Select a category:',
          options: _mainOptions(),
        ),
      );

      _disableInput(); // chip-only for categories
    } catch (e) {
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Unable to load categories.',
          options: const ['Retry'],
        ),
      );
      _disableInput();
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  // ============================================================
  // CONFIRMATION
  // ============================================================
  void _askConfirmation() {
    setState(() {
      _awaitingConfirmation = true;
      _inputEnabled = false;

      messages.add(
        ChatMessage(
          sender: 'bot',
          text: 'Is this your final description?',
          options: const [
            'No (Continue your typing)',
            'Yes, I want to submit now',
          ],
        ),
      );
    });
  }

  void _sendMessage([String? preset]) {
    if (!_inputEnabled && preset == null) return;

    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(ChatMessage(sender: 'user', text: text));
      if (preset == null) _controller.clear();
    });

    // Chips
    if (preset != null) {
      _botResponse(text);
      return;
    }

    // Typed details should go through confirmation
    if (_context == 'awaiting_details') {
      _form['_draft'] = text;
      _askConfirmation();
      return;
    }

    _botResponse(text);
  }

  // ============================================================
  // SUBMIT COMPLAINT TO BACKEND
  // ============================================================
  Future<void> _submitComplaint(String ticketNo) async {
    try {
      // Get customer user_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('authenticated_user') ?? '';
      
      debugPrint('✅ Customer ID retrieved: $customerId');

      
      final body = {
        'contact_no': '', // Auto-filled from customer profile
        'address': _form['address'] ?? '',
        'main_category': _form['main_category_name'] ?? '',
        'sub_category': _form['sub_category_name'] ?? '',
        'category': 'OTHER', // Default category - set based on main_category if needed
        'details': _form['description'] ?? '',
        // 'image': '', // Optional: for image upload later
        'status': 'PROGRESSING',
        'customer': customerId,
        // customer, zone, ward, is_active, is_deleted will be set by backend
      };

      final headers = await authHeader();
      headers['Content-Type'] = 'application/json';
      debugPrint('Request headers: $headers');
      debugPrint("AUTH => ${headers['Authorization']}");

      debugPrint('Request body: $body');

      final res = await http.post(
        Uri.parse('http://192.168.4.97:5000/api/desktop/customers/complaints/'),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint('Complaint submit status: ${res.statusCode}');
      debugPrint('Complaint submit response: ${res.body}');
      debugPrint('Response length: ${res.body.length} bytes');

      if (res.statusCode != 201 && res.statusCode != 200) {
        try {
          final errorBody = jsonDecode(res.body);
          debugPrint('❌ ERROR DETAILS: $errorBody');
        } catch (e) {
          debugPrint('❌ RAW ERROR: ${res.body}');
        }
        debugPrint('Failed to submit complaint');
      } else {
        debugPrint('✅ Complaint submitted successfully');
      }
    } catch (e) {
      debugPrint('Error submitting complaint: $e');
    }
  }

  // ============================================================
  // BOT LOGIC (dynamic only)
  // ============================================================
  Future<void> _botResponse(String userInput) async {
    final normalized = userInput.trim().toLowerCase();

    // ---------- CONFIRMATION HANDLER ----------
    if (_awaitingConfirmation) {
      if (normalized.startsWith('no')) {
        _awaitingConfirmation = false;
        setState(() => _inputEnabled = true);

        _replaceTypingWith(
          ChatMessage(sender: 'bot', text: 'Continue typing.'),
        );
        return;
      }

      if (normalized.startsWith('yes')) {
        _awaitingConfirmation = false;

        final finalText = _form['_draft'] ?? '';
        _form.remove('_draft');

        // store confirmed description
        _form['description'] = finalText;

        _context = 'awaiting_address';
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text: 'Please share the address related to this issue.',
          ),
        );
        return;
      }
    }

    setState(() => messages.add(ChatMessage(sender: 'bot', typing: true)));
    await Future.delayed(const Duration(milliseconds: 650));

    // ---------- Retry ----------
    if (normalized == 'retry') {
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Reloading categories…',
          typing: true,
        ),
      );
      await _loadCategories();
      return;
    }

    // ---------- MAIN MENU ----------
    if (normalized == 'main menu' ||
        normalized == 'menu' ||
        normalized == 'home') {
      _flow = 'dynamic_issue';
      _context = 'awaiting_main_category';
      _form.clear();
      _activeSubCategories = [];

      if (!_categoriesLoaded) {
        _replaceTypingWith(
          ChatMessage(sender: 'bot', text: 'Loading categories…', typing: true),
        );
        await _loadCategories();
        return;
      }

      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Select a category:',
          options: _mainOptions(),
        ),
      );
      _disableInput();
      return;
    }

    // ---------- awaiting_main_category ----------
    if (_context == 'awaiting_main_category') {
      final main = _findMainByName(userInput);
      if (main == null) {
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text: 'Please select a valid category:',
            options: _mainOptions(),
          ),
        );
        _disableInput();
        return;
      }

      final mainId = _safeId(main);
      final mainName = _safeName(main);

      _form['main_category_id'] = mainId;
      _form['main_category_name'] = mainName;

      _activeSubCategories =
          _subCategories.where((s) => _safeMainIdFromSub(s) == mainId).toList();

      if (_activeSubCategories.isEmpty) {
        _context = 'awaiting_details';
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text: 'Please describe the issue in detail.',
          ),
        );
        return;
      }

      _context = 'awaiting_sub_category';
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Select sub-category:',
          options: _subOptions(),
        ),
      );
      _disableInput();
      return;
    }

    // ---------- awaiting_sub_category ----------
    if (_context == 'awaiting_sub_category') {
      final sub = _findSubByName(userInput);
      if (sub == null) {
        _replaceTypingWith(
          ChatMessage(
            sender: 'bot',
            text: 'Please select a valid sub-category:',
            options: _subOptions(),
          ),
        );
        _disableInput();
        return;
      }

      _form['sub_category_id'] = _safeId(sub);
      _form['sub_category_name'] = _safeName(sub);

      _context = 'awaiting_details';
      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: 'Please describe the issue in detail.',
        ),
      );
      return;
    }

    // ---------- awaiting_details (typed) ----------
    if (_context == 'awaiting_details') {
      // should not reach here normally (typed goes to confirmation)
      _form['_draft'] = userInput;
      _askConfirmation();
      return;
    }

    // ---------- awaiting_address ----------
    if (_context == 'awaiting_address') {
      _form['address'] = userInput;

      final ticketNo = _nextId('ISS');

      // Submit to backend
      await _submitComplaint(ticketNo);

      _replaceTypingWith(
        ChatMessage(
          sender: 'bot',
          text: '✅ Complaint submitted (Ticket $ticketNo)\n'
              'Category: ${_form['main_category_name'] ?? '-'}\n'
              'Sub-Category: ${_form['sub_category_name'] ?? '-'}\n'
              'Address: ${_form['address']}\n'
              'Description: ${_form['description'] ?? '-'}',
          options: const ['Main menu'],
        ),
      );

      _disableInput();
      _form.clear();
      _activeSubCategories = [];
      _context = 'awaiting_main_category';
      return;
    }

    // ---------- fallback ----------
    _replaceTypingWith(
      ChatMessage(
        sender: 'bot',
        text: 'Please use the options.',
        options: _context == 'awaiting_main_category'
            ? _mainOptions()
            : _context == 'awaiting_sub_category'
                ? _subOptions()
                : const ['Main menu'],
      ),
    );
    _disableInput();
  }

  // ============================================================
  // Helpers (safe getters; handles Map json OR model objects)
  // ============================================================
  String _safeName(dynamic obj) {
    try {
      if (obj is Map) {
        return (obj['name'] ??
                obj['main_categoryName'] ??
                obj['sub_categoryName'] ??
                obj['main_category_name'] ??
                obj['sub_category_name'] ??
                '')
            .toString();
      }
      return (obj.name ?? obj.mainCategoryName ?? obj.subCategoryName ?? '')
          .toString();
    } catch (_) {
      return '';
    }
  }

  String _safeId(dynamic obj) {
    try {
      if (obj is Map) return (obj['id'] ?? '').toString();
      return (obj.id ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  String _safeMainIdFromSub(dynamic obj) {
    try {
      if (obj is Map) {
        return (obj['mainCategory'] ??
                obj['main_category_id'] ??
                obj['mainCategoryId'] ??
                obj['main_id'] ??
                '')
            .toString();
      }
      return (obj.mainCategory ?? obj.mainCategoryId ?? obj.main_category_id ?? obj.mainId ?? '')
          .toString();
    } catch (_) {
      return '';
    }
  }

  dynamic _findMainByName(String input) {
    final n = input.trim().toLowerCase();
    for (final m in _mainCategories) {
      if (_safeName(m).trim().toLowerCase() == n) return m;
    }
    return null;
  }

  dynamic _findSubByName(String input) {
    final n = input.trim().toLowerCase();
    for (final s in _activeSubCategories) {
      if (_safeName(s).trim().toLowerCase() == n) return s;
    }
    return null;
  }

  List<String> _mainOptions() => _mainCategories
      .map((e) => _safeName(e))
      .where((s) => s.trim().isNotEmpty)
      .toList();

  List<String> _subOptions() => _activeSubCategories
      .map((e) => _safeName(e))
      .where((s) => s.trim().isNotEmpty)
      .toList();

  // ============================================================
  // UI helpers
  // ============================================================
  void _replaceTypingWith(ChatMessage next) {
    final idx = messages.lastIndexWhere((m) => m.typing);

    final expectsTextInput =
        _context == 'awaiting_details' || _context == 'awaiting_address';

    final sanitized = expectsTextInput
        ? ChatMessage(sender: next.sender, text: next.text, options: null)
        : next;

    setState(() {
      if (idx != -1) {
        messages[idx] = sanitized;
      } else {
        messages.add(sanitized);
      }

      _inputEnabled = expectsTextInput;
      if (!expectsTextInput) _controller.clear();
    });
  }

  void _disableInput() {
    setState(() {
      _inputEnabled = false;
      _controller.clear();
    });
  }

  String _nextId(String prefix) => '$prefix${_ticketSeq++}';

  // ============================================================
  // UI
  // ============================================================
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
                                children: List.generate(options.length, (i) {
                                  final option = options[i];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i == options.length - 1 ? 0 : 8,
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
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

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
                      radius: 3,
                      backgroundColor: Colors.grey,
                    ),
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
