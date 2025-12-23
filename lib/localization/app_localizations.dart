import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/constants.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(
      localizations != null,
      'No AppLocalizations found in context. Did you add AppLocalizations.delegate?',
    );
    return localizations!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'profileTitle': 'Profile',
      'profileSubtitle': 'Manage your account and collection preferences.',
      'greeting': 'Hi, {name}',
      'collectionDetails': 'Collection Details',
      'collectionHistory': 'Collection History & Weighment',
      'trackWaste': 'Track My Waste',
      'raiseGrievance': 'Raise Grievance (Help Desk)',
      'darkMode': 'Dark Mode',
      'darkModeSubtitle': 'Switch between light and dark experiences',
      'changeLanguage': 'Change Language',
      'changeLanguageSubtitle': 'Choose between Hindi and Tamil',
      'languageSaved': 'Language preference saved: {label}',
      'profileContactTitle': 'Contact details',
      'profileContactSubtitle': 'All key references in one place',
      'profilePhoneLabel': 'Phone',
      'profileEmailLabel': 'Email',
      'profileDesignationLabel': 'Designation',
      'profileWardZoneLabel': 'Ward / Zone',
      'profileAttendanceTitle': 'Attendance & leave',
      'profileAttendanceSubtitle': 'Quick snapshot from attendance module',
      'profileEditButton': 'Edit profile',
      'logout': 'Logout',
      'homeTitle': 'Home',
      'quickActions': 'Quick Actions',
      'notificationsLabel': 'Notifications',
      'notificationsCaughtUp': 'You are all caught up!',
      'notificationsWaiting':
          'We will alert you as soon as a collection vehicle enters your geofence.',
      'wasteCollected': '{period} waste collected',
      'noWasteRecorded': 'No waste recorded yet for this period',
      'trackHeaderTitle': 'Track Your Waste',
      'trackLiveDescription':
          'Live weighment figures from operator uploads. Data resets monthly.',
      'trackChoosePeriod': 'Choose a period to view wet, dry and mixed totals.',
      'trackShowingPeriod': 'Showing {period} data',
      'trackLoading': 'Pulling live collection figures...',
      'trackNoData':
          'No waste is recorded for this period yet. We will show new weights as soon as operators upload them.',
      'trackRetry': 'Retry now',
      'wetWaste': 'Wet Waste',
      'dryWaste': 'Dry Waste',
      'mixedWaste': 'Mixed Waste',
      'metricWet': 'Wet waste collected',
      'metricDry': 'Dry waste collected',
      'metricMixed': 'Mixed waste collected',
      'metricTotal': 'Total waste collected',
      'metricTapCard': 'Tap a card above to view detailed breakdown.',
      'metricTapBack': 'Tap again to switch back to total waste.',
      'calendarLabel': 'Calendar',
      'allTime': 'All time',
      'periodDaily': 'Daily',
      'periodMonthly': 'Monthly',
      'periodTotal': 'Total',
      'mapLiveHeadline': 'Live Vehicle Tracking',
      'mapVehicleHeadline': 'Tracking {vehicle}',
      'mapRefreshingTelemetry': 'Refreshing telemetry.',
      'mapVehiclesActive': '{count} vehicle{pluralSuffix} active',
      'mapVehicleEnRoute': '{vehicle} en route',
      'mapSearchHint': 'Search vehicle / ward / driver',
      'mapEstimatedLoad': 'Estimated Load',
      'mapLastUpdate': 'Last update',
      'mapUnknownVehicle': 'Unknown Vehicle',
      'mapNoData': 'No Data',
      'mapThemeStandard': 'Standard',
      'mapThemeLight': 'Light',
      'mapAssignedVehicle': 'Assigned vehicle',
      'mapCollectorEnRoute': 'Your collector is en route',
      'mapAwaitingAssignedVehicle': 'Awaiting assigned vehicle',
      'mapLiveTelemetry': 'Live telemetry',
      'mapNoLocationYet': 'No location yet',
      'mapWaitingForCollector':
          'Waiting for your allocated collector to enter {zone}.',
      'mapVehicleCounts': '{assigned} allocated · {total} total',
      'tabHome': 'Home',
      'tabTrack': 'Track',
      'tabMap': 'Map',
      'tabProfile': 'Profile',
      'attendanceTabHome': 'Home',
      'attendanceTabMarkAttendance': 'Mark Attendance',
      'attendanceTabSummary': 'Summary',
      'trackButtonLabel': 'Track',
      'vehicleFilterAll': 'All',
      'vehicleFilterRunning': 'Running',
      'vehicleFilterIdle': 'Idle',
      'vehicleFilterParked': 'Parked',
      'vehicleFilterNoData': 'No data',
      'mapGammaCollectionZone': 'Gamma Collection Zone',
      'quickActionTrackVehicles': 'Track Vehicles',
      'quickActionCollectionDetails': 'Collection Details',
      'quickActionCollectionHistory': 'Collection History',
      'quickActionRaiseGrievance': 'Raise Grievance',
      'quickActionRateCollector': 'Rate Collector',
      'quickActionQr': 'QR',
      'quickActionUpcomingCollection': 'Upcoming Collection',
      'qrDialogTitle': 'My Collection QR',
      'qrDialogSubtitle':
          'Show this code to your collector for instant verification.',
      'qrDialogLoginPrompt': 'Please log in to view your QR code.',
      'qrDialogDone': 'Done',
      'collectionHistoryPageTitle': 'Collection History',
      'selectDateLabel': 'Select Date',
      'viewingDateLabel': 'Viewing: {date}',
      'collectionLogFor': 'Collection Log for {month}',
      'totalWeightCollectedLabel': 'Total Weight Collected: {weight} kg',
      'noCollectionData': 'No collection data for this date yet.',
      'noDetailedCollectionData': 'No detailed data captured for this visit.',
      'collectedAtLabel': 'Collected at {time}',
      'customerIdLabel': 'Customer ID: {id}',
      'entryTotalWeightLabel': 'Total Weight: {weight} kg',
      'viewProofLabel': 'View Proof',
      'notRecorded': 'Not recorded',
      'noProofImageAvailable': 'No proof image available for this entry.',
      'proofImageMissing': 'Proof image could not be found.',
      'closeLabel': 'Close',
      'trackDatePickerHelp': 'Choose a date to view collection data',
      'registrationSuccessTitle': 'Registration Successful',
      'registrationComplete': 'Registration Complete!',
      'welcomeMessage': 'Welcome, {name}!',
      'qrActivatedDescription':
          'Your unique QR code is now active for waste collection verification.',
      'viewMyCollectionQr': 'View My Collection QR Code',
      'skipToDashboard': 'Skip to Dashboard',
      'operatorLabel': 'Operator',
      'operatorHeaderSubtitle': '{name} · {code}',
      'operatorWardZone': 'Ward {ward} · Zone {zone}',
      'operatorNavHome': 'Home',
      'operatorNavOverview': 'Overview',
      'operatorNavAssignments': 'Assignments',
      'operatorNavAttendance': 'Attendance',
      'operatorNavProfile': 'Profile',
      'operatorNextStop': 'Next stop',
      'operatorUpcomingStop': 'Upcoming stop',
      'operatorRouteLabel': 'Route',
      'operatorTapToScan': 'Tap to scan QR / Collect waste',
      'operatorLastCollected': 'Last collected',
      'operatorWet': 'Wet',
      'operatorDry': 'Dry',
      'operatorTime': 'Time',
      'operatorAttendanceTitle': 'Attendance',
      'operatorAttendanceSubtitle': 'Stay in sync with your shift',
      'operatorAttendanceOpen': 'Open attendance',
      'operatorAttendanceToday': 'Today',
      'operatorAttendanceMonth': 'This month',
      'operatorLeaveBalance': 'Leave balance',
      'operatorAttendanceStreak': 'Attendance streak',
      'operatorAttendanceSummary': 'Summary',
      'operatorAttendanceHistory': 'History',
      'operatorAttendanceMark': 'Mark',
      // ===== Attendance Screen =====
      'attendanceTitle': 'Attendance',
      'attendanceSubtitle': "Manage today's presence and history",
      'presence': 'Presence',
      'leaves': 'Leaves',
      'permission': 'Permission',
      'checkIn': 'Check In',
      'checkOut': 'Check Out',
      'leave': 'Leave',
      'visit': 'Visit',
      'overtime': 'Overtime',
      'history': 'History',
      'summary': 'Summary',
      'punchAttendance': 'Punch Attendance',
      'pendingSync': 'Pending Sync',
      'online': 'Online',
      'offline': 'Offline',
      'noInternetSync': 'No internet. Cannot sync.',
      'syncSuccess': 'Synced successfully.',
      'syncFailed': 'Sync failed.',
      'enableLocation': 'Please enable location services.',
      'locationPermissionRequired': 'Location permission is required.',
    },
    'hi': {
      'profileTitle': 'प्रोफ़ाइल',
      'profileSubtitle': 'अपने खाते और संग्रह प्राथमिकताओं को प्रबंधित करें।',
      'greeting': 'नमस्ते, {name}',
      'collectionDetails': 'संग्रह विवरण',
      'collectionHistory': 'संग्रह इतिहास और वज़न',
      'trackWaste': 'मेरे कचरे को ट्रैक करें',
      'raiseGrievance': 'शिकायत दर्ज करें (हेल्प डेस्क)',
      'darkMode': 'डार्क मोड',
      'darkModeSubtitle': 'लाइट और डार्क अनुभवों के बीच स्विच करें',
      'changeLanguage': 'भाषा बदलें',
      'changeLanguageSubtitle': 'हिंदी और तमिल के बीच चुनें',
      'languageSaved': 'भाषा प्राथमिकता सहेजी गई: {label}',
      'profileContactTitle': 'संपर्क विवरण',
      'profileContactSubtitle': 'सभी प्रमुख संदर्भ एक ही स्थान पर',
      'profilePhoneLabel': 'फोन',
      'profileEmailLabel': 'ईमेल',
      'profileDesignationLabel': 'पदनाम',
      'profileWardZoneLabel': 'वार्ड / जोन',
      'profileAttendanceTitle': 'उपस्थिति और छुट्टी',
      'profileAttendanceSubtitle': 'उपस्थिति मॉड्यूल से त्वरित झलक',
      'profileEditButton': 'प्रोफ़ाइल संपादित करें',
      'logout': 'लॉग आउट',
      'homeTitle': 'होम',
      'quickActions': 'त्वरित क्रियाएँ',
      'notificationsLabel': 'सूचनाएँ',
      'notificationsCaughtUp': 'आप सब कुछ देख चुके हैं!',
      'notificationsWaiting':
          'जब भी कोई संग्रह वाहन आपकी भू-सीमा में प्रवेश करता है, हम आपको सूचित करेंगे।',
      'wasteCollected': '{period} कचरा एकत्रित',
      'noWasteRecorded': 'इस अवधि में कोई कचरा रिकॉर्ड नहीं हुआ है',
      'trackHeaderTitle': 'अपने कचरे को ट्रैक करें',
      'trackLiveDescription':
          'ऑपरेटर अपलोड से लाइव वज़न आंकड़े। डेटा मासिक रूप से रीसेट होता है।',
      'trackChoosePeriod':
          'गीला, सूखा और मिश्रित कुल देखने के लिए एक अवधि चुनें।',
      'trackShowingPeriod': '{period} डेटा दिखाया जा रहा है',
      'trackLoading': 'लाइव संग्रह आंकड़े लाए जा रहे हैं...',
      'trackNoData':
          'इस अवधि के लिए कोई कचरा दर्ज नहीं है। जैसे ही ऑपरेटर अपलोड करेंगे, हम नए भार दिखाएंगे।',
      'trackRetry': 'अब पुनः प्रयास करें',
      'wetWaste': 'गीला कचरा',
      'dryWaste': 'सूखा कचरा',
      'mixedWaste': 'मिश्रित कचरा',
      'metricWet': 'एकत्रित गीला कचरा',
      'metricDry': 'एकत्रित सूखा कचरा',
      'metricMixed': 'एकत्रित मिश्रित कचरा',
      'metricTotal': 'कुल कचरा एकत्रित',
      'metricTapCard': 'विस्तृत विवरण देखने के लिए ऊपर कार्ड पर टैप करें।',
      'metricTapBack': 'कुल कचरे पर वापस जाने के लिए फिर से टैप करें।',
      'calendarLabel': 'कैलेंडर',
      'allTime': 'सभी समय',
      'periodDaily': 'दैनिक',
      'periodMonthly': 'मासिक',
      'periodTotal': 'कुल',
      'mapLiveHeadline': 'लाइव वाहन ट्रैकिंग',
      'mapVehicleHeadline': '{vehicle} को ट्रैक किया जा रहा है',
      'mapRefreshingTelemetry': 'टेलीमेट्री रीफ्रेश हो रही है।',
      'mapVehiclesActive': '{count} वाहन सक्रिय',
      'mapVehicleEnRoute': '{vehicle} मार्ग पर है',
      'mapSearchHint': 'वाहन / वार्ड / ड्राइवर खोजें',
      'mapEstimatedLoad': 'अनुमानित लोड',
      'mapLastUpdate': 'अंतिम अद्यतन',
      'mapUnknownVehicle': 'अज्ञात वाहन',
      'mapNoData': 'कोई डेटा नहीं',
      'mapThemeStandard': 'मानक',
      'mapThemeLight': 'लाइट',
      'mapAssignedVehicle': 'नियुक्त वाहन',
      'mapCollectorEnRoute': 'आपका कलेक्टर रास्ते में है',
      'mapAwaitingAssignedVehicle': 'नियुक्त वाहन का इंतजार',
      'mapLiveTelemetry': 'लाइव टेलीमेट्री',
      'mapNoLocationYet': 'अभी तक कोई स्थान नहीं',
      'mapWaitingForCollector':
          'आपके आवंटित कलेक्टर के {zone} में प्रवेश करने की प्रतीक्षा है।',
      'mapVehicleCounts': '{assigned} नियोजित · {total} कुल',
      'tabHome': 'होम',
      'tabTrack': 'ट्रैक',
      'tabMap': 'मैप',
      'tabProfile': 'प्रोफ़ाइल',
      'attendanceTabHome': 'होम',
      'attendanceTabMarkAttendance': 'उपस्थिति दर्ज करें',
      'attendanceTabSummary': 'सारांश',
      'trackButtonLabel': 'ट्रैक',
      'vehicleFilterAll': 'सभी',
      'vehicleFilterRunning': 'चल रहे',
      'vehicleFilterIdle': 'निष्क्रिय',
      'vehicleFilterParked': 'पार्क किया',
      'vehicleFilterNoData': 'कोई डेटा नहीं',
      'mapGammaCollectionZone': 'गामा संग्रह क्षेत्र',
      'quickActionTrackVehicles': 'वाहनों को ट्रैक करें',
      'quickActionCollectionDetails': 'संग्रह विवरण',
      'quickActionCollectionHistory': 'संग्रह इतिहास',
      'quickActionRaiseGrievance': 'शिकायत दर्ज करें',
      'quickActionRateCollector': 'कलेक्टर को रेट करें',
      'quickActionQr': 'QR',
      'quickActionUpcomingCollection': 'आगामी संग्रह',
      'qrDialogTitle': 'मेरी संग्रह QR',
      'qrDialogSubtitle':
          'इस कोड को अपने कलेक्टर को दिखाएँ ताकि वे तुरंत सत्यापन कर सकें।',
      'qrDialogLoginPrompt': 'कृपया अपना QR देखने के लिए लॉग इन करें।',
      'qrDialogDone': 'समाप्त',
      'collectionHistoryPageTitle': 'संग्रह इतिहास',
      'selectDateLabel': 'तारीख चुनें',
      'viewingDateLabel': 'देखा जा रहा है: {date}',
      'collectionLogFor': '{month} के लिए संग्रह लॉग',
      'totalWeightCollectedLabel': 'कुल संग्रहित वजन: {weight} किग्रा',
      'noCollectionData': 'इस तिथि के लिए अभी कोई संग्रह डेटा नहीं है।',
      'noDetailedCollectionData':
          'इस यात्रा के लिए कोई विस्तृत डेटा दर्ज नहीं किया गया है।',
      'collectedAtLabel': 'संग्रह समय: {time}',
      'customerIdLabel': 'ग्राहक आईडी: {id}',
      'entryTotalWeightLabel': 'कुल वजन: {weight} किग्रा',
      'viewProofLabel': 'प्रमाण देखें',
      'notRecorded': 'रिकॉर्ड नहीं किया गया',
      'noProofImageAvailable':
          'इस प्रविष्टि के लिए कोई प्रमाण छवि उपलब्ध नहीं है।',
      'proofImageMissing': 'प्रमाण छवि नहीं मिली।',
      'closeLabel': 'बंद करें',
      'trackDatePickerHelp': 'संग्रह डेटा देखने के लिए एक तिथि चुनें',
      'registrationSuccessTitle': 'पंजीकरण सफल',
      'registrationComplete': 'पंजीकरण पूर्ण!',
      'welcomeMessage': 'स्वागत है, {name}!',
      'qrActivatedDescription':
          'आपका अनूठा QR कोड अब कचरा संग्रह सत्यापन के लिए सक्रिय है।',
      'viewMyCollectionQr': 'मेरा संग्रह QR कोड देखें',
      'skipToDashboard': 'डैशबोर्ड पर जाएँ',
      'operatorLabel': 'ऑपरेटर',
      'operatorHeaderSubtitle': '{name} · {code}',
      'operatorWardZone': 'वार्ड {ward} · जोन {zone}',
      'operatorNavHome': 'होम',
      'operatorNavOverview': 'ओवरव्यू',
      'operatorNavAssignments': 'असाइनमेंट',
      'operatorNavAttendance': 'उपस्थिति',
      'operatorNavProfile': 'प्रोफ़ाइल',
      'operatorNextStop': 'अगला स्टॉप',
      'operatorUpcomingStop': 'आगामी स्टॉप',
      'operatorRouteLabel': 'रूट',
      'operatorTapToScan': 'QR स्कैन करने के लिए टैप करें / कचरा एकत्र करें',
      'operatorLastCollected': 'अंतिम संग्रह',
      'operatorWet': 'गीला',
      'operatorDry': 'सूखा',
      'operatorTime': 'समय',
      'operatorAttendanceTitle': 'उपस्थिति',
      'operatorAttendanceSubtitle': 'अपने शिफ्ट के साथ सिंक में रहें',
      'operatorAttendanceOpen': 'उपस्थिति खोलें',
      'operatorAttendanceToday': 'आज',
      'operatorAttendanceMonth': 'इस महीने',
      'operatorLeaveBalance': 'छुट्टी शेष',
      'operatorAttendanceStreak': 'उपस्थिति की लकीर',
      'operatorAttendanceSummary': 'सारांश',
      'operatorAttendanceHistory': 'इतिहास',
      'operatorAttendanceMark': 'निशान लगाएँ',
      // ===== Attendance Screen =====
      'attendanceTitle': 'उपस्थिति',
      'attendanceSubtitle': 'आज की उपस्थिति और इतिहास प्रबंधित करें',
      'presence': 'उपस्थिति',
      'leaves': 'छुट्टियाँ',
      'permission': 'अनुमति',
      'checkIn': 'चेक इन',
      'checkOut': 'चेक आउट',
      'leave': 'छुट्टी',
      'visit': 'भ्रमण',
      'overtime': 'ओवरटाइम',
      'history': 'इतिहास',
      'summary': 'सारांश',
      'punchAttendance': 'उपस्थिति पंच करें',
      'pendingSync': 'लंबित सिंक',
      'online': 'ऑनलाइन',
      'offline': 'ऑफलाइन',
      'noInternetSync': 'इंटरनेट नहीं है। सिंक संभव नहीं।',
      'syncSuccess': 'सफलतापूर्वक सिंक हुआ।',
      'syncFailed': 'सिंक विफल।',
      'enableLocation': 'कृपया लोकेशन सेवा सक्षम करें।',
      'locationPermissionRequired': 'लोकेशन अनुमति आवश्यक है।',
    },
    'ta': {
      'profileTitle': 'சுயவிவரம்',
      'profileSubtitle':
          'உங்கள் கணக்கு மற்றும் சேமிப்பு விருப்பங்களை நிர்வகிக்கவும்.',
      'greeting': 'வணக்கம், {name}',
      'collectionDetails': 'சேகரிப்பு விவரங்கள்',
      'collectionHistory': 'சேகரிப்பு வரலாறு மற்றும் எடை',
      'trackWaste': 'என் குப்பையை கண்காணிக்கவும்',
      'raiseGrievance': 'புலம்புரை பதிவு (உதவி மையம்)',
      'darkMode': 'இருண்ட நிலை',
      'darkModeSubtitle': 'ஒளி மற்றும் இருண்ட அனுபவங்களை மாற்றவும்',
      'changeLanguage': 'மொழியை மாற்றவும்',
      'changeLanguageSubtitle': 'ஹிந்தி மற்றும் தமிழ் மொழிகளில் தேர்வு செய்க',
      'languageSaved': 'மொழி விருப்பம் சேமிக்கப்பட்டது: {label}',
      'profileContactTitle': 'தொடர்பு விவரங்கள்',
      'profileContactSubtitle': 'அனைத்து முக்கிய குறிப்புகளும் ஒரே இடத்தில்',
      'profilePhoneLabel': 'அலைபேசி',
      'profileEmailLabel': 'மின்னஞ்சல்',
      'profileDesignationLabel': 'பதவி',
      'profileWardZoneLabel': 'வார்டு / மண்டலம்',
      'profileAttendanceTitle': 'வருகையும் விடுதியும்',
      'profileAttendanceSubtitle': 'வருகை தொகுப்பின் சுருக்கத்தை விரைவாக காண்க',
      'profileEditButton': 'சுயவிவரத்தை தொகுக்கவும்',
      'logout': 'வெளியேறு',
      'homeTitle': 'முகப்பு',
      'quickActions': 'விரைவு நடவடிக்கைகள்',
      'notificationsCaughtUp': 'நீங்கள் அனைத்தையும் பார்த்துவிட்டீர்கள்!',
      'notificationsWaiting':
          'ஒரு சேகரிப்பு வண்டி உங்கள் பாதுகாப்பு வரம்புக்குள் வந்தவுடன் நாங்கள் அறிவிப்போம்.',
      'wasteCollected': '{period} குப்பை சேகரிக்கப்பட்டது',
      'noWasteRecorded': 'இந்த காலத்தில் எந்த குப்பையும் பதிவாகவில்லை',
      'trackHeaderTitle': 'உங்கள் குப்பையை கண்காணிக்கவும்',
      'trackLiveDescription':
          'ஆபரேட்டர் பதிவுகளிலிருந்து நேரடி எடை தொகைகள். தரவு மாதந்தோறும் மீட்டமைக்கப்படும்.',
      'trackChoosePeriod':
          'ஈர், உலர் மற்றும் கலப்பு மொத்தங்களை காணஒரு காலத்தைத் தேர்ந்தெடுக்கவும்.',
      'trackShowingPeriod': '{period} தரவு காட்டப்படுகிறது',
      'trackLoading': 'நேரடி சேகரிப்பு தரவுகள் ஏற்றப்படுகின்றன...',
      'trackNoData':
          'இந்த காலத்திற்கு எந்த குப்பை பதிவாகவில்லை. ஆபரேட்டர்கள் பதிவேற்றும் போதும் புதிய எடைகள் காட்டப்படும்.',
      'trackRetry': 'இப்போது மறுபடியும் முயற்சிக்கவும்',
      'wetWaste': 'ஈர குப்பை',
      'dryWaste': 'உலர் குப்பை',
      'mixedWaste': 'கலப்பு குப்பை',
      'metricWet': 'சேகரிக்கப்பட்ட ஈர குப்பை',
      'metricDry': 'சேகரிக்கப்பட்ட உலர் குப்பை',
      'metricMixed': 'சேகரிக்கப்பட்ட கலப்பு குப்பை',
      'metricTotal': 'மொத்த குப்பை சேகரிக்கப்பட்டது',
      'metricTapCard':
          'விரிவான விவரங்களைப் பார்க்க மேலே உள்ள அட்டையைத் தொட்டு பாருங்கள்.',
      'metricTapBack':
          'மொத்த குப்பைக்கு திரும்ப விரும்பினால் மீண்டும் தொட்டு மாற்றவும்.',
      'calendarLabel': 'காலண்டர்',
      'allTime': 'எல்லா காலங்களிலும்',
      'periodDaily': 'தினசரி',
      'periodMonthly': 'மாதாந்திர',
      'periodTotal': 'மொத்தம்',
      'mapLiveHeadline': 'நேரடி வாகன கண்காணிப்பு',
      'mapVehicleHeadline': '{vehicle} கண்காணிக்கப்படுகிறது',
      'mapRefreshingTelemetry': 'டெலிமெட்ரி புதுப்பிக்கப்படுகிறது.',
      'mapVehiclesActive': '{count} வாகனங்கள் செயல்பாட்டில் உள்ளன',
      'mapVehicleEnRoute': '{vehicle} பாதையில் உள்ளது',
      'mapSearchHint': 'வாகனம் / வார்ட் / டிரைவர் தேடவும்',
      'mapEstimatedLoad': 'கணிக்கப்பட்ட பாரம்',
      'mapLastUpdate': 'கடைசி புதுப்பிப்பு',
      'mapUnknownVehicle': 'அறியப்படாத வாகனம்',
      'mapNoData': 'தரவு இல்லை',
      'mapThemeStandard': 'நெறிமுறை',
      'mapThemeLight': 'ஒளி',
      'mapAssignedVehicle': 'ஒதுக்கப்பட்ட வாகனம்',
      'mapCollectorEnRoute': 'உங்கள் சேகரிப்பாளர் வழியில் உள்ளார்',
      'mapAwaitingAssignedVehicle': 'ஒதுக்கப்பட்ட வாகனத்தை எதிர்பார்க்கிறது',
      'mapLiveTelemetry': 'நேரடி தொலைமார்பு',
      'mapNoLocationYet': 'இப்பொழுதுவரை இடம் இல்லை',
      'mapWaitingForCollector':
          '{zone} இல் உங்கள் நியமிக்கப்பட்ட சேகரிப்பாளர் வருவதை எதிர்பார்க்கிறோம்.',
      'mapVehicleCounts': '{assigned} ஒதுக்கப்பட்டவை · {total} மொத்தம்',
      'tabHome': 'முகப்பு',
      'tabTrack': 'டிராக்',
      'tabMap': 'வரைபடம்',
      'tabProfile': 'சுயவிவரம்',
      'attendanceTabHome': 'முகப்பு',
      'attendanceTabMarkAttendance': 'வருகையை பதிவு செய்',
      'attendanceTabSummary': 'சுருக்கம்',
      'trackButtonLabel': 'டிராக்',
      'vehicleFilterAll': 'அனைத்தும்',
      'vehicleFilterRunning': 'நடந்து கொண்டிருக்கிறது',
      'vehicleFilterIdle': 'இயக்கம் இல்லாதது',
      'vehicleFilterParked': 'நிறுத்தப்பட்டுள்ளது',
      'vehicleFilterNoData': 'தரவு இல்லை',
      'mapGammaCollectionZone': 'காம்மா சேகரிப்பு மண்டலம்',
      'quickActionTrackVehicles': 'வாகனங்களை பின்தொடர்க',
      'quickActionCollectionDetails': 'சேகரிப்பு விவரங்கள்',
      'quickActionCollectionHistory': 'சேகரிப்பு வரலாறு',
      'quickActionRaiseGrievance': 'புலம்புரை பதிவுச் செய்',
      'quickActionRateCollector': 'கலெக்டரை மதிப்பிடு',
      'quickActionQr': 'QR',
      'quickActionUpcomingCollection': 'வரும் சேகரிப்பு',
      'qrDialogTitle': 'என் சேகரிப்பு QR',
      'qrDialogSubtitle':
          'உங்கள் சேகரிப்பாளருக்கு உடனடி சரிபார்ப்பு செய்ய இந்த குறியீட்டை காட்டவும்.',
      'qrDialogLoginPrompt': 'உங்கள் QR ஐ காண உள்நுழையவும்.',
      'qrDialogDone': 'முடிந்தது',
      'collectionHistoryPageTitle': 'சேகரிப்பு வரலாறு',
      'selectDateLabel': 'தேதியைத் தேர்ந்தெடு',
      'viewingDateLabel': 'பார்க்கும் தேதி: {date}',
      'collectionLogFor': '{month} மாதம் சேகரிப்பு பதிவு',
      'totalWeightCollectedLabel': 'மொத்த சேகரிக்கப்பட்ட எடை: {weight} கிலோ',
      'noCollectionData': 'இந்த தேதிக்கான சேகரிப்பு தரவு இன்னும் இல்லை.',
      'noDetailedCollectionData':
          'இந்த பயணத்திற்கான விரிவான தரவு பதிவு செய்யப்படவில்லை.',
      'collectedAtLabel': 'சேகரிக்கப்பட்ட நேரம்: {time}',
      'customerIdLabel': 'வாடிக்கையாளர் ஐடி: {id}',
      'entryTotalWeightLabel': 'மொத்த எடை: {weight} கிலோ',
      'viewProofLabel': 'ஆதாரம் பார்க்கவும்',
      'notRecorded': 'பதிவு செய்யப்படவில்லை',
      'noProofImageAvailable': 'இந்த பதிவிற்கு ஆதார படம் கிடைக்கவில்லை.',
      'proofImageMissing': 'ஆதார படம் கிடைக்கவில்லை.',
      'closeLabel': 'மூடு',
      'trackDatePickerHelp':
          'சேகரிப்பு தரவைப் பார்க்க ஒரு தேதியை தேர்ந்தெடுக்கவும்',
      'registrationSuccessTitle': 'பதிவு வெற்றி',
      'registrationComplete': 'பதிவு நிறைவு!',
      'welcomeMessage': 'வரவேற்கிறோம், {name}!',
      'qrActivatedDescription':
          'உங்கள் தனிப்பட்ட QR குறியீடு இப்போது குப்பை சேகரிப்பு உறுதிப்படுத்தலுக்கு செயலில் உள்ளது.',
      'viewMyCollectionQr': 'என் சேகரிப்பு QR குறியீட்டை காண்க',
      'skipToDashboard': 'டாஷ்போர்டுக்கு செல்லுங்கள்',
      'operatorLabel': 'ஆபரேட்டர்',
      'operatorHeaderSubtitle': '{name} · {code}',
      'operatorWardZone': 'வார்டு {ward} · மண்டலம் {zone}',
      'operatorNavHome': 'முகப்பு',
      'operatorNavOverview': 'கண்ணோட்டம்',
      'operatorNavAssignments': 'ஒதுக்கீடுகள்',
      'operatorNavAttendance': 'வருகை',
      'operatorNavProfile': 'சுயவிவரம்',
      'operatorNextStop': 'அடுத்த நிறுத்தம்',
      'operatorUpcomingStop': 'வரவிருக்கும் நிறுத்தம்',
      'operatorRouteLabel': 'பாதை',
      'operatorTapToScan': 'QR ஸ்கேன் செய்ய தட்டவும் / கழிவை சேகரிக்கவும்',
      'operatorLastCollected': 'கடைசி சேகரிப்பு',
      'operatorWet': 'ஈர',
      'operatorDry': 'உலர்',
      'operatorTime': 'நேரம்',
      'operatorAttendanceTitle': 'வருகை',
      'operatorAttendanceSubtitle': 'உங்கள் மாற்றத்துடன் ஒத்திசைவில் இருங்கள்',
      'operatorAttendanceOpen': 'வருகையைத் தொடங்கவும்',
      'operatorAttendanceToday': 'இன்று',
      'operatorAttendanceMonth': 'இந்த மாதம்',
      'operatorLeaveBalance': 'விடுப்பு இருப்பு',
      'operatorAttendanceStreak': 'வருகை தொடர்',
      'operatorAttendanceSummary': 'சுருக்கம்',
      'operatorAttendanceHistory': 'வரலாறு',
      'operatorAttendanceMark': 'குறியிடு',
      // ===== Attendance Screen =====
      'attendanceTitle': 'வருகை',
      'attendanceSubtitle': 'இன்றைய வருகை மற்றும் வரலாற்றை நிர்வகிக்கவும்',
      'presence': 'வருகை',
      'leaves': 'விடுப்பு',
      'permission': 'அனுமதி',
      'checkIn': 'செக் இன்',
      'checkOut': 'செக் அவுட்',
      'leave': 'விடுப்பு',
      'visit': 'சந்திப்பு',
      'overtime': 'மேல்நேரம்',
      'history': 'வரலாறு',
      'summary': 'சுருக்கம்',
      'punchAttendance': 'வருகையை பதிவு செய்',
      'pendingSync': 'நிலுவையில் உள்ள ஒத்திசைவு',
      'online': 'ஆன்லைன்',
      'offline': 'ஆஃப்லைன்',
      'noInternetSync': 'இணையம் இல்லை. ஒத்திசைக்க முடியாது.',
      'syncSuccess': 'வெற்றிகரமாக ஒத்திசைக்கப்பட்டது.',
      'syncFailed': 'ஒத்திசைவு தோல்வி.',
      'enableLocation': 'தயவுசெய்து இடம் சேவையை இயக்கவும்.',
      'locationPermissionRequired': 'இடம் அனுமதி தேவை.',
    },
  };

  String _translate(String key) {
    final languageMap =
        _localizedValues[locale.languageCode] ?? _localizedValues['en']!;
    return languageMap[key] ?? _localizedValues['en']![key] ?? key;
  }

  String get profileTitle => _translate('profileTitle');
  String get profileSubtitle => _translate('profileSubtitle');
  String greeting(String name) =>
      _translate('greeting').replaceAll('{name}', name);
  String get collectionDetails => _translate('collectionDetails');
  String get collectionHistory => _translate('collectionHistory');
  String get trackWaste => _translate('trackWaste');
  String get raiseGrievance => _translate('raiseGrievance');
  String get darkMode => _translate('darkMode');
  String get darkModeSubtitle => _translate('darkModeSubtitle');
  String get changeLanguage => _translate('changeLanguage');
  String get changeLanguageSubtitle => _translate('changeLanguageSubtitle');
  String languageSaved(String label) =>
      _translate('languageSaved').replaceAll('{label}', label);
  String get logout => _translate('logout');
  String get profileContactTitle => _translate('profileContactTitle');
  String get profileContactSubtitle => _translate('profileContactSubtitle');
  String get profilePhoneLabel => _translate('profilePhoneLabel');
  String get profileEmailLabel => _translate('profileEmailLabel');
  String get profileDesignationLabel => _translate('profileDesignationLabel');
  String get profileWardZoneLabel => _translate('profileWardZoneLabel');
  String get profileAttendanceTitle => _translate('profileAttendanceTitle');
  String get profileAttendanceSubtitle =>
      _translate('profileAttendanceSubtitle');
  String get profileEditButton => _translate('profileEditButton');

  String get homeTitle => _translate('homeTitle');
  String get quickActions => _translate('quickActions');
  String get notificationsLabel => _translate('notificationsLabel');
  String get notificationsCaughtUp => _translate('notificationsCaughtUp');
  String get notificationsWaiting => _translate('notificationsWaiting');

  String wasteCollectedLabel(String period) =>
      _translate('wasteCollected').replaceAll('{period}', period);
  String get noWasteRecorded => _translate('noWasteRecorded');

  String get trackHeaderTitle => _translate('trackHeaderTitle');
  String get trackLiveDescription => _translate('trackLiveDescription');
  String get trackChoosePeriod => _translate('trackChoosePeriod');
  String get trackDatePickerHelp => _translate('trackDatePickerHelp');
  String trackShowingPeriod(String period) =>
      _translate('trackShowingPeriod').replaceAll('{period}', period);
  String get trackLoading => _translate('trackLoading');
  String get trackNoData => _translate('trackNoData');
  String get trackRetry => _translate('trackRetry');

  String get wetWaste => _translate('wetWaste');
  String get dryWaste => _translate('dryWaste');
  String get mixedWaste => _translate('mixedWaste');
  String get metricWet => _translate('metricWet');
  String get metricDry => _translate('metricDry');
  String get metricMixed => _translate('metricMixed');
  String get metricTotal => _translate('metricTotal');
  String get metricTapCard => _translate('metricTapCard');
  String get metricTapBack => _translate('metricTapBack');

  String get calendarLabel => _translate('calendarLabel');
  String get allTime => _translate('allTime');
  String get periodDaily => _translate('periodDaily');
  String get periodMonthly => _translate('periodMonthly');
  String get periodTotal => _translate('periodTotal');
  String get collectionHistoryPageTitle =>
      _translate('collectionHistoryPageTitle');
  String get selectDateLabel => _translate('selectDateLabel');
  String viewingDateLabel(String date) =>
      _translate('viewingDateLabel').replaceAll('{date}', date);
  String collectionLogFor(String month) =>
      _translate('collectionLogFor').replaceAll('{month}', month);
  String totalWeightCollectedLabel(String weight) =>
      _translate('totalWeightCollectedLabel').replaceAll('{weight}', weight);
  String get noCollectionData => _translate('noCollectionData');
  String get noDetailedCollectionData => _translate('noDetailedCollectionData');
  String collectedAtLabel(String time) =>
      _translate('collectedAtLabel').replaceAll('{time}', time);
  String customerIdLabel(String id) =>
      _translate('customerIdLabel').replaceAll('{id}', id);
  String entryTotalWeightLabel(String weight) =>
      _translate('entryTotalWeightLabel').replaceAll('{weight}', weight);
  String get viewProofLabel => _translate('viewProofLabel');
  String get notRecorded => _translate('notRecorded');
  String get noProofImageAvailable => _translate('noProofImageAvailable');
  String get proofImageMissing => _translate('proofImageMissing');
  String get closeLabel => _translate('closeLabel');

  String get mapLiveHeadline => _translate('mapLiveHeadline');
  String mapVehicleHeadline(String vehicle) =>
      _translate('mapVehicleHeadline').replaceAll('{vehicle}', vehicle);
  String get mapRefreshingTelemetry => _translate('mapRefreshingTelemetry');
  String vehiclesActive(int count) {
    final suffix = count == 1 ? '' : 's';
    return _translate('mapVehiclesActive')
        .replaceAll('{count}', count.toString())
        .replaceAll('{pluralSuffix}', suffix);
  }

  String mapVehicleEnRoute(String vehicle) =>
      _translate('mapVehicleEnRoute').replaceAll('{vehicle}', vehicle);
  String get mapSearchHint => _translate('mapSearchHint');
  String get mapEstimatedLoad => _translate('mapEstimatedLoad');
  String get mapLastUpdate => _translate('mapLastUpdate');
  String get mapUnknownVehicle => _translate('mapUnknownVehicle');
  String get mapNoData => _translate('mapNoData');
  String get mapThemeStandard => _translate('mapThemeStandard');
  String get mapThemeLight => _translate('mapThemeLight');
  String get mapAssignedVehicle => _translate('mapAssignedVehicle');
  String get mapCollectorEnRoute => _translate('mapCollectorEnRoute');
  String get mapAwaitingAssignedVehicle =>
      _translate('mapAwaitingAssignedVehicle');
  String get mapLiveTelemetry => _translate('mapLiveTelemetry');
  String get mapNoLocationYet => _translate('mapNoLocationYet');
  String mapWaitingForCollector(String zone) =>
      _translate('mapWaitingForCollector').replaceAll('{zone}', zone);
  String mapVehicleCounts(int assigned, int total) =>
      _translate('mapVehicleCounts')
          .replaceAll('{assigned}', assigned.toString())
          .replaceAll('{total}', total.toString());
  String get mapGammaCollectionZone => _translate('mapGammaCollectionZone');

  String get tabHome => _translate('tabHome');
  String get tabTrack => _translate('tabTrack');
  String get tabMap => _translate('tabMap');
  String get tabProfile => _translate('tabProfile');
  String get attendanceTabHome => _translate('attendanceTabHome');
  String get attendanceTabMarkAttendance =>
      _translate('attendanceTabMarkAttendance');
  String get attendanceTabSummary => _translate('attendanceTabSummary');
  String get trackButtonLabel => _translate('trackButtonLabel');
  String get quickActionTrackVehicles => _translate('quickActionTrackVehicles');
  String get quickActionCollectionDetails =>
      _translate('quickActionCollectionDetails');
  String get quickActionCollectionHistory =>
      _translate('quickActionCollectionHistory');
  String get quickActionRaiseGrievance =>
      _translate('quickActionRaiseGrievance');
  String get quickActionRateCollector => _translate('quickActionRateCollector');
  String get quickActionQr => _translate('quickActionQr');
  String get quickActionUpcomingCollection =>
      _translate('quickActionUpcomingCollection');
  String get qrDialogTitle => _translate('qrDialogTitle');
  String get qrDialogSubtitle => _translate('qrDialogSubtitle');
  String get qrDialogLoginPrompt => _translate('qrDialogLoginPrompt');
  String get qrDialogDone => _translate('qrDialogDone');
  String get registrationSuccessTitle => _translate('registrationSuccessTitle');
  String get registrationComplete => _translate('registrationComplete');
  String welcomeMessage(String name) =>
      _translate('welcomeMessage').replaceAll('{name}', name);
  String get qrActivatedDescription => _translate('qrActivatedDescription');
  String get viewMyCollectionQr => _translate('viewMyCollectionQr');
  String get skipToDashboard => _translate('skipToDashboard');
  String get operatorLabel => _translate('operatorLabel');
  String operatorHeaderSubtitle(String name, String code) =>
      _translate('operatorHeaderSubtitle')
          .replaceAll('{name}', name)
          .replaceAll('{code}', code);
  String operatorWardZone(String ward, String zone) =>
      _translate('operatorWardZone')
          .replaceAll('{ward}', ward)
          .replaceAll('{zone}', zone);
  String get operatorNavHome => _translate('operatorNavHome');
  String get operatorNavOverview => _translate('operatorNavOverview');
  String get operatorNavAssignments => _translate('operatorNavAssignments');
  String get operatorNavAttendance => _translate('operatorNavAttendance');
  String get operatorNavProfile => _translate('operatorNavProfile');
  String get operatorNextStop => _translate('operatorNextStop');
  String get operatorUpcomingStop => _translate('operatorUpcomingStop');
  String get operatorRouteLabel => _translate('operatorRouteLabel');
  String get operatorTapToScan => _translate('operatorTapToScan');
  String get operatorLastCollected => _translate('operatorLastCollected');
  String get operatorWet => _translate('operatorWet');
  String get operatorDry => _translate('operatorDry');
  String get operatorTime => _translate('operatorTime');
  String get operatorAttendanceTitle => _translate('operatorAttendanceTitle');
  String get operatorAttendanceSubtitle =>
      _translate('operatorAttendanceSubtitle');
  String get operatorAttendanceOpen => _translate('operatorAttendanceOpen');
  String get operatorAttendanceToday => _translate('operatorAttendanceToday');
  String get operatorAttendanceMonth => _translate('operatorAttendanceMonth');
  String get operatorLeaveBalance => _translate('operatorLeaveBalance');
  String get operatorAttendanceStreak => _translate('operatorAttendanceStreak');
  String get operatorAttendanceSummary =>
      _translate('operatorAttendanceSummary');
  String get operatorAttendanceHistory =>
      _translate('operatorAttendanceHistory');
  String get operatorAttendanceMark => _translate('operatorAttendanceMark');

// ===== Attendance Screen Getters =====
  String get attendanceTitle => _translate('attendanceTitle');
  String get attendanceSubtitle => _translate('attendanceSubtitle');
  String get presence => _translate('presence');
  String get leaves => _translate('leaves');
  String get permission => _translate('permission');
  String get checkIn => _translate('checkIn');
  String get checkOut => _translate('checkOut');
  String get leave => _translate('leave');
  String get visit => _translate('visit');
  String get overtime => _translate('overtime');
  String get history => _translate('history');
  String get summary => _translate('summary');
  String get punchAttendance => _translate('punchAttendance');
  String get pendingSync => _translate('pendingSync');
  String get online => _translate('online');
  String get offline => _translate('offline');
  String get noInternetSync => _translate('noInternetSync');
  String get syncSuccess => _translate('syncSuccess');
  String get syncFailed => _translate('syncFailed');
  String get enableLocation => _translate('enableLocation');
  String get locationPermissionRequired =>
      _translate('locationPermissionRequired');

  String vehicleFilterLabel(VehicleFilter filter) {
    switch (filter) {
      case VehicleFilter.all:
        return _translate('vehicleFilterAll');
      case VehicleFilter.running:
        return _translate('vehicleFilterRunning');
      case VehicleFilter.idle:
        return _translate('vehicleFilterIdle');
      case VehicleFilter.parked:
        return _translate('vehicleFilterParked');
      case VehicleFilter.noData:
        return _translate('vehicleFilterNoData');
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
