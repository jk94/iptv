import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';

/// Settings: manage playlists (M3U / Xtream) and clear watch history.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Playlists',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (state.playlists.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Noch keine Playlist hinterlegt.'),
              ),
            )
          else
            for (final playlist in state.playlists) ...[
              _PlaylistTile(playlist: playlist),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _showAddPlaylistSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Playlist hinzufügen'),
          ),
          const SizedBox(height: 32),
          Text(
            'Verlauf',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Zuletzt gesehen löschen'),
              enabled: state.recents.isNotEmpty,
              onTap: () async {
                await context.read<AppState>().clearRecents();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verlauf gelöscht.')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'IPTV Player • Version 1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPlaylistSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddPlaylistSheet(),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          playlist.type == PlaylistType.m3u
              ? Icons.playlist_play_rounded
              : Icons.cloud_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(playlist.name),
        subtitle: Text(
          playlist.type == PlaylistType.m3u
              ? playlist.url ?? ''
              : playlist.host ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Entfernen',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Playlist entfernen?'),
        content: Text('„${playlist.name}" wird aus der App entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().removePlaylist(playlist.id);
    }
  }
}

/// Bottom sheet with tabs to add either an M3U URL or an Xtream account.
class _AddPlaylistSheet extends StatefulWidget {
  const _AddPlaylistSheet();

  @override
  State<_AddPlaylistSheet> createState() => _AddPlaylistSheetState();
}

class _AddPlaylistSheetState extends State<_AddPlaylistSheet> {
  final _formKey = GlobalKey<FormState>();
  PlaylistType _type = PlaylistType.m3u;

  final _name = TextEditingController();
  final _url = TextEditingController();
  final _host = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _host.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    if (_type == PlaylistType.m3u) {
      await state.addM3uPlaylist(
        name: _name.text.trim(),
        url: _url.text.trim(),
      );
    } else {
      await state.addXtreamPlaylist(
        name: _name.text.trim(),
        host: _host.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Pflichtfeld' : null;

  String? _validUrl(String? value) {
    if (_required(value) != null) return 'Pflichtfeld';
    final uri = Uri.tryParse(value!.trim());
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return 'Bitte eine gültige http(s)-URL eingeben';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Playlist hinzufügen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<PlaylistType>(
              segments: const [
                ButtonSegment(
                  value: PlaylistType.m3u,
                  label: Text('M3U-URL'),
                  icon: Icon(Icons.playlist_play_rounded),
                ),
                ButtonSegment(
                  value: PlaylistType.xtream,
                  label: Text('Xtream Codes'),
                  icon: Icon(Icons.cloud_outlined),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            if (_type == PlaylistType.m3u)
              TextFormField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Playlist-URL',
                  hintText: 'http://beispiel.de/playlist.m3u',
                ),
                keyboardType: TextInputType.url,
                validator: _validUrl,
              )
            else ...[
              TextFormField(
                controller: _host,
                decoration: const InputDecoration(
                  labelText: 'Server',
                  hintText: 'http://server:port',
                ),
                keyboardType: TextInputType.url,
                validator: _validUrl,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Benutzername'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Passwort'),
                obscureText: true,
                validator: _required,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
