import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yvl/services/ytm_home.dart';
import 'package:yvl/services/storage_service.dart';

final ytmHomeServiceProvider = Provider<YouTubeMusicHomeService>((ref) {
  final service = YouTubeMusicHomeService();
  ref.onDispose(() => service.dispose());
  return service;
});

final homeSectionsProvider =
    AsyncNotifierProvider<HomeSectionsNotifier, List<HomeSection>>(() {
      return HomeSectionsNotifier();
    });

class HomeSectionsNotifier extends AsyncNotifier<List<HomeSection>> {
  @override
  Future<List<HomeSection>> build() async {
    final storage = ref.watch(storageServiceProvider);
    final cached = storage.getHomeCache();
    if (cached.isNotEmpty) {
      Future.delayed(Duration.zero, _refreshBackground);
      return cached;
    }
    final service = ref.watch(ytmHomeServiceProvider);
    await service.initialize();
    final fresh = await service.getHome(limit: 10);
    storage.setHomeCache(fresh);
    return fresh;
  }

  Future<void> _refreshBackground() async {
    try {
      final service = ref.read(ytmHomeServiceProvider);
      await service.initialize();
      final fresh = await service.getHome(limit: 10);
      ref.read(storageServiceProvider).setHomeCache(fresh);
      state = AsyncValue.data(fresh);
    } catch (e) {}
  }

  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final service = ref.read(ytmHomeServiceProvider);
      await service.initialize();
      final fresh = await service.getHome(limit: 10);
      ref.read(storageServiceProvider).setHomeCache(fresh);
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final homeFilterProvider = StateProvider<String>((ref) => 'All');

// Regional/Hindi content keywords to filter out
const _regionalKeywords = [
  'hindi', 'bollywood', 'bhojpuri', 'filmi', 'desi',
  'punjabi', 'haryanvi', 'regional', 'tamil', 'telugu',
  'malayalam', 'kannada', 'marathi', 'bengali', 'gujarati',
  'bhakti', 'devotional', 'carnatic',
];

final filteredHomeSectionsProvider = Provider<AsyncValue<List<HomeSection>>>((ref) {
  final homeSectionsAsync = ref.watch(homeSectionsProvider);
  final filter = ref.watch(homeFilterProvider);

  return homeSectionsAsync.whenData((sections) {
    // Always remove regional/Hindi sections
    var filtered = sections.where((s) {
      final title = s.title.toLowerCase();
      return !_regionalKeywords.any((kw) => title.contains(kw));
    }).toList();

    if (filter == 'All') return filtered;

    return filtered
        .map((section) {
          final filteredItems = section.items.where((item) {
            if (filter == 'Songs') {
              return item.type == 'song' || (item.videoId != null && item.type != 'album' && item.type != 'playlist');
            }
            if (filter == 'Albums') return item.type == 'album';
            if (filter == 'Playlists') return item.type == 'playlist';
            if (filter == 'Podcasts') {
              return item.type == 'podcast' || item.type == 'episode';
            }
            return false;
          }).toList();

          if (filteredItems.isEmpty) return null;
          return HomeSection(title: section.title, items: filteredItems);
        })
        .whereType<HomeSection>()
        .toList();
  });
});

// Artist info provider – searches YTM for real photos + browseId per artist name
final artistInfoProvider = FutureProvider.family<Map<String, String>?, String>((ref, artistName) async {
  try {
    final service = ref.read(ytmHomeServiceProvider);
    await service.initialize();
    return service.searchArtistInfo(artistName);
  } catch (_) {
    return null;
  }
});

// "For You" – personalized recommendations based on listening history
final forYouProvider = Provider<List<HomeItem>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final history = storage.getHistory();
  if (history.isEmpty) return [];

  // Count plays per artist
  final artistCount = <String, int>{};
  for (final song in history) {
    final artist = song.displayArtist;
    if (artist.isNotEmpty && artist != 'Unknown') {
      artistCount[artist] = (artistCount[artist] ?? 0) + 1;
    }
  }

  // Top 5 most-listened artists
  final topArtistNames = (artistCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(5)
      .map((e) => e.key)
      .toSet();

  // Build deduped recommendations: top-artist songs first, then others
  final seen = <String>{};
  final topSongs = <HomeItem>[];
  final otherSongs = <HomeItem>[];

  for (final song in history.reversed) {
    if (song.videoId == null || seen.contains(song.videoId)) continue;
    seen.add(song.videoId!);

    // Only show square-thumbnail (music) items
    final thumb = song.thumbnails.isNotEmpty ? song.thumbnails.last : null;
    if (thumb == null) continue;
    if (thumb.url.contains('i.ytimg.com')) continue; // Skip video thumbnails

    final item = HomeItem(
      title: song.title,
      subtitle: song.displayArtist,
      thumbnails: [{'url': thumb.url, 'width': 500, 'height': 500}],
      videoId: song.videoId,
      type: 'song',
    );

    if (topArtistNames.contains(song.displayArtist)) {
      topSongs.add(item);
    } else {
      otherSongs.add(item);
    }

    if (topSongs.length + otherSongs.length >= 20) break;
  }

  // Shuffle top songs slightly for freshness, combine
  return [...topSongs.take(8), ...otherSongs.take(4)];
});
