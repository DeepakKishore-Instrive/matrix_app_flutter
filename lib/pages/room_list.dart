import 'package:flutter/material.dart';
import 'package:flutter_application_2/pages/create_group.dart';
import 'package:flutter_application_2/pages/login.dart';
import 'package:flutter_application_2/pages/room.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  _RoomListPageState createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  final TextEditingController _searchController = TextEditingController();
  SearchUserDirectoryResponse? _searchData;
  bool _isSearching = false;
  bool _isLoading = false;

  void _logout() async {
    try {
      final client = Provider.of<Client>(context, listen: false);
      await client.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      _showErrorSnackBar('Logout failed: ${e.toString()}');
    }
  }

  void _join(Room room) async {
    try {
      if (room.membership != Membership.join) {
        await room.join();
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoomPage(room: room),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Could not join room: ${e.toString()}');
    }
  }

  Future<void> _createDirectChat(String userId, String userName) async {
    try {
      setState(() => _isLoading = true);
      final client = Provider.of<Client>(context, listen: false);
      String roomId = await client.createRoom(
        isDirect: true,
        invite: [userId],
      );

      _searchController.clear();
      _searchData = null;
      setState(() => _isLoading = false);

      Room? newRoom = client.getRoomById(roomId);
      if (newRoom != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RoomPage(room: newRoom)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Could not create room: ${e.toString()}');
    }
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

  String _convertMxcToHttp(String? mxcUrl) {
    if (mxcUrl == null || !mxcUrl.startsWith('mxc://')) return '';
    return 'https://matrix.org/_matrix/media/v3/download/${mxcUrl.substring(6)}';
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
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchData = null);
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

  Widget _buildRoomList(List<Room> rooms) {
    return ListView.separated(
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemCount: rooms.length,
      itemBuilder: (context, i) => Dismissible(
        key: Key(i.toString()),
        onDismissed: (direction) {},
        child: ListTile(
          leading: 
          // rooms[i].avatar != null
          //     ? FutureBuilder(
          //         future: rooms[i].avatar!.getThumbnailUri(
          //               Provider.of<Client>(context, listen: false),
          //               width: 56,
          //               height: 56,
          //             ),
          //         builder: (context, asyncData) {
          //           if (!asyncData.hasData) {
          //             return CircularProgressIndicator.adaptive();
          //           }
          //           return CircleAvatar(
          //             foregroundImage: NetworkImage(asyncData.data.toString()),
          //             backgroundColor: Colors.grey[300],
          //             child: rooms[i].avatar == null
          //                 ? Icon(Icons.person, color: Colors.grey[600])
          //                 : null,
          //           );
          //         })
          //     :
               SizedBox(),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  rooms[i].getLocalizedDisplayname(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (rooms[i].notificationCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rooms[i].notificationCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            rooms[i].lastEvent?.body ?? 'No messages',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _join(rooms[i]),
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

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
          child: ListTile(
            onTap: () => _createDirectChat(
                profile.userId, profile.displayName ?? profile.userId),
            leading: profile.avatarUrl != null
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

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              child: Text("Me"),
            ),
          ),
        ),
        title: const Text('Matrix Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : StreamBuilder(
                    stream: client.onSync.stream,
                    builder: (context, _) => _buildRoomList(client.rooms),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "New Group",
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => CreatedGroup(),
          ));
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
