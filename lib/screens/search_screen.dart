import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  ImageProvider? _getAvatar(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('data:image')) {
      return MemoryImage(base64Decode(photoUrl.split(',').last));
    }
    return NetworkImage(photoUrl);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Buscar compañeros o usuarios...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim();
            });
          },
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
      body: _searchQuery.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Escribe un nombre para buscar usuarios en CampusConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : StreamBuilder<List<UserModel>>(
              stream: _userService.searchUsers(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data ?? [];

                if (users.isEmpty) {
                  return const Center(child: Text('No se encontraron usuarios.'));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final avatar = _getAvatar(user.fotoUrl);

                    return StreamBuilder<bool>(
                      stream: _userService.isFollowingStream(user.idUsuario),
                      builder: (context, followSnapshot) {
                        final isFollowing = followSnapshot.data ?? false;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: avatar,
                            child: avatar == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(user.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(user.correo),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing ? Colors.grey.shade300 : Colors.redAccent,
                              foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                              elevation: 0,
                            ),
                            onPressed: () {
                              _userService.toggleFollowUser(user.idUsuario);
                            },
                            child: Text(isFollowing ? 'Siguiendo' : 'Seguir'),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}