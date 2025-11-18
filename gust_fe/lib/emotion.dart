// emotion.dart

import 'package:flutter/material.dart';

enum Emotion {
  HAPPY,
  SAD,
  STRESSED,
  ANXIOUS,
  TIRED,
  BORED,
  NEUTRAL,
}

extension EmotionExtension on Emotion {
  String get label {
    switch (this) {
      case Emotion.HAPPY:
        return "Happy";
      case Emotion.SAD:
        return "Sad";
      case Emotion.STRESSED:
        return "Stressed";
      case Emotion.ANXIOUS:
        return "Anxious";
      case Emotion.TIRED:
        return "Tired";
      case Emotion.BORED:
        return "Bored";
      case Emotion.NEUTRAL:
        return "Neutral";
    }
  }

  // Using simple, universal emojis for better cross-platform compatibility
  String get emoji {
    switch (this) {
      case Emotion.HAPPY:
        return "??";
      case Emotion.SAD:
        return "??";
      case Emotion.STRESSED:
        return "??";
      case Emotion.ANXIOUS:
        return "??";
      case Emotion.TIRED:
        return "??";
      case Emotion.BORED:
        return "??";
      case Emotion.NEUTRAL:
        return "??";
    }
  }
  IconData get icon {
    switch (this) {
      case Emotion.HAPPY:
        return Icons.sentiment_very_satisfied;
      case Emotion.SAD:
        return Icons.sentiment_very_dissatisfied;
      case Emotion.STRESSED:
        return Icons.sentiment_dissatisfied;
      case Emotion.ANXIOUS:
        return Icons.sentiment_neutral;
      case Emotion.TIRED:
        return Icons.bedtime;
      case Emotion.BORED:
        return Icons.sentiment_satisfied;
      case Emotion.NEUTRAL:
        return Icons.sentiment_satisfied_alt;
    }
  }

  Color get color {
    switch (this) {
      case Emotion.HAPPY:
        return const Color(0xFF4CAF50); // Green
      case Emotion.SAD:
        return const Color(0xFF2196F3); // Blue
      case Emotion.STRESSED:
        return const Color(0xFFFF9800); // Orange
      case Emotion.ANXIOUS:
        return const Color(0xFFFF5722); // Deep Orange
      case Emotion.TIRED:
        return const Color(0xFF9C27B0); // Purple
      case Emotion.BORED:
        return const Color(0xFF607D8B); // Blue Grey
      case Emotion.NEUTRAL:
        return const Color(0xFF757575); // Grey
    }
  }
}


