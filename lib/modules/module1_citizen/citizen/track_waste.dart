import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/theme/citizen_pattern_background.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/controllers/track_controller.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/widgets/track_tab.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/services/track_service.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

class TrackWasteScreen extends StatefulWidget {
  const TrackWasteScreen({super.key});

  @override
  State<TrackWasteScreen> createState() => _TrackWasteScreenState();
}

class _TrackWasteScreenState extends State<TrackWasteScreen> {
  late final TrackController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TrackController(TrackService())..refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.trackWaste,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: highlightColor,
      ),
      body: CitizenPatternBackground(
        child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return TrackTab(
            controller: _controller,
            highlightColor: highlightColor,
            textColor: textColor,
            onPickDate: () async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                initialDate: _controller.selectedDate,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 1),
                helpText: localizations.trackDatePickerHelp,
                builder: (context, child) {
                  return Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: highlightColor,
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (selected != null) {
                await _controller.pickDate(selected);
              }
            },
          );
        },
        ),
      ),
    );
  }
}
