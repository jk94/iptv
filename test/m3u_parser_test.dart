import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/services/m3u_parser.dart';

void main() {
  group('M3uParser', () {
    test('parses entries with group-title and tvg-logo', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="ard" tvg-logo="http://logo/ard.png" group-title="Vollprogramm",Das Erste
http://stream.example/ard.m3u8
#EXTINF:-1 group-title="Sport",Sport1
http://stream.example/sport1.m3u8
''';

      final channels = M3uParser.parse(playlist);

      expect(channels, hasLength(2));
      expect(channels[0].name, 'Das Erste');
      expect(channels[0].url, 'http://stream.example/ard.m3u8');
      expect(channels[0].category, 'Vollprogramm');
      expect(channels[0].logoUrl, 'http://logo/ard.png');
      expect(channels[1].category, 'Sport');
      expect(channels[1].logoUrl, isNull);
    });

    test('falls back to default category and url as name', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1,
http://stream.example/unknown.m3u8
''';

      final channels = M3uParser.parse(playlist);

      expect(channels, hasLength(1));
      expect(channels[0].name, 'http://stream.example/unknown.m3u8');
      expect(channels[0].category, 'Ohne Kategorie');
    });

    test('supports #EXTGRP category lines', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1,News Channel
#EXTGRP:Nachrichten
http://stream.example/news.m3u8
''';

      final channels = M3uParser.parse(playlist);

      expect(channels.single.category, 'Nachrichten');
      expect(channels.single.name, 'News Channel');
    });

    test('ignores comment lines and blank lines', () {
      const playlist = '''
#EXTM3U

#EXTINF:-1 group-title="Musik",MTV
#EXTVLCOPT:http-user-agent=Test
http://stream.example/mtv.m3u8
''';

      final channels = M3uParser.parse(playlist);

      expect(channels.single.name, 'MTV');
      expect(channels.single.category, 'Musik');
    });
  });
}
