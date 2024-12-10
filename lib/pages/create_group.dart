import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/pages/room.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class CreatedGroup extends StatefulWidget {
  const CreatedGroup({super.key});

  @override
  State<CreatedGroup> createState() => _CreatedGroupState();
}

class _CreatedGroupState extends State<CreatedGroup> {
  final TextEditingController _searchController = TextEditingController();
  SearchUserDirectoryResponse? _searchData;
  bool _isSearching = false;
  bool _isLoading = false;
  List<Profile> selectedUser = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create New Group"),
      ),
      body: Column(
        children: [
          _buildSearchField(),
          buildSelectedUsers(),
          Expanded(child: _buildSearchResults())
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search users...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () async {
                    await _createGroupDialog();
                    // Navigator.pop(context);
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onSubmitted: (_) => _searchUsers(),
      ),
    );
  }

  _createGroupDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        TextEditingController textController = TextEditingController();
        return AlertDialog(
          title: Text("Create Group"),
          content: TextField(
            controller: textController,
            decoration: InputDecoration(hintText: "Name"),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await _createGroupChat(
                    textController.text,
                    selectedUser
                        .map(
                          (e) => e.userId,
                        )
                        .toList());
              },
              child: Text("Create"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _searchUsers() async {
    if (_searchController.text.isEmpty) return;

    try {
      setState(() {
        _isSearching = true;
        _isLoading = true;
      });

      final client = Provider.of<Client>(context, listen: false);
      _searchData = await client.searchUserDirectory(_searchController.text);

      setState(() {
        _isSearching = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _isLoading = false;
      });
      _showErrorSnackBar('Search failed: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _createGroupChat(String groupName, List<String> userIds) async {
    try {
      setState(() => _isLoading = true);
      final client = Provider.of<Client>(context, listen: false);
      String roomId = await client.createRoom(
        isDirect: false,
        name: groupName,
        invite: userIds,
      );

      _searchController.clear();
      _searchData = null;
      setState(() => _isLoading = false);

      Room? newRoom = client.getRoomById(roomId);
      if (newRoom != null) {
        Navigator.of(context).pop(); // Close the dialog
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RoomPage(room: newRoom)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Could not create room: ${e.toString()}');
    }
  }

  Widget buildSelectedUsers() {
    return Flexible(
      child: SizedBox(
        height: 50,
        child: ListView(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          children: selectedUser
              .map(
                (e) => Container(
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.purple.shade100),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            selectedUser.removeWhere(
                              (element) => element.userId == e.userId,
                            );
                            setState(() {});
                          },
                          child: Icon(
                            Icons.close,
                            size: 15,
                          ),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(e.displayName ?? e.userId),
                      ],
                    )),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchData == null || _searchData!.results.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchData?.results.length,
      itemBuilder: (context, index) {
        final profile = _searchData!.results[index];
        bool isMarked = isUserPresent(profile.userId);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
          child: ListTile(
            onTap: () {
              if (isMarked) {
                selectedUser.removeWhere(
                  (element) => element.userId == profile.userId,
                );
              } else {
                selectedUser.add(profile);
              }
              setState(() {});
            },
            leading: isMarked
                ? CircleAvatar(
                    child: Icon(Icons.check),
                  )
                : profile.avatarUrl != null
                    ? CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                            _convertMxcToHttp(profile.avatarUrl.toString())),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.person, color: Colors.grey[600]),
                      ),
            title: Text(
              profile.displayName ?? profile.userId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(profile.userId),
            trailing: const Icon(Icons.chat_bubble_outline),
          ),
        );
      },
    );
  }

  String _convertMxcToHttp(String? mxcUrl) {
    if (mxcUrl == null || !mxcUrl.startsWith('mxc://')) return '';
    return 'https://matrix.org/_matrix/media/v3/download/${mxcUrl.substring(6)}';
  }

  bool isUserPresent(String? id) => selectedUser.any(
        (element) => element.userId == id,
      );
}
