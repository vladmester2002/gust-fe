// emotion.dart

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

  String get emoji {
    switch (this) {
      case Emotion.HAPPY:
        return "😃";
      case Emotion.SAD:
        return "😢";
      case Emotion.STRESSED:
        return "😫";
      case Emotion.ANXIOUS:
        return "😰";
      case Emotion.TIRED:
        return "😴";
      case Emotion.BORED:
        return "🥱";
      case Emotion.NEUTRAL:
        return "🙂";
    }
  }
}
