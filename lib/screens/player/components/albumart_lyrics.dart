import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:yvl/services/lyrics_service.dart';
import 'package:yvl/widgets/lyrics_view.dart';
import 'package:yvl/widgets/bubble_lyrics_view.dart';
import 'package:yvl/widgets/karaoke_view.dart';
import 'package:yvl/providers/theme_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:yvl/providers/player_provider.dart';

enum _LyricsMode { lineByLine, karaoke, bubble, plain }

class AlbumArtNLyrics extends ConsumerStatefulWidget {
  final double playerArtImageSize;
  const AlbumArtNLyrics({super.key, required this.playerArtImageSize});

  @override
  ConsumerState<AlbumArtNLyrics> createState() => _AlbumArtNLyricsState();
}

class _AlbumArtNLyricsState extends ConsumerState<AlbumArtNLyrics> {
  bool _showLyrics = false;
  bool _isLoadingLyrics = false;
  Lyrics? _lyrics;
  String? _lastFetchedTitle;
  _LyricsMode _lyricsMode = _LyricsMode.lineByLine;
  int _reSyncCount = 0; // Increments to force lyric scroll-to-current

  Future<void> _fetchLyrics(MediaItem mediaItem) async {
    if (_lyrics != null && _lastFetchedTitle == mediaItem.title) return;
    if (_isLoadingLyrics) return;
    if (mounted) setState(() => _isLoadingLyrics = true);
    try {
      final lyrics = await ref
          .read(lyricsServiceProvider)
          .fetchLyrics(
            mediaItem.title,
            mediaItem.artist ?? '',
            mediaItem.duration?.inSeconds ??
                ref.read(audioHandlerProvider).player.duration?.inSeconds ??
                0,
          );
      if (mounted) {
        setState(() {
          _lyrics = lyrics;
          _lastFetchedTitle = mediaItem.title;
          _isLoadingLyrics = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLyrics = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    // Auto-prefetch lyrics when song changes
    ref.listen(currentMediaItemProvider, (previous, next) {
      next.whenData((mediaItem) {
        if (mediaItem != null && mediaItem.title != _lastFetchedTitle) {
          if (mounted) setState(() { _lyrics = null; });
          _fetchLyrics(mediaItem);
        }
      });
    });

    final safeSize = widget.playerArtImageSize.clamp(10.0, double.infinity);
    final accent = ref.watch(currentPaletteProvider).asData?.value?.darkVibrantColor?.color ?? Colors.white;

    return SizedBox(
      width: safeSize,
      height: safeSize,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 15)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Album Art
              mediaItemAsync.when(
                data: (mediaItem) {
                  if (mediaItem?.artUri == null) return Container(color: Colors.grey[900]);
                  return CachedNetworkImage(
                    imageUrl: mediaItem!.artUri.toString().replaceAll(RegExp(r'w\d+-h\d+'), 'w800-h800'),
                    fit: BoxFit.cover,
                    width: widget.playerArtImageSize,
                    height: widget.playerArtImageSize,
                    errorWidget: (_, __, ___) => Icon(Icons.music_note, size: 50, color: Theme.of(context).colorScheme.onSurface),
                  );
                },
                loading: () => Container(color: Colors.grey[900]),
                error: (_, __) => Container(color: Colors.grey[900], child: const Icon(Icons.error)),
              ),

              // Lyrics Overlay
              if (_showLyrics)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        color: (Theme.of(context).brightness == Brightness.dark
                                ? Colors.black
                                : Colors.white)
                            .withValues(alpha: 0.50),
                        child: Column(
                          children: [
                            // Mode selector + close button
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // 4 Mode buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ModePill(
                                        icon: FluentIcons.text_align_left_24_regular,
                                        label: 'Line',
                                        active: _lyricsMode == _LyricsMode.lineByLine,
                                        onTap: () => setState(() => _lyricsMode = _LyricsMode.lineByLine),
                                        accent: accent,
                                      ),
                                      _ModePill(
                                        icon: FluentIcons.mic_24_regular,
                                        label: 'Karaoke',
                                        active: _lyricsMode == _LyricsMode.karaoke,
                                        onTap: () => setState(() => _lyricsMode = _LyricsMode.karaoke),
                                        accent: accent,
                                      ),
                                      _ModePill(
                                        icon: FluentIcons.chat_bubbles_question_24_regular,
                                        label: 'Bubble',
                                        active: _lyricsMode == _LyricsMode.bubble,
                                        onTap: () => setState(() => _lyricsMode = _LyricsMode.bubble),
                                        accent: accent,
                                      ),
                                      _ModePill(
                                        icon: FluentIcons.document_text_24_regular,
                                        label: 'Plain',
                                        active: _lyricsMode == _LyricsMode.plain,
                                        onTap: () => setState(() => _lyricsMode = _LyricsMode.plain),
                                        accent: accent,
                                      ),
                                    ],
                                  ),
                                  // Re-sync + Close buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(() => _reSyncCount++),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(FluentIcons.arrow_sync_20_regular, size: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => _showLyrics = false),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.close_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Lyrics content
                            Expanded(
                              child: _isLoadingLyrics
                                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface))
                                  : _lyrics == null
                                      ? Center(child: Text('No lyrics found', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))
                                      : _buildModeContent(_lyrics!, audioHandler, accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Lyrics Button (shown when lyrics panel is closed)
              if (!_showLyrics)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              final mediaItem = mediaItemAsync.value;
                              if (mediaItem != null) {
                                setState(() => _showLyrics = true);
                                _fetchLyrics(mediaItem);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isLoadingLyrics)
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    )
                                  else
                                    Icon(FluentIcons.text_quote_20_filled,
                                        color: Theme.of(context).colorScheme.onSurface, size: 16),
                                  const SizedBox(width: 8),
                                  Text('Lyrics', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeContent(Lyrics lyrics, dynamic audioHandler, Color accent) {
    switch (_lyricsMode) {
      case _LyricsMode.lineByLine:
        return LyricsView(
          key: ValueKey('lyrics_line_$_reSyncCount'),
          lyrics: lyrics,
          onClose: () => setState(() => _showLyrics = false),
          positionStream: audioHandler.player.positionStream,
          totalDuration: audioHandler.player.duration ?? Duration.zero,
          isEmbedded: true,
          accentColor: accent,
        );
      case _LyricsMode.karaoke:
        if (lyrics.karaokeLines != null && lyrics.karaokeLines!.isNotEmpty) {
          return KaraokeView(
            lines: lyrics.karaokeLines!,
            positionStream: audioHandler.player.positionStream,
            isEmbedded: true,
          );
        }
        // Fallback to line-by-line if no karaoke data
        return LyricsView(
          lyrics: lyrics,
          onClose: () => setState(() => _showLyrics = false),
          positionStream: audioHandler.player.positionStream,
          totalDuration: audioHandler.player.duration ?? Duration.zero,
          isEmbedded: true,
          accentColor: accent,
        );
      case _LyricsMode.bubble:
        return BubbleLyricsView(
          syncedLyrics: lyrics.syncedLyrics,
          plainLyrics: lyrics.plainLyrics,
          positionStream: audioHandler.player.positionStream,
          accentColor: accent,
        );
      case _LyricsMode.plain:
        return _PlainLyricsView(
          text: lyrics.plainLyrics.isNotEmpty ? lyrics.plainLyrics : lyrics.syncedLyrics,
          onClose: () => setState(() => _showLyrics = false),
        );
    }
  }
}

// ────────────────────────────────────────────────────────
// Mode pill button
// ────────────────────────────────────────────────────────
class _ModePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color accent;

  const _ModePill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? accent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// Plain lyrics view — static scrollable text
// ────────────────────────────────────────────────────────
class _PlainLyricsView extends StatelessWidget {
  final String text;
  final VoidCallback onClose;
  const _PlainLyricsView({required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d+\]'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return Center(
        child: Text('No lyrics available', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: lines.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          lines[i],
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
