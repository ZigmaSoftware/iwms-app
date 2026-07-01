import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/shared/services/notification_service.dart';
import 'package:iwms_citizen_app/data/models/grievance_ticket_model.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_grievance_repository.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// Supervisor grievance queue with scoped filters, a compact ticket card,
/// and a detail + timeline sheet.
class SupervisorGrievanceScreen extends StatefulWidget {
  const SupervisorGrievanceScreen({super.key});

  @override
  State<SupervisorGrievanceScreen> createState() =>
      _SupervisorGrievanceScreenState();
}

Color _statusColor(String? code) {
  switch (code) {
    case 'SUBMITTED':
    case 'DRAFT':
      return const Color(0xFF0288D1);
    case 'ASSIGNED':
      return const Color(0xFF3949AB);
    case 'IN_PROGRESS':
      return SupervisorTheme.warning;
    case 'ESCALATED':
      return SupervisorTheme.danger;
    case 'RESOLVED':
      return SupervisorTheme.success;
    case 'CLOSED':
      return const Color(0xFF616161);
    case 'REOPENED':
      return const Color(0xFFE65100);
    default:
      return SupervisorTheme.mutedText;
  }
}

String _fmt(DateTime? d) =>
    d == null ? '—' : DateFormat('dd MMM, hh:mm a').format(d.toLocal());

const _finalCodes = {'RESOLVED', 'CLOSED', 'REJECTED', 'CANCELLED'};

class _SupervisorGrievanceScreenState extends State<SupervisorGrievanceScreen> {
  final _repo = SupervisorGrievanceRepository();
  List<GrievanceTicket> _tickets = [];
  bool _loading = true;
  bool _busy = false;
  String _filter = 'all'; // all | pending | started | escalated | resolved
  Timer? _poll;
  Set<String> _knownIds = {};

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _poll =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshSilently());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) setState(() => _loading = true);
    try {
      final list = await _repo.fetchTickets();
      if (!mounted) return;
      setState(() {
        _tickets = list;
        _loading = false;
      });
      _knownIds = list.map((t) => t.uniqueId).toSet();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshSilently() async {
    try {
      final list = await _repo.fetchTickets();
      if (!mounted) return;
      final incoming = list.map((t) => t.uniqueId).toSet();
      final fresh = incoming.difference(_knownIds);
      setState(() => _tickets = list);
      if (_knownIds.isNotEmpty && fresh.isNotEmpty) {
        final n = fresh.length;
        await getIt<NotificationService>().showAssignmentNotification(
          title: 'New grievance${n > 1 ? 's' : ''} in your department',
          message: n > 1
              ? '$n new tickets need attention.'
              : 'A new ticket has been assigned to your team.',
        );
      }
      _knownIds = incoming;
    } catch (_) {}
  }

  List<GrievanceTicket> get _filtered {
    return _tickets.where((t) {
      final c = t.statusCode;
      if (_filter == 'pending') return c == 'SUBMITTED' || c == 'ASSIGNED';
      if (_filter == 'started') return c == 'IN_PROGRESS';
      if (_filter == 'escalated') return c == 'ESCALATED';
      if (_filter == 'resolved') return _finalCodes.contains(c);
      return true;
    }).toList();
  }

  int _count(bool Function(GrievanceTicket) f) => _tickets.where(f).length;

  Future<void> _runAction(String label, Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label ✓'),
          backgroundColor: SupervisorTheme.success,
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label failed'),
          backgroundColor: SupervisorTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askRemarks(String title, {bool required = false}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Add a note…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: SupervisorTheme.accent),
            onPressed: () {
              if (required && ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _onStart(GrievanceTicket t) =>
      _runAction('Started', () => _repo.start(t.uniqueId));

  Future<void> _onEscalate(GrievanceTicket t) async {
    final reason = await _askRemarks('Escalate ${t.ticketNo}', required: true);
    if (reason == null) return;
    _runAction('Escalated', () => _repo.escalate(t.uniqueId, reason));
  }

  Future<void> _onResolve(GrievanceTicket t) async {
    final note = await _askRemarks('Resolve ${t.ticketNo}');
    if (note == null) return;
    _runAction('Resolved', () => _repo.resolve(t.uniqueId, note));
  }

  Future<void> _openDetail(GrievanceTicket summary) async {
    GrievanceTicket t = summary;
    try {
      t = await _repo.fetchTicket(summary.uniqueId);
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SupervisorDetailSheet(ticket: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupervisorTheme.background,
      appBar: AppBar(
        backgroundColor: SupervisorTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Grievances'),
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: SupervisorTheme.accent,
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 140),
                              Center(
                                child: Text(
                                  'No grievances here.',
                                  style: TextStyle(
                                    color: SupervisorTheme.mutedText,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _card(_filtered[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final tabs = [
      ('all', 'All', _tickets.length),
      (
        'pending',
        'Pending',
        _count((t) => t.statusCode == 'SUBMITTED' || t.statusCode == 'ASSIGNED'),
      ),
      ('started', 'Started', _count((t) => t.statusCode == 'IN_PROGRESS')),
      ('escalated', 'Escalated', _count((t) => t.statusCode == 'ESCALATED')),
      ('resolved', 'Resolved', _count((t) => _finalCodes.contains(t.statusCode))),
    ];
    return Container(
      color: SupervisorTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (key, label, n) in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$label ($n)'),
                  selected: _filter == key,
                  onSelected: (_) => setState(() => _filter = key),
                  selectedColor: SupervisorTheme.primary,
                  labelStyle: TextStyle(
                    color: _filter == key
                        ? Colors.white
                        : SupervisorTheme.strongText,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: SupervisorTheme.surfaceMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(GrievanceTicket t) {
    final sc = _statusColor(t.statusCode);
    final isFinal = _finalCodes.contains(t.statusCode);
    final isStarted = t.statusCode == 'IN_PROGRESS';
    final showStart = !isFinal && !isStarted;
    final showEscalate = !isFinal;
    final showResolve = !isFinal;

    return Container(
      decoration: BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: sc, width: 4)),
        boxShadow: SupervisorTheme.softShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.ticketNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if ((t.title ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        t.title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (t.priorityCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: SupervisorTheme.strongText,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t.priorityCode!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      t.statusName ?? t.statusCode ?? '-',
                      style: TextStyle(
                        color: sc,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _meta(
            Icons.folder_outlined,
            '${t.categoryName ?? '-'}${t.subcategoryName != null ? ' › ${t.subcategoryName}' : ''}',
          ),
          if (t.assignedStaffName != null)
            _meta(Icons.engineering_outlined, t.assignedStaffName!),
          if ((t.locationText ?? '').isNotEmpty)
            _meta(Icons.place_outlined, t.locationText!),
          _meta(Icons.schedule, _fmt(t.createdAt)),
          const Divider(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (showStart)
                _actionBtn(
                  label: 'Start work',
                  icon: Icons.play_arrow_rounded,
                  color: SupervisorTheme.warning,
                  onTap: () => _onStart(t),
                ),
              if (showEscalate)
                _actionBtn(
                  label: 'Escalate',
                  icon: Icons.trending_up_rounded,
                  color: SupervisorTheme.danger,
                  onTap: () => _onEscalate(t),
                ),
              if (showResolve)
                _actionBtn(
                  label: 'Resolve',
                  icon: Icons.check_circle_rounded,
                  color: SupervisorTheme.success,
                  onTap: () => _onResolve(t),
                ),
              TextButton.icon(
                onPressed: () => _openDetail(t),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Details'),
              ),
              if (isStarted)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    'Work started',
                    style: TextStyle(
                      color: SupervisorTheme.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: SupervisorTheme.mutedText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: SupervisorTheme.mutedText,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      OutlinedButton(
        onPressed: _busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _SupervisorDetailSheet extends StatelessWidget {
  final GrievanceTicket ticket;
  const _SupervisorDetailSheet({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(ticket.statusCode);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.ticketNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ticket.statusName ?? ticket.statusCode ?? '-',
                  style: TextStyle(
                    color: sc,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _kv(
            'Category',
            '${ticket.categoryName ?? '-'}${ticket.subcategoryName != null ? ' › ${ticket.subcategoryName}' : ''}',
          ),
          _kv('Priority', ticket.priorityCode ?? '-'),
          _kv('Assigned team', ticket.assignedTeamName ?? '-'),
          if (ticket.assignedStaffName != null)
            _kv('Responsible', ticket.assignedStaffName!),
          if ((ticket.customerName ?? '').isNotEmpty)
            _kv('Citizen', ticket.customerName!),
          if ((ticket.waPhone ?? '').isNotEmpty)
            _kv('Contact', ticket.waPhone!),
          if ((ticket.locationText ?? '').isNotEmpty)
            _kv('Location', ticket.locationText!),
          _kv('Raised on', _fmt(ticket.createdAt)),
          if ((ticket.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(ticket.description!),
          ],
          const SizedBox(height: 20),
          const Text(
            'Progress timeline',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (ticket.timeline.isEmpty)
            Text(
              'No updates yet.',
              style: TextStyle(color: SupervisorTheme.mutedText),
            )
          else
            ...ticket.timeline.map(_tile),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                k,
                style: TextStyle(
                  color: SupervisorTheme.mutedText,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _tile(GrievanceTimelineEvent e) {
    final sc = _statusColor(e.statusCode);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: sc, shape: BoxShape.circle),
              ),
              Expanded(child: Container(width: 2, color: Colors.grey.shade200)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.statusName.isNotEmpty ? e.statusName : e.statusCode,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if ((e.remarks ?? '').isNotEmpty)
                    Text(e.remarks!,
                        style: const TextStyle(fontSize: 13.5, height: 1.25)),
                  Text(
                    _fmt(e.at),
                    style: TextStyle(
                      color: SupervisorTheme.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
