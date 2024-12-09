
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

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

