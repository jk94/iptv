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

  Future<void> removePlaylist(String id) async {
    _playlists = _playlists.where((p) => p.id != id).toList();
    _channelCache.remove(id);
    notifyListeners();
    await _savePlaylists();
  }

  /// Loads (and caches) the channels of a playlist.
  Future<List<Channel>> channelsFor(Playlist playlist,
      {bool refresh = false}) async {
    if (!refresh && _channelCache.containsKey(playlist.id)) {
      return _channelCache[playlist.id]!;
    }
    final channels = await _loader.load(playlist);
    _channelCache[playlist.id] = channels;
    return channels;
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
