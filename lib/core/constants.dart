// lib/core/constants.dart

import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';

// --- COLOR AND STYLE CONSTANTS ---
const Color kPrimaryColor = AppColors.primary; // Deep green primary
const Color kAccentColor = AppColors.primaryVariant; // Emerald accent
const Color kSoftTintColor = AppColors.accentLight; // Soft green background

const Color kTextColor = AppColors.textPrimary; // Rich forest text
const Color kPlaceholderColor = AppColors.textSecondary; // Muted herb hints
const Color kContainerColor = kSoftTintColor; // Light container background
const Color kBorderColor = AppColors.accentMuted; // Soft green border

// --- NEW ENUM FOR FILTERING (Shared by Bloc and UI) ---
enum VehicleFilter { all, running, idle, parked, noData }

// --- REUSABLE HELPER (No longer needed when we use GoRouter) ---
// The previously defined `createSlideUpRoute` function has been removed
// as GoRouter handles transitions efficiently using the routes configuration.
