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
            onPressed: () => showPlaylistSheet(context),
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

}

/// Opens the bottom sheet to add a new playlist or, when [existing] is given,
/// to edit it.
void showPlaylistSheet(BuildContext context, {Playlist? existing}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlaylistSheet(existing: existing),
  );
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
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                showPlaylistSheet(context, existing: playlist);
              case 'reload':
                _reload(context);
              case 'delete':
                _confirmDelete(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Bearbeiten'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'reload',
              child: ListTile(
                leading: Icon(Icons.refresh_rounded),
                title: Text('Channels neu laden'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded),
                title: Text('Entfernen'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();
    messenger.showSnackBar(
      SnackBar(content: Text('„${playlist.name}" wird neu geladen…')),
    );
    try {
      final count = await appState.forceReload(playlist);
      messenger.showSnackBar(
        SnackBar(content: Text('$count Streams neu geladen.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Neu laden fehlgeschlagen.')),
      );
    }
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

/// Bottom sheet to add a new playlist or edit an existing one
/// (M3U URL or Xtream account).
class _PlaylistSheet extends StatefulWidget {
  final Playlist? existing;
  const _PlaylistSheet({this.existing});

  @override
  State<_PlaylistSheet> createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends State<_PlaylistSheet> {
  final _formKey = GlobalKey<FormState>();
  late PlaylistType _type;

  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _host;
  late final TextEditingController _username;
  late final TextEditingController _password;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? PlaylistType.m3u;
    _name = TextEditingController(text: existing?.name ?? '');
    _url = TextEditingController(text: existing?.url ?? '');
    _host = TextEditingController(text: existing?.host ?? '');
    _username = TextEditingController(text: existing?.username ?? '');
    _password = TextEditingController(text: existing?.password ?? '');
  }

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
    final existing = widget.existing;

    if (existing != null) {
      await state.updatePlaylist(existing.copyWith(
        name: _name.text.trim(),
        type: _type,
        url: _type == PlaylistType.m3u ? _url.text.trim() : null,
        host: _type == PlaylistType.xtream ? _host.text.trim() : null,
        username:
            _type == PlaylistType.xtream ? _username.text.trim() : null,
        password: _type == PlaylistType.xtream ? _password.text : null,
      ));
    } else if (_type == PlaylistType.m3u) {
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
              _isEditing ? 'Playlist bearbeiten' : 'Playlist hinzufügen',
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
