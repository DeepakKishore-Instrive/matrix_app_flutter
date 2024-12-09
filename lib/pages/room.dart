import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/pages/room_details.dart';
import 'package:flutter_application_2/pages/video_player_screen.dart';
import 'package:flutter_application_2/widgets/mx_image.dart';
import 'package:flutter_application_2/widgets/reply_content.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
      _showErrorSnackBar('Error loading timeline: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _sendMessage({
    String? body,
    String msgType = 'm.text',
    String? url,
    String? filename,
  }) async {
    try {
      final txnId = DateTime.now().millisecondsSinceEpoch.toString();

      // Prepare message content
      final content = <String, dynamic>{
        'body': body ?? _sendController.text.trim(),
        'msgtype': msgType,
      };

      // Add file-related info if sending a file
      if (url != null) {
        content['url'] = url;
        if (filename != null) content['filename'] = filename;
      }

      // Handle reply if applicable
      if (_replyingToEvent != null) {
        content['m.relates_to'] = {
          'rel_type': 'm.in_reply_to',
          'event_id': _replyingToEvent!.eventId,
        };
      }

      // Send the message
      await widget.room.client
          .sendMessage(widget.room.id, 'm.room.message', txnId, content);

      // Reset UI state
      _sendController.clear();
      setState(() {
        _replyingToEvent = null;
      });
    } catch (e) {
      _showErrorSnackBar('Error sending message: $e');
    }
  }

  Future<void> _sendImageMessage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);

        // Show loading dialog
        _showLoadingDialog();

        // Upload file to Matrix
        final matrixFile = await _uploadMatrixFile(file);

        // Close loading dialog
        Navigator.of(context).pop();

        // Send image message
        await _sendMessage(
          body: path.basename(pickedFile.path),
          msgType: 'm.image',
          url: matrixFile.toString(),
          filename: path.basename(pickedFile.path),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error sending image: $e');
    }
  }

  Future<void> _sendFileMessage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        // Show loading dialog
        _showLoadingDialog();

        // Upload file to Matrix
        final matrixFile = await _uploadMatrixFile(file);

        // Close loading dialog
        Navigator.of(context).pop();

        // Determine message type based on file type
        final mimeType =
            lookupMimeType(file.path) ?? 'application/octet-stream';
        String msgType = 'm.file';

        if (mimeType.startsWith('image/')) msgType = 'm.image';
        if (mimeType.startsWith('audio/')) msgType = 'm.audio';
        if (mimeType.startsWith('video/')) msgType = 'm.video';

        // Send file message
        await _sendMessage(
          body: path.basename(file.path),
          msgType: msgType,
          url: matrixFile.toString(),
          filename: path.basename(file.path),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error sending file: $e');
    }
  }

  Future<Uri> _uploadMatrixFile(File file) async {
    final matrixFile = await widget.room.client.uploadContent(
      file.readAsBytesSync(),
      filename: path.basename(file.path),
    );
    return matrixFile; // Use the `url` property instead
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildMessageContent(Event event) {
    final theme = Theme.of(context);

    // Handle different message types
    switch (event.type) {
      case EventTypes.Message:
        switch (event.messageType) {
          case MessageTypes.Text:
            return Text(
              event.plaintextBody,
              style: theme.textTheme.bodyMedium,
            );

          case MessageTypes.Image:
            return _buildImageMessage(event);

          case MessageTypes.File:
            return _buildFileMessage(event);

          case MessageTypes.Audio:
            return _buildAudioMessage(event);

          case MessageTypes.Video:
            return _buildVideoMessage(event);

          default:
            return Text(
              event.plaintextBody,
              style: theme.textTheme.bodyMedium,
            );
        }

      case EventTypes.Sticker:
        return _buildStickerMessage(event);

      default:
        return Text(
          'Unsupported message type: ${event.type}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey,
          ),
        );
    }
  }

  Widget _buildImageMessage(Event event) {
    return GestureDetector(
        onTap: () => _showImageDialog(event),
        child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 200,
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: MxcImage(
              event: event,
            ))
        //   Image.network(

        //     event.attachmentMxcUrl
        //     .toString(),
        //     fit: BoxFit.cover,
        //     loadingBuilder: (context, child, loadingProgress) {
        //       if (loadingProgress == null) return child;
        //       return const Center(child: CircularProgressIndicator());
        //     },
        //   ),
        // ),
        );
  }

  Widget _buildFileMessage(Event event) {
    return ListTile(
      leading: const Icon(Icons.file_present),
      title: Text(event.body),
      trailing: IconButton(
        icon: const Icon(Icons.download),
        onPressed: () {},
      ),
    );
  }

  Widget _buildAudioMessage(Event event) {
    return ListTile(
      leading: const Icon(Icons.audiotrack),
      title: Text(event.body),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: () {},
      ),
    );
  }

  Widget _buildVideoMessage(Event event) {
    return GestureDetector(
      onTap: () async {
        final MatrixFile? matrixFile = await event.downloadAndDecryptAttachment(
          getThumbnail: false,
        );

        if (matrixFile != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(
                videoBytes: matrixFile.bytes,
              ),
            ),
          );
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thumbnail preview
          FutureBuilder(
            future: event.downloadAndDecryptAttachment(
              getThumbnail: true,
            ),
            builder: (context, AsyncSnapshot<MatrixFile?> asyncData) {
              if (asyncData.hasData && asyncData.data != null) {
                return Image.memory(
                  asyncData.data!.bytes,
                  fit: BoxFit.cover,
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: Icon(Icons.error)),
                    );
                  },
                );
              }
              return const SizedBox(
                height: 250,
                width: 250,
                child: Center(child: CircularProgressIndicator()),
              );
            },
          ),
          // Play button overlay
          const CircleAvatar(
            backgroundColor: Colors.black54,
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerMessage(Event event) {
    return Image.network(
      event.content['url'] as String? ?? '',
      width: 100,
      height: 100,
      fit: BoxFit.contain,
    );
  }

  void _showImageDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Image.network(
          event.content['url'] as String? ?? '',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.getLocalizedDisplayname()),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => RoomDetails(
                  room: widget.room,
                ),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _timeline == null
                ? const Center(child: CircularProgressIndicator.adaptive())
                : ListView.builder(
                    reverse: true,
                    itemCount: _timeline!.events.length,
                    itemBuilder: (context, index) {
                      final event = _timeline!.events[index];

                      switch (event.type) {
                        case EventTypes.Message:
                          return _buildMessageBubble(event,
                              event.senderId == widget.room.client.userID);
                        case EventTypes.RoomCreate:
                          return StateMessage(
                              "${widget.room.name} is created by ${event.content["creator"]}");
                        default:
                          return SizedBox.shrink();
                      }
                      // if (!{
                      //   EventTypes.Message,
                      //   EventTypes.Sticker,
                      //   EventTypes.Encrypted,
                      //   EventTypes.CallInvite,
                      // }.contains(event.type)) {
                      //   if (event.type.startsWith('m.call.')) {
                      //     return const SizedBox.shrink();
                      //   }
                      //   // if (event.type == EventTypes.RoomCreate) {
                      //   //   return RoomCreationStateEvent(event: event);
                      //   // }
                      //   // return StateMessage(event);
                      // }
                      // // Filter out non-message events
                      // if (event.type != EventTypes.Message &&
                      //     event.type != EventTypes.Sticker) {
                      //   return SizedBox.shrink();
                      // }
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  String _convertMxcToHttp(String? mxcUrl) {
    if (mxcUrl == null || !mxcUrl.startsWith('mxc://')) return '';
    return 'https://matrix.org/_matrix/media/v3/download/${mxcUrl.substring(6)}';
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () => _showAttachmentBottomSheet(),
          ),
          Expanded(
            child: TextField(
              controller: _sendController,
              decoration: InputDecoration(
                hintText: 'Send a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _sendMessage(),
          ),
        ],
      ),
    );
  }

  void _showAttachmentBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Image'),
            onTap: () {
              Navigator.pop(context);
              _sendImageMessage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_present),
            title: const Text('File'),
            onTap: () {
              Navigator.pop(context);
              _sendFileMessage();
            },
          ),
          
        ],
      ),
    );
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
                  _buildMessageContent(event),
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
}

class StateMessage extends StatelessWidget {
  final String eventData;
  const StateMessage(this.eventData, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: theme.colorScheme.surface.withAlpha(128),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                eventData,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
