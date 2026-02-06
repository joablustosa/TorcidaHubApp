import 'package:shared_preferences/shared_preferences.dart';

const String _keyViewedEventStoryFanClubIds = 'viewed_event_story_fan_club_ids';

/// Marca torcidas cujos stories foram visualizados pelo usuário.
class ViewedStoriesService {
  /// Salva os IDs de torcidas que o usuário visualizou na tela de stories.
  static Future<void> markViewed(Iterable<String> fanClubIds) async {
    if (fanClubIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_keyViewedEventStoryFanClubIds) ?? [];
    final set = current.toSet()..addAll(fanClubIds);
    await prefs.setStringList(_keyViewedEventStoryFanClubIds, set.toList());
  }

  /// Retorna o conjunto de IDs de torcidas já visualizados.
  static Future<Set<String>> getViewedFanClubIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyViewedEventStoryFanClubIds) ?? [];
    return list.toSet();
  }
}
