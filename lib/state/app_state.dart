import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/playlist_loader.dart';

/// Central app state: configured playlists, loaded channels per playlist
/// and the recently watched streams. Persisted via [SharedPreferences].
class AppState extends ChangeNotifier {
  static const _playlistsKey = 'playlists';
  static const _recentsKey = 'recents';
  static const _maxRecents = 10;

  static String _channelsKey(String playlistId) => 'channels_$playlistId';

  final PlaylistLoader _loader = PlaylistLoader();
  final Map<String, List<Channel>> _channelCache = {};

  List<Playlist> _playlists = [];
  List<RecentEntry> _recents = [];
  bool _initialized = false;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<RecentEntry> get recents => List.unmodifiable(_recents);
  bool get initialized => _initialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rawPlaylists = prefs.getString(_playlistsKey);
    if (rawPlaylists != null) {
      _playlists = (jsonDecode(rawPlaylists) as List)
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final rawRecents = prefs.getString(_recentsKey);
    if (rawRecents != null) {
      _recents = RecentEntry.decodeList(rawRecents);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> addM3uPlaylist({required String name, required String url}) {
    return _addPlaylist(Playlist(
      id: const Uuid().v4(),
      name: name,
      type: PlaylistType.m3u,
      url: url,
    ));
  }

  Future<void> addXtreamPlaylist({
    required String name,
    required String host,
    required String username,
    required String password,
  }) {
    return _addPlaylist(Playlist(
      id: const Uuid().v4(),
      name: name,
      type: PlaylistType.xtream,
      host: host,
      username: username,
      password: password,
    ));
  }

  Future<void> _addPlaylist(Playlist playlist) async {
    _playlists = [..._playlists, playlist];
    notifyListeners();
    await _savePlaylists();
  }

  /// Updates an existing playlist. If the source (URL/credentials) changed,
  /// the cached channels are invalidated so they get reloaded.
  Future<void> updatePlaylist(Playlist updated) async {
    final index = _playlists.indexWhere((p) => p.id == updated.id);
    if (index < 0) return;
    final previous = _playlists[index];
    final next = [..._playlists];
    next[index] = updated;
    _playlists = next;

    if (!previous.hasSameSource(updated)) {
      await _invalidateChannelCache(updated.id);
    }
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> removePlaylist(String id) async {
    _playlists = _playlists.where((p) => p.id != id).toList();
    await _invalidateChannelCache(id);
    notifyListeners();
    await _savePlaylists();
  }

  /// Loads the channels of a playlist.
  ///
  /// Order of lookup (unless [refresh] is set): in-memory cache, then the
  /// persistent cache from a previous session, then the network. A network
  /// load always updates both caches so a restart can reuse them.
  Future<List<Channel>> channelsFor(Playlist playlist,
      {bool refresh = false}) async {
    if (!refresh) {
      final memory = _channelCache[playlist.id];
      if (memory != null) return memory;

      final cached = await _loadCachedChannels(playlist.id);
      if (cached != null && cached.isNotEmpty) {
        _channelCache[playlist.id] = cached;
        return cached;
      }
    }

    final channels = await _loader.load(playlist);
    _channelCache[playlist.id] = channels;
    await _saveChannels(playlist.id, channels);
    return channels;
  }

  /// Forces a network reload of the channels and refreshes the cache.
  /// Returns the number of channels loaded.
  Future<int> forceReload(Playlist playlist) async {
    final channels = await channelsFor(playlist, refresh: true);
    notifyListeners();
    return channels.length;
  }

  Future<List<Channel>?> _loadCachedChannels(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_channelsKey(playlistId));
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Channel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveChannels(String playlistId, List<Channel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _channelsKey(playlistId),
      jsonEncode(channels.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _invalidateChannelCache(String playlistId) async {
    _channelCache.remove(playlistId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_channelsKey(playlistId));
  }

  /// Category names of a loaded playlist, in order of first appearance.
  static List<String> categoriesOf(List<Channel> channels) {
    final seen = <String>{};
    final categories = <String>[];
    for (final c in channels) {
      if (seen.add(c.category)) categories.add(c.category);
    }
    return categories;
  }

  Future<void> addRecent(Channel channel, String playlistName) async {
    _recents = [
      RecentEntry(
        channel: channel,
        playlistName: playlistName,
        watchedAt: DateTime.now(),
      ),
      ..._recents.where((r) => r.channel.url != channel.url),
    ].take(_maxRecents).toList();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentsKey, RecentEntry.encodeList(_recents));
  }

  Future<void> clearRecents() async {
    _recents = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentsKey);
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _playlistsKey,
      jsonEncode(_playlists.map((p) => p.toJson()).toList()),
    );
  }
}
