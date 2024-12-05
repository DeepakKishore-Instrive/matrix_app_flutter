import 'package:flutter/material.dart';
import 'package:flutter_application_2/login.dart';
import 'package:flutter_application_2/room.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  _RoomListPageState createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  TextEditingController searchController = TextEditingController();
  void _logout() async {
    final client = Provider.of<Client>(context, listen: false);
    await client.logout();
    // client.searchUserDirectory(searchTerm)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _join(Room room) async {
    if (room.membership != Membership.join) {
      await room.join();
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomPage(room: room),
      ),
    );
  }

  Future<void> _createRoom(String userId) async {
    final client = Provider.of<Client>(context, listen: false);
    String roomId = await client.createRoom(isDirect: true, invite: [
      userId,
    ]);
    print(roomId);
    searchController.clear();
    setState(() {});
    // client.
  }

  SearchUserDirectoryResponse? searchData;

  String convertMxcToHttp(
    String mxcUrl,
  ) {
    if (mxcUrl.startsWith('mxc://')) {
      // final parts = mxcUrl.substring(6).split('/');
      return 'https://matrix.org/_matrix/media/v3/download/${mxcUrl.substring(6)}'; //"mxc://matrix.org/VkqEVTPEcYhKeQaoXLehYvoE"
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
                suffixIcon: IconButton(
                    onPressed: () async {
                      Future.value([]);
                      searchData = await client
                          .searchUserDirectory(searchController.text);
                      setState(() {});
                      print(searchData);
                    },
                    icon: Icon(Icons.search))),
          ),
          Expanded(
            child: searchController.text.isNotEmpty
                ? searchData != null && searchData!.results.isNotEmpty
                    ? ListView.builder(
                        itemCount: searchData?.results.length,
                        itemBuilder: (context, index) {
                          List<Profile> profile = searchData?.results ?? [];
                          return Card(
                            child: ListTile(
                                onTap: () {
                                  _createRoom(profile[index].userId);
                                },
                                leading:profile[index].avatarUrl !=
                                          null? CircleAvatar(
                                  backgroundImage:NetworkImage(convertMxcToHttp(
                                          profile[index].avatarUrl.toString()))
                                      
                                ): null,
                                title: Text(
                                    "${profile[index].displayName} | ${profile[index].userId}")),
                          );
                        },
                      )
                    : SizedBox(
                        child: Text("No Data"),
                      )
                : StreamBuilder(
                    stream: client.onSync.stream,
                    builder: (context, _) => ListView.builder(
                      itemCount: client.rooms.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: CircleAvatar(
                          foregroundImage: client.rooms[i].avatar == null
                              ? null
                              : NetworkImage(client.rooms[i].avatar!
                                  .getThumbnailUri(
                                    client,
                                    width: 56,
                                    height: 56,
                                  )
                                  .toString()),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    client.rooms[i].getLocalizedDisplayname())),
                            if (client.rooms[i].notificationCount > 0)
                              Material(
                                  borderRadius: BorderRadius.circular(99),
                                  color: Colors.red,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: Text(client
                                        .rooms[i].notificationCount
                                        .toString()),
                                  ))
                          ],
                        ),
                        subtitle: Text(
                          client.rooms[i].lastEvent?.body ?? 'No messages',
                          maxLines: 1,
                        ),
                        onTap: () => _join(client.rooms[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
