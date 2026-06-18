import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/channel_logo.dart';
import 'player_screen.dart';

/// Lists the streams of one category; tapping a stream opens the player.
class ChannelsScreen extends StatefulWidget {
  final String playlistName;
  final String category;
  final List<Channel> channels;

  const ChannelsScreen({
    super.key,
    required this.playlistName,
    required this.category,
    required this.channels,
  });

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final channels = widget.channels
        .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Stream suchen…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: channels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final channel = channels[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: ChannelLogo(logoUrl: channel.logoUrl),
                    title: Text(
                      channel.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.play_circle_outline_rounded),
                    onTap: () {
                      // Navigate within the full category list so prev/next
                      // is not limited by the current search filter.
                      final startIndex = widget.channels.indexOf(channel);
                      PlayerScreen.open(
                        context,
                        channels: widget.channels,
                        initialIndex: startIndex >= 0 ? startIndex : 0,
                        playlistName: widget.playlistName,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
