import 'package:flutter/foundation.dart';

enum BottomNavItem { home, track, map, profile }

class HomeNavController extends ChangeNotifier {
  BottomNavItem active = BottomNavItem.home;

  void setItem(BottomNavItem item) {
    if (active == item) return;
    active = item;
    notifyListeners();
  }
}
