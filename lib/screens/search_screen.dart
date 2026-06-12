import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yvl/providers/search_provider.dart';
import 'package:yvl/widgets/result_tile.dart';
import 'package:yvl/models/muzo_item.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;

  static const List<_Genre> _genres = [
    _Genre('Chill',      Icons.waves_rounded,           0xFF0d1b2e, 0xFF1565C0),
    _Genre('Hip Hop',    Icons.graphic_eq_rounded,      0xFF1a0030, 0xFF6A1B9A),
    _Genre('Lo-Fi',      Icons.radio_rounded,           0xFF0d1f0d, 0xFF2E7D32),
    _Genre('Bollywood',  Icons.auto_awesome_rounded,    0xFF1f0e00, 0xFFE65100),
    _Genre('Trending',   Icons.trending_up_rounded,     0xFF1f0000, 0xFFC62828),
    _Genre('Pop',        Icons.music_note_rounded,      0xFF1f0020, 0xFF880E4F),
    _Genre('Rock',       Icons.electric_bolt_rounded,   0xFF111111, 0xFF424242),
    _Genre('K-Pop',      Icons.stars_rounded,           0xFF001025, 0xFF01579B),
    _Genre('Jazz',       Icons.piano_rounded,           0xFF1a1200, 0xFF6D4C41),
    _Genre('Electronic', Icons.flash_on_rounded,        0xFF001428, 0xFF006064),
    _Genre('Workout',    Icons.fitness_center_rounded,  0xFF1a0800, 0xFFBF360C),
    _Genre('Party',      Icons.celebration_rounded,     0xFF150020, 0xFF4A148C),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _showSuggestions = _searchController.text.isNotEmpty;
    });
  }

  void _performSearch(String query) {
    _searchController.text = query;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: query.length));
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
    ref.read(searchQueryProvider.notifier).state = query;
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final currentFilter = ref.watch(searchFilterProvider);
    final suggestionsAsync =
        ref.watch(searchSuggestionsProvider(_searchController.text));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.09)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  cursorColor: Theme.of(context).colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: 'Chill, Hip Hop, Bollywood...',
                    hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.38),
                    ),
                    filled: false,
                    prefixIcon: IconButton(
                      icon: Icon(
                        FluentIcons.arrow_left_24_regular,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        size: 22,
                      ),
                      onPressed: () {
                        ref.read(searchQueryProvider.notifier).state = '';
                        Navigator.pop(context);
                      },
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              FluentIcons.dismiss_circle_24_filled,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _focusNode.requestFocus();
                              setState(() => _showSuggestions = false);
                              ref.read(searchQueryProvider.notifier).state =
                                  '';
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: _performSearch,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            // ── Filter chips (only when query active) ──────────
            if (!_showSuggestions && query.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip('All', currentFilter, isDark),
                    _chip('Songs', currentFilter, isDark),
                    _chip('Videos', currentFilter, isDark),
                    _chip('Albums', currentFilter, isDark),
                    _chip('Artists', currentFilter, isDark),
                    _chip('Playlists', currentFilter, isDark),
                    _chip('Channels', currentFilter, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Content area ────────────────────────────────────
            Expanded(
              child: _showSuggestions
                  ? _buildSuggestions(suggestionsAsync)
                  : query.isEmpty
                      ? _buildBrowseCategories()
                      : _buildResults(searchResults, currentFilter),
            ),
          ],
        ),
      ),
    );
  }

  // ── Browse genre grid (shown when search is empty) ──────────────
  Widget _buildBrowseCategories() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            child: Text(
              'Browse',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final g = _genres[i];
                return _genreTile(g);
              },
              childCount: _genres.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }

  Widget _genreTile(_Genre g) {
    return GestureDetector(
      onTap: () => _performSearch(g.label),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(g.color1), Color(g.color2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(g.icon,
                  color: Colors.white.withValues(alpha: 0.85), size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  g.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Suggestions ─────────────────────────────────────────────────
  Widget _buildSuggestions(AsyncValue<List<String>> async) {
    return async.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return ListView.separated(
          padding: const EdgeInsets.only(top: 4),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox.shrink(),
          itemBuilder: (context, i) {
            final s = list[i];
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(FluentIcons.search_24_regular,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                  size: 18),
              title: Text(s,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15)),
              trailing: Icon(FluentIcons.arrow_up_left_24_regular,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                  size: 18),
              onTap: () => _performSearch(s),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ── Search results ───────────────────────────────────────────────
  Widget _buildResults(
      AsyncValue<List<MuzoItem>> searchResults, String currentFilter) {
    return searchResults.when(
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.music_note_2_24_regular,
                    size: 48,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.15)),
                const SizedBox(height: 16),
                Text('No results found',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        if (currentFilter == 'all') {
          final Map<String, List<MuzoItem>> grouped = {};
          for (final r in results) {
            grouped.putIfAbsent(r.category ?? 'Other', () => []).add(r);
          }
          const order = [
            'Songs', 'Videos', 'Albums', 'Artists', 'Playlists', 'Channels'
          ];
          final cats = grouped.keys.toList()
            ..sort((a, b) {
              final ia = order.indexOf(a);
              final ib = order.indexOf(b);
              if (ia != -1 && ib != -1) return ia.compareTo(ib);
              if (ia != -1) return -1;
              if (ib != -1) return 1;
              return a.compareTo(b);
            });

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 160),
            itemCount: cats.length,
            itemBuilder: (context, index) {
              final cat = cats[index];
              final items = grouped[cat]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat,
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3)),
                        if (order.contains(cat))
                          GestureDetector(
                            onTap: () => ref
                                .read(searchFilterProvider.notifier)
                                .state = cat.toLowerCase(),
                            child: Text('More',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                  ...items.take(4).map((r) => ResultTile(result: r)),
                ],
              );
            },
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 160),
          itemCount: results.length + 1,
          itemBuilder: (context, index) {
            if (index == results.length) {
              final notifier = ref.read(searchResultsProvider.notifier);
              if (!notifier.hasMore) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: TextButton(
                    onPressed: () => notifier.loadMore(),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: const Text('Load More'),
                  ),
                ),
              );
            }
            return ResultTile(result: results[index]);
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          strokeWidth: 2,
        ),
      ),
      error: (error, _) => Center(
        child: Text('Error: $error',
            style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _chip(String label, String currentFilter, bool isDark) {
    final isSelected = label.toLowerCase() == currentFilter.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () =>
            ref.read(searchFilterProvider.notifier).state =
                label.toLowerCase(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _Genre {
  final String label;
  final IconData icon;
  final int color1;
  final int color2;
  const _Genre(this.label, this.icon, this.color1, this.color2);
}
