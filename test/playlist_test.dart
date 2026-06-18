import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/models/models.dart';

void main() {
  group('Playlist', () {
    const base = Playlist(
      id: 'abc',
      name: 'Mein Anbieter',
      type: PlaylistType.xtream,
      host: 'http://server:8080',
      username: 'user',
      password: 'secret',
    );

    test('copyWith keeps id and replaces only given fields', () {
      final renamed = base.copyWith(name: 'Neuer Name');

      expect(renamed.id, base.id);
      expect(renamed.name, 'Neuer Name');
      expect(renamed.host, base.host);
      expect(renamed.username, base.username);
      expect(renamed.password, base.password);
      expect(renamed.type, base.type);
    });

    test('hasSameSource is true when only the name changes', () {
      expect(base.hasSameSource(base.copyWith(name: 'Anders')), isTrue);
    });

    test('hasSameSource is false when a credential changes', () {
      expect(base.hasSameSource(base.copyWith(password: 'neu')), isFalse);
      expect(base.hasSameSource(base.copyWith(host: 'http://x:1')), isFalse);
    });

    test('survives a JSON round trip', () {
      final restored = Playlist.fromJson(base.toJson());

      expect(restored.id, base.id);
      expect(restored.type, base.type);
      expect(restored.host, base.host);
      expect(restored.hasSameSource(base), isTrue);
    });
  });
}
