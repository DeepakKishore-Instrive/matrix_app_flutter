import 'package:flutter/material.dart';
import 'package:flutter_application_2/pages/login.dart';
import 'package:flutter_application_2/pages/room_list.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' as sqlite;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final client = Client(
    'Matrix Example Chat',
    databaseBuilder: (_) async {
      final dir = await getApplicationSupportDirectory();
      final db = MatrixSdkDatabase(
        "chatDB",
        database: await sqlite.openDatabase('$dir/database.sqlite'),
      );
      await db.open();
      return db;
    },
  );
  await client.init();
  runApp(MatrixExampleChat(client: client));
}

class MatrixExampleChat extends StatelessWidget {
  final Client client;
  const MatrixExampleChat({required this.client, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Matrix Example Chat',
      builder: (context, child) => Provider<Client>(
        create: (context) => client,
        child: child,
      ),
      home: client.isLogged() ? const RoomListPage() : const LoginPage(),
    );
  }
}
