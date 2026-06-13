import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yvl/models/muzo_item.dart';
import 'package:yvl/providers/player_provider.dart';
import 'package:yvl/screens/album_screen.dart';
import 'package:yvl/services/ytm_home.dart';
import 'package:yvl/utils/page_routes.dart';
import 'package:yvl/widgets/home_item_widget.dart';

class HomeSectionWidget extends StatelessWidget {
  final HomeSection section;

  const HomeSectionWidget({super.key, required this.section});

  bool get _isAlbumSection {
    if (section.items.isEmpty) return false;
    final albumCount = section.items.where((i) => i.type == 'album').length;
    return albumCount >= (section.items.length / 2).ceil();
  }

  bool get _isSongListSection {
    if (section.items.isEmpty) return false;
    final songCount = section.items.where((i) => i.videoId != null && i.type != 'album' && i.type != 'playlist').length;
    return songCount >= (section.items.length * 0.7).ceil();
  }

  @override
  Widget build(BuildContext context) {
    if (section.items.isEmpty) return const SizedBox.shrink();

    if (_isAlbumSection) return _buildAlbumSection(context);
    if (_isSongListSection) return _buildSongListSection(context);
    return _buildCarouselSection(context);
  }

  // ─── Standard horizontal carousel ───────────────────────────────────────────
  Widget _buildCarouselSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              return HomeItemWidget(item: section.items[index]);
            },
          ),
        ),
      ],
    );
  }

  // ─── Compact album grid (smaller 110px covers) ───────────────────────────────
  Widget _buildAlbumSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context),
        SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              return _CompactAlbumItem(item: section.items[index]);
            },
          ),
        ),
      ],
    );
  }

  // ─── Song list view (vertical) ───────────────────────────────────────────────
  Widget _buildSongListSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context),
        ...section.items.take(6).map((item) => _SongListTile(item: item)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 0.3,
            ),
          ),
          if (_isAlbumSection || _isSongListSection)
            Text(
              'Albums' , // tag label
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Compact album tile (110×110 cover + title below) ────────────────────────
class _CompactAlbumItem extends StatelessWidget {
  final HomeItem item;
  const _CompactAlbumItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (item.browseId != null) {
          Navigator.push(
            context,
            SlidePageRoute(
              page: AlbumScreen(
                albumId: item.browseId!,
                albumName: item.title,
                thumbnailUrl: item.thumbnailUrl,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _albumPlaceholder(context),
                      )
                    : _albumPlaceholder(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            if (item.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _albumPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        FluentIcons.album_24_regular,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }
}

// ─── Song list tile ──────────────────────────────────────────────────────────
class _SongListTile extends ConsumerWidget {
  final HomeItem item;
  const _SongListTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (item.videoId != null) {
          final muzoResult = MuzoItem(
            title: item.title,
            thumbnails: [
              if (item.thumbnailUrl != null)
                MuzoThumbnail(url: item.thumbnailUrl!, width: 500, height: 500),
            ],
            resultType: 'song',
            isExplicit: false,
            videoId: item.videoId,
            artists: item.subtitle != null
                ? [MuzoArtist(name: item.subtitle!, id: null)]
                : null,
          );
          ref.read(audioHandlerProvider).playVideo(muzoResult);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // Album art
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          FluentIcons.music_note_2_24_filled,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      )
                    : Icon(
                        FluentIcons.music_note_2_24_filled,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Play indicator
            Icon(
              FluentIcons.play_circle_24_regular,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
