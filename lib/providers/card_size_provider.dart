import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CardSize { small, medium, large }

extension CardSizeExt on CardSize {
  double get maxExtent {
    switch (this) {
      case CardSize.small:
        return 160;
      case CardSize.medium:
        return 200;
      case CardSize.large:
        return 280;
    }
  }
}

class CardSizeNotifier extends Notifier<CardSize> {
  @override
  CardSize build() => CardSize.medium;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('card_size');
    if (saved != null) {
      state = CardSize.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => CardSize.medium,
      );
    }
  }

  Future<void> setSize(CardSize size) async {
    state = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('card_size', size.name);
  }
}

final cardSizeProvider = NotifierProvider<CardSizeNotifier, CardSize>(
  CardSizeNotifier.new,
);
