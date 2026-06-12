import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'm3u_parser.dart';

/// Loads the channels of a [Playlist] from its source
/// (M3U URL or Xtream Codes API).
class PlaylistLoader {
  static const _timeout = Duration(seconds: 20);

  Future<List<Channel>> load(Playlist playlist) {
    switch (playlist.type) {
      case PlaylistType.m3u:
        return _loadM3u(playlist);
      case PlaylistType.xtream:
        return _loadXtream(playlist);
    }
  }

  Future<List<Channel>> _loadM3u(Playlist playlist) async {
    final response =
        await http.get(Uri.parse(playlist.url!)).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Playlist konnte nicht geladen werden '
          '(HTTP ${response.statusCode})');
    }
    final channels = M3uParser.parse(utf8.decode(response.bodyBytes,
        allowMalformed: true));
    if (channels.isEmpty) {
      throw Exception('Die Playlist enthält keine Streams.');
    }
    return channels;
  }

  Future<List<Channel>> _loadXtream(Playlist playlist) async {
    final host = playlist.host!.replaceFirst(RegExp(r'/+$'), '');
    final base = '$host/player_api.php'
        '?username=${Uri.encodeQueryComponent(playlist.username!)}'
        '&password=${Uri.encodeQueryComponent(playlist.password!)}';

    final categoriesJson =
        await _getJson('$base&action=get_live_categories') as List;
    final categoryNames = <String, String>{
      for (final c in categoriesJson)
        (c['category_id']).toString(): (c['category_name'] ?? '') as String,
    };

    final streamsJson =
        await _getJson('$base&action=get_live_streams') as List;

    return streamsJson.map((s) {
      final streamId = s['stream_id'];
      final categoryId = (s['category_id'])?.toString();
      final logo = s['stream_icon'] as String?;
      return Channel(
        name: (s['name'] ?? 'Unbenannt') as String,
        url: '$host/live/${playlist.username}/${playlist.password}/'
            '$streamId.m3u8',
        category: categoryNames[categoryId] ?? 'Ohne Kategorie',
        logoUrl: logo != null && logo.isNotEmpty ? logo : null,
      );
    }).toList();
  }

  Future<dynamic> _getJson(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Xtream-Server antwortet nicht '
          '(HTTP ${response.statusCode})');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
