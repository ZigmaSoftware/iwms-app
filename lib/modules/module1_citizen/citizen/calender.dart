import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';
import '../../../core/constants.dart';
import '../../../core/di.dart';
import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_state.dart';
import '../../../shared/models/collection_history.dart';
import '../../../shared/services/collection_history_service.dart';
import '../../../router/app_router.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CollectionHistoryService _historyService;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _historyService = getIt<CollectionHistoryService>();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              onSurface: kTextColor,
            ),
           dialogTheme: DialogThemeData(
  backgroundColor: Colors.white,
),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'dry':
        return Colors.blue;
      case 'wet':
        return Colors.green;
      case 'mixed':
        return Colors.deepOrange;
      default:
        return kPrimaryColor;
    }
  }

  List<CollectionHistoryEntry> _entriesForSelectedDate(
    List<CollectionHistoryEntry> entries,
    {String? customerId}
  ) {
    final trimmedCustomer = customerId?.trim() ?? '';
    return entries.where((entry) {
      if (trimmedCustomer.isNotEmpty &&
          entry.customerId.trim() != trimmedCustomer) {
        return false;
      }
      final date = entry.collectedAt;
      return date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate);
    final formattedHeader = DateFormat('MMMM yyyy').format(_selectedDate);
    final localizations = AppLocalizations.of(context);
    final authState = context.watch<AuthBloc>().state;
    final customerId =
        authState is AuthStateAuthenticated ? authState.userId : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.collectionHistoryPageTitle),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutePaths.citizenHome);
            }
          },
        ),
      ),
      body: ValueListenableBuilder<List<CollectionHistoryEntry>>(
        valueListenable: _historyService.entriesNotifier,
        builder: (context, entries, _) {
          final filtered = _entriesForSelectedDate(
            entries,
            customerId: customerId,
          );
          final totalWeightForDate =
              filtered.fold<double>(0, (sum, entry) => sum + entry.totalWeight);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 28, color: kPrimaryColor),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations.selectDateLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: kPlaceholderColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  localizations.viewingDateLabel(formattedDate),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: kTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios,
                              size: 18, color: kPlaceholderColor),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  localizations.collectionLogFor(formattedHeader),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: kTextColor,
                      ),
                ),
                const Divider(height: 20),
                if (totalWeightForDate > 0)
                  Card(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        localizations.totalWeightCollectedLabel(
                          totalWeightForDate.toStringAsFixed(2),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.inbox_outlined,
                              size: 64, color: kPlaceholderColor),
                          const SizedBox(height: 12),
                          Text(
                            localizations.noCollectionData,
                            style:
                                const TextStyle(fontSize: 16, color: kPlaceholderColor),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filtered.map(_buildEntryCard),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEntryCard(CollectionHistoryEntry entry) {
    final sectionsWithData = entry.sections
        .where((section) =>
            (section.weight?.isNotEmpty ?? false) ||
            (section.imagePath?.isNotEmpty ?? false) ||
            (section.imageBase64?.isNotEmpty ?? false))
        .toList();

    final timeLabel = DateFormat('h:mm a').format(entry.collectedAt);
    final localizations = AppLocalizations.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.collectedAtLabel(timeLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              localizations.customerIdLabel(entry.customerId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kPlaceholderColor),
            ),
            if (entry.customerName.trim().isNotEmpty)
              Text(
                'Citizen: ${entry.customerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kPlaceholderColor),
              ),
            const SizedBox(height: 4),
            Text(
              localizations.entryTotalWeightLabel(
                entry.totalWeight.toStringAsFixed(2),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            const Divider(height: 24),
            if (sectionsWithData.isEmpty)
              Text(
                localizations.noDetailedCollectionData,
                style: const TextStyle(color: kPlaceholderColor),
              )
            else
              for (final section in sectionsWithData)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildSectionRow(section),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionRow(CollectionHistorySection section) {
    final localizations = AppLocalizations.of(context);
    final color = _colorForType(section.normalizedType);
    final rawWeight = section.weight?.trim() ?? '';
    final hasWeight = rawWeight.isNotEmpty;
    final weightDisplay = hasWeight
        ? (RegExp('[a-zA-Z]').hasMatch(rawWeight) ? rawWeight : '$rawWeight kg')
        : localizations.notRecorded;
    final typeLabel =
        '${section.type[0].toUpperCase()}${section.type.substring(1)} Waste';

    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: _buildSectionImage(section),
    );

    final detailColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          typeLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kTextColor,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            weightDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: ((section.imagePath != null &&
                        section.imagePath!.isNotEmpty) ||
                    (section.imageBase64 != null &&
                        section.imageBase64!.isNotEmpty))
                ? () => _viewProof(context, section)
                : null,
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            label: Text(
              localizations.viewProofLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimaryColor,
              side: const BorderSide(color: kPrimaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              imageWidget,
              const SizedBox(height: 12),
              detailColumn,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            imageWidget,
            const SizedBox(width: 16),
            Expanded(child: detailColumn),
          ],
        );
      },
    );
  }

  Widget _buildSectionImage(CollectionHistorySection section) {
    if (section.imageBase64 != null && section.imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(section.imageBase64!);
        return Image.memory(
          bytes,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        );
      } catch (_) {
        // ignore decode errors and fall back to path
      }
    }

    if (section.imagePath == null || section.imagePath!.isEmpty) {
      return Container(
        width: 100,
        height: 100,
        color: kPlaceholderColor.withValues(alpha: 0.2),
        child: const Center(
          child: Icon(Icons.image, color: Colors.grey),
        ),
      );
    }
    final file = File(section.imagePath!);
    if (!file.existsSync()) {
      return Container(
        width: 100,
        height: 100,
        color: kPlaceholderColor.withValues(alpha: 0.2),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    return Image.file(
      file,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
    );
  }

  void _viewProof(
    BuildContext context,
    CollectionHistorySection section,
  ) {
    final localizations = AppLocalizations.of(context);
    if ((section.imageBase64 == null || section.imageBase64!.isEmpty) &&
        (section.imagePath == null || section.imagePath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.noProofImageAvailable),
        ),
      );
      return;
    }

    Widget? imageWidget;
    if (section.imageBase64 != null && section.imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(section.imageBase64!);
        imageWidget = Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        imageWidget = null;
      }
    }

    if (imageWidget == null &&
        section.imagePath != null &&
        section.imagePath!.isNotEmpty) {
      final file = File(section.imagePath!);
      if (file.existsSync()) {
        imageWidget = Image.file(file, fit: BoxFit.contain);
      }
    }

    if (imageWidget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.proofImageMissing),
        ),
      );
      return;
    }

    final proofWidget = imageWidget;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: proofWidget),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(localizations.closeLabel),
            ),
          ],
        ),
      ),
    );
  }
}
