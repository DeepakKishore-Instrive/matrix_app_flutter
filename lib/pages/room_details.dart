import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class RoomDetails extends StatefulWidget {
  final Room room;
  const RoomDetails({super.key, required this.room});

  @override
  State<RoomDetails> createState() => _RoomDetailsState();
}

class _RoomDetailsState extends State<RoomDetails> {
  List<User> _roomMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchRoomMembers();
  }

  Future<void> _fetchRoomMembers() async {
    try {
      final members = await widget.room.requestParticipants();
      setState(() {
        _roomMembers = members;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load members: $e')),
      );
    }
  }

  void _showMemberBottomSheet() {
    showModalBottomSheet(
      backgroundColor: Colors.transparent,
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Room Members (${_roomMembers.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: Icon(Icons.person_add),
                          onPressed: _inviteMember,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _roomMembers.isEmpty
                        ? Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            controller: controller,
                            itemCount: _roomMembers.length,
                            itemBuilder: (context, index) {
                              final member = _roomMembers[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[300],
                                  child: Icon(Icons.person),
                                ),
                                title: Text(member.displayName ?? member.id),
                                subtitle: Text(_getMemberRole(member)),
                                trailing: _buildMemberActions(member),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getMemberRole(User member) {
    if (member.powerLevel == 100) return 'Admin';
    if (member.powerLevel >= 50) return 'Moderator';
    return 'Member';
  }

  Widget _buildMemberActions(User member) {
    return PopupMenuButton<String>(
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.remove_circle, color: Colors.red),
              SizedBox(width: 8),
              Text('Remove'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'make_admin',
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings),
              SizedBox(width: 8),
              Text('Make Admin'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'make_moderator',
          child: Row(
            children: [
              Icon(Icons.manage_accounts),
              SizedBox(width: 8),
              Text('Make Moderator'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'remove':
            _removeMember(member);
            break;
          case 'make_admin':
            _changeMemberRole(member, 100);
            break;
          case 'make_moderator':
            _changeMemberRole(member, 50);
            break;
        }
      },
    );
  }

  void _inviteMember() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController inviteController = TextEditingController();
        return AlertDialog(
          title: Text('Invite Member'),
          content: TextField(
            controller: inviteController,
            decoration: InputDecoration(
              hintText: 'Enter Matrix ID',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _performInvite(inviteController.text);
                Navigator.of(context).pop();
              },
              child: Text('Invite'),
            ),
          ],
        );
      },
    );
  }

  void _performInvite(String matrixId) async {
    try {
      await widget.room.invite(matrixId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to $matrixId')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to invite: $e')),
      );
    }
  }

  void _removeMember(User member) async {
    try {
      await widget.room.kick(member.id);
      setState(() {
        _roomMembers.remove(member);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.displayName ?? member.id} removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove member: $e')),
      );
    }
  }

  void _changeMemberRole(User member, int powerLevel) async {
    try {
      await widget.room.setPower(member.id, powerLevel);
      setState(() {
        _fetchRoomMembers();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Role updated for ${member.displayName ?? member.id}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change role: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Room Details"),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildRoomHeader(),
          _buildMemberSection(),
          _buildRoomCreationDetails(),
          _buildRoomTopic(),
        ],
      ),
    );
  }

  Widget _buildRoomHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[300],
          child: Icon(Icons.group, size: 50),
        ),
        SizedBox(height: 10),
        Text(
          widget.room.displayname,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }

  Widget _buildMemberSection() {
    final totalMembers = (widget.room.summary.mInvitedMemberCount ?? 0) +
        (widget.room.summary.mJoinedMemberCount ?? 0);

    return Card(
      child: ListTile(
        leading: Icon(Icons.people),
        title: Text('Members'),
        trailing: Text('$totalMembers'),
        onTap: _showMemberBottomSheet,
      ),
    );
  }

  Widget _buildRoomCreationDetails() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.calendar_today),
        title: Text('Created'),
        trailing: Text(_formatDate(widget.room.timeCreated)),
      ),
    );
  }

  Widget _buildRoomTopic() {
    final topic = widget.room.topic;
    return Card(
      child: ListTile(
        leading: Icon(Icons.description),
        title: Text('Room Topic'),
        subtitle: Text(topic.isNotEmpty ? topic : 'No topic set'),
      ),
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}