import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class RoomPage extends StatefulWidget {
  final Room room;
  const RoomPage({required this.room, super.key});

  @override
  _RoomPageState createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final Future<Timeline> _timelineFuture;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final TextEditingController _sendController = TextEditingController();
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _timelineFuture = widget.room.getTimeline(
      onChange: (_) {
        // No explicit state refresh needed as AnimatedList handles changes
        print('on change!');
      },
      onInsert: (index) {
        print('on insert! $index');
        _listKey.currentState?.insertItem(index);
        _count++;
      },
      onRemove: (index) {
        print('On remove $index');
        _listKey.currentState?.removeItem(index, (context, animation) {
          return const ListTile();
        });
        _count--;
      },
      onUpdate: () => print('On update'),
    );
  }

  void _sendMessage() {
    final message = _sendController.text.trim();
    if (message.isNotEmpty) {
      widget.room.sendTextEvent(message);
      _sendController.clear();
    }
  }

  Widget _buildTimeline(Timeline timeline) {
    _count = timeline.events.length;
    final client = Provider.of<Client>(context, listen: false);

    return Column(
      children: [
        Center(
          child: TextButton(
            onPressed: timeline.requestHistory,
            child: const Text('Load more...'),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedList(
            key: _listKey,
            reverse: true,
            initialItemCount: timeline.events.length,
            itemBuilder: (context, index, animation) {
              final event = timeline.events[index];
              bool ownMessage = event.senderId == client.userID;
              // if (event.relationshipEventId != null) return Container();
              return Align(
                alignment:
                    ownMessage ? Alignment.centerRight : Alignment.centerLeft,
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.8,
                  child: Column(
                    children: [
                      if (event.relationshipType == RelationshipTypes.reply)
                        FutureBuilder<Event?>(
                          future: event.getReplyEvent(timeline),
                          builder: (
                            BuildContext context,
                            snapshot,
                          ) {
                            final replyEvent = snapshot.hasData
                                ? snapshot.data!
                                : Event(
                                    eventId: event.relationshipEventId!,
                                    content: {
                                      'msgtype': 'm.text',
                                      'body': '...',
                                    },
                                    senderId: event.senderId,
                                    type: 'm.room.message',
                                    room: event.room,
                                    status: EventStatus.sent,
                                    originServerTs: DateTime.now(),
                                  );
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: 4.0,
                              ),
                              child: AbsorbPointer(
                                child: ReplyContent(
                                  replyEvent,
                                  ownMessage: ownMessage,
                                  timeline: timeline,
                                ),
                              ),
                            );
                          },
                        ),
                      if (event.type == EventTypes.Message)
                        ScaleTransition(
                          scale: animation,
                          child: Opacity(
                            opacity: event.status.isSent ? 1 : 0.5,
                            child: ListTile(
                              leading: CircleAvatar(
                                foregroundImage: event
                                            .senderFromMemoryOrFallback
                                            .avatarUrl ==
                                        null
                                    ? null
                                    : NetworkImage(
                                        event.senderFromMemoryOrFallback
                                            .avatarUrl!
                                            .getThumbnailUri(widget.room.client,
                                                width: 56, height: 56)
                                            .toString(),
                                      ),
                              ),
                              title: Row(
                                children: [
                                  ownMessage
                                      ? const SizedBox()
                                      : Expanded(
                                          child: Text(
                                            event.senderFromMemoryOrFallback
                                                .calcDisplayname(),
                                          ),
                                        ),
                                  Text(
                                    event.originServerTs.toIso8601String(),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                  "${event.plaintextBody} | ${event.hashCode}"),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              );

              // return SizedBox();
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.getLocalizedDisplayname()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<Timeline>(
                future: _timelineFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(),
                    );
                  }
                  return _buildTimeline(snapshot.data!);
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sendController,
                      decoration: const InputDecoration(
                        hintText: 'Send message',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_outlined),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReplyContent extends StatelessWidget {
  final Event replyEvent;
  final bool ownMessage;
  final Timeline? timeline;
  final Color? backgroundColor;

  const ReplyContent(
    this.replyEvent, {
    this.ownMessage = false,
    super.key,
    this.timeline,
    this.backgroundColor,
  });

  static const BorderRadius borderRadius = BorderRadius.only(
    topRight: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final timeline = this.timeline;
    final displayEvent =
        timeline != null ? replyEvent.getDisplayEvent(timeline) : replyEvent;
    final fontSize = 18.0;
    final color = ownMessage
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.tertiary;

    return Material(
      color: backgroundColor ??
          theme.colorScheme.surface.withOpacity(ownMessage ? 0.2 : 0.33),
      borderRadius: borderRadius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 3,
            height: fontSize * 2 + 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FutureBuilder<User?>(
                  initialData: displayEvent.senderFromMemoryOrFallback,
                  future: displayEvent.fetchSenderUser(),
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data?.calcDisplayname() ?? displayEvent.senderFromMemoryOrFallback.calcDisplayname()}:',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: fontSize,
                      ),
                    );
                  },
                ),
                Text(
                  displayEvent.text,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: ownMessage
                        ? theme.colorScheme.onTertiary
                        : theme.colorScheme.onSurface,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
