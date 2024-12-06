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
  Timeline? _timeline;
  final TextEditingController _sendController = TextEditingController();
  Event? _replyingToEvent;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    try {
      _timeline = await widget.room.getTimeline(
        onUpdate: () {
          if (mounted) setState(() {});
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading timeline: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _sendController.text.trim();
    if (message.isEmpty) return;

    try {
      String txnId = DateTime.now().millisecondsSinceEpoch.toString();

      if (_replyingToEvent != null) {
        await widget.room.client
            .sendMessage(widget.room.id, 'm.room.message', txnId, {
          'body': message,
          'msgtype': 'm.text',
          'm.relates_to': {
            'rel_type': 'm.in_reply_to',
            'event_id': _replyingToEvent!.eventId,
          }
        });

        setState(() {
          _replyingToEvent = null;
        });
      } else {
        await widget.room.client
            .sendMessage(widget.room.id, 'm.room.message', txnId, {
          'body': message,
          'msgtype': 'm.text',
        });
      }
      _sendController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  void _startReply(Event event) {
    setState(() {
      _replyingToEvent = event;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToEvent = null;
    });
  }

  Widget _buildMessageBubble(Event event, bool ownMessage) {
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPress: () => _startReply(event),
      child: Align(
        alignment: ownMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              ownMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (event.relationshipType == RelationshipTypes.reply)
              FutureBuilder<Event?>(
                future: event.getReplyEvent(_timeline!),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: ReplyContent(
                        snapshot.data!,
                        ownMessage: ownMessage,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ownMessage
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      ownMessage ? const Radius.circular(16) : Radius.zero,
                  bottomRight:
                      ownMessage ? Radius.zero : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!ownMessage)
                    Text(
                      event.senderFromMemoryOrFallback.calcDisplayname(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    event.plaintextBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ownMessage
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.originServerTs.toIso8601String().substring(11, 16),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingToEvent == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingToEvent!.senderFromMemoryOrFallback.calcDisplayname()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  _replyingToEvent!.plaintextBody,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.room.getLocalizedDisplayname(),
          style: theme.textTheme.titleMedium,
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _timeline == null
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : ListView.builder(
                      reverse: true,
                      itemCount: _timeline!.events.length,
                      itemBuilder: (context, index) {
                        final event = _timeline!.events[index];

                        if (event.type != EventTypes.Message)
                          return const SizedBox.shrink();

                        return _buildMessageBubble(
                            event, event.senderId == widget.room.client.userID);
                      },
                    ),
            ),
            _buildReplyPreview(),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sendController,
                      decoration: InputDecoration(
                        hintText: _replyingToEvent != null
                            ? 'Reply to message'
                            : 'Send message',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: IconButton(
                      icon: Icon(Icons.send_outlined,
                          color: theme.colorScheme.onPrimary),
                      onPressed: _sendMessage,
                    ),
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
  final Color? backgroundColor;

  const ReplyContent(
    this.replyEvent, {
    this.ownMessage = false,
    super.key,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = ownMessage
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.tertiary;

    return Material(
      color: backgroundColor ??
          theme.colorScheme.surface.withOpacity(ownMessage ? 0.2 : 0.33),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 3,
            height: 40,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  replyEvent.senderFromMemoryOrFallback.calcDisplayname(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  replyEvent.plaintextBody,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
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
