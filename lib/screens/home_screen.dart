import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/channel_logo.dart';
import 'categories_screen.dart';
import 'player_screen.dart';

/// Start page: recently watched streams and the playlist overview.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('IPTV Player')),
      body: !state.initialized
          ? const Center(child: CircularProgressIndicator())
          : state.playlists.isEmpty && state.recents.isEmpty
              ? const _EmptyHome()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (state.recents.isNotEmpty) ...[
                      const _SectionTitle('Zuletzt gesehen'),
                      const SizedBox(height: 12),
                      _RecentsRow(recents: state.recents),
                      const SizedBox(height: 24),
                    ],
                    const _SectionTitle('Meine Playlists'),
                    const SizedBox(height: 12),
                    if (state.playlists.isEmpty)
                      const _NoPlaylistsHint()
                    else
                      for (final playlist in state.playlists) ...[
                        _PlaylistCard(playlist: playlist),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _RecentsRow extends StatelessWidget {
  final List<RecentEntry> recents;
  const _RecentsRow({required this.recents});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final entry = recents[index];
          return SizedBox(
            width: 130,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => PlayerScreen.open(
                  context,
                  channels: [entry.channel],
                  initialIndex: 0,
                  playlistName: entry.playlistName,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChannelLogo(logoUrl: entry.channel.logoUrl, size: 56),
                      const Spacer(),
                      Text(
                        entry.channel.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlaylistCard extends StatefulWidget {
  final Playlist playlist;
  const _PlaylistCard({required this.playlist});

  @override
  State<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<_PlaylistCard> {
  bool _reloading = false;

  Future<void> _reload() async {
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();
    setState(() => _reloading = true);
    try {
      final count = await appState.forceReload(widget.playlist);
      messenger.showSnackBar(
        SnackBar(content: Text('$count Streams neu geladen.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Neu laden fehlgeschlagen.')),
      );
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playlist = widget.playlist;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.15),
          child: Icon(
            playlist.type == PlaylistType.m3u
                ? Icons.playlist_play_rounded
                : Icons.cloud_outlined,
            color: scheme.primary,
          ),
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          playlist.type == PlaylistType.m3u ? 'M3U-Playlist' : 'Xtream Codes',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Channels neu laden',
              icon: _reloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: _reloading ? null : _reload,
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoriesScreen(playlist: playlist),
          ),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.live_tv_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Willkommen!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Füge in den Einstellungen eine Playlist hinzu, '
              'um mit dem Streamen zu beginnen.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPlaylistsHint extends StatelessWidget {
  const _NoPlaylistsHint();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Noch keine Playlist hinterlegt. '
          'Du kannst Playlists in den Einstellungen hinzufügen.',
        ),
      ),
    );
  }
}
