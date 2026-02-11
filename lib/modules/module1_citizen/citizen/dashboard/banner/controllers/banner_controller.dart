import 'dart:async';

import 'package:flutter/material.dart';

import '../models/banner_slide.dart';
import '../services/banner_service.dart';

class BannerController extends ChangeNotifier {
  BannerController({
    required BannerService service,
    List<BannerSlide>? fallbackSlides,
    Duration autoSlideInterval = const Duration(seconds: 5),
  })  : _service = service,
        _autoSlideInterval = autoSlideInterval {
    _slides = fallbackSlides ?? const [];
  }

  final BannerService _service;
  final Duration _autoSlideInterval;

  final PageController pageController = PageController(viewportFraction: 0.92);
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  Timer? _autoTimer;
  List<BannerSlide> _slides = const [];
  List<BannerSlide> get slides => _slides;

  Future<void> initialize() async {
    final cached = await _service.loadCached();
    if (cached.isNotEmpty) {
      _slides = cached;
      _currentIndex = 0;
      notifyListeners();
    }
    await refresh();
    _restartTimer();
  }

  Future<void> refresh() async {
    final remote = await _service.fetchRemote();
    if (remote.isNotEmpty) {
      _slides = remote;
      _currentIndex = 0;
      notifyListeners();
    }
  }

  void onPageChanged(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
    _restartTimer();
  }

  void _restartTimer() {
    _autoTimer?.cancel();
    if (_slides.length <= 1) return;
    _autoTimer = Timer.periodic(_autoSlideInterval, (_) {
      if (!pageController.hasClients || _slides.length <= 1) return;
      final nextPage = (_currentIndex + 1) % _slides.length;
      pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    pageController.dispose();
    super.dispose();
  }
}
