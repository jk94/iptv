import 'dart:convert';

/// Type of a stored playlist source.
enum PlaylistType { m3u, xtream }

/// A playlist source configured by the user (M3U URL or Xtream account).
class Playlist {
  final String id;
  final String name;
  final PlaylistType type;

  /// M3U: the playlist URL.
  final String? url;

  /// Xtream: server base URL (e.g. http://host:port), username, password.
  final String? host;
  final String? username;
  final String? password;

  const Playlist({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.host,
    this.username,
    this.password,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'url': url,
        'host': host,
        'username': username,
        'password': password,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        type: PlaylistType.values.byName(json['type'] as String),
        url: json['url'] as String?,
        host: json['host'] as String?,
        username: json['username'] as String?,
        password: json['password'] as String?,
      );
}

/// A single stream entry inside a playlist.
class Channel {
  final String name;
  final String url;
  final String category;
  final String? logoUrl;

  const Channel({
    required this.name,
    required this.url,
    required this.category,
    this.logoUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'category': category,
        'logoUrl': logoUrl,
      };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        name: json['name'] as String,
        url: json['url'] as String,
        category: json['category'] as String,
        logoUrl: json['logoUrl'] as String?,
      );
}

/// A recently watched stream, kept for the home screen quick access.
class RecentEntry {
  final Channel channel;
  final String playlistName;
  final DateTime watchedAt;

  const RecentEntry({
    required this.channel,
    required this.playlistName,
    required this.watchedAt,
  });

  Map<String, dynamic> toJson() => {
        'channel': channel.toJson(),
        'playlistName': playlistName,
        'watchedAt': watchedAt.toIso8601String(),
      };

  factory RecentEntry.fromJson(Map<String, dynamic> json) => RecentEntry(
        channel: Channel.fromJson(json['channel'] as Map<String, dynamic>),
        playlistName: json['playlistName'] as String,
        watchedAt: DateTime.parse(json['watchedAt'] as String),
      );

  static String encodeList(List<RecentEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<RecentEntry> decodeList(String raw) => (jsonDecode(raw) as List)
      .map((e) => RecentEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}
