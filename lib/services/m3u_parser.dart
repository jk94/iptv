import '../models/models.dart';

/// Parses M3U/M3U8 playlists into [Channel] entries.
///
/// Reads `#EXTINF` lines including the common IPTV attributes
/// `tvg-logo` and `group-title` (used as category).
class M3uParser {
  static final _attrPattern = RegExp(r'([\w-]+)="([^"]*)"');

  static List<Channel> parse(String content) {
    final channels = <Channel>[];
    String? pendingName;
    String? pendingLogo;
    String? pendingGroup;

    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        final attrs = <String, String>{};
        for (final m in _attrPattern.allMatches(line)) {
          attrs[m.group(1)!.toLowerCase()] = m.group(2)!;
        }
        final commaIndex = line.lastIndexOf(',');
        pendingName = commaIndex >= 0 && commaIndex < line.length - 1
            ? line.substring(commaIndex + 1).trim()
            : attrs['tvg-name'];
        pendingLogo = attrs['tvg-logo'];
        pendingGroup = attrs['group-title'];
      } else if (line.startsWith('#EXTGRP:')) {
        pendingGroup = line.substring('#EXTGRP:'.length).trim();
      } else if (!line.startsWith('#')) {
        // A URL line completes the pending entry.
        channels.add(Channel(
          name: pendingName?.isNotEmpty == true ? pendingName! : line,
          url: line,
          category: pendingGroup?.isNotEmpty == true
              ? pendingGroup!
              : 'Ohne Kategorie',
          logoUrl: pendingLogo?.isNotEmpty == true ? pendingLogo : null,
        ));
        pendingName = null;
        pendingLogo = null;
        pendingGroup = null;
      }
    }
    return channels;
  }
}
