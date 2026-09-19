import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../widgets/comments_sheet.dart'; // <--- Import del modal de comentarios
import 'profile_screen.dart';
import 'login_screen.dart';
import 'search_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  UserModel? _currentUser;
  bool _isPublishing = false;
  bool _showWelcomeBanner = true;
  Uint8List? _selectedPostImageBytes;

  final Map<String, String> _reactionEmojis = {
    'me_gusta': '👍',
    'dislike': '👎',
    'corazon': '❤️',
    'sorpresa': '😮',
    'tristeza': '😢',
    'me_enoja': '😡',
  };

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postController.dispose();
    super.dispose();
  }

  void _toggleReactionAndKeepPosition(String postId, String userId, String reactionType) {
    final double currentOffset = _scrollController.offset;
    _postService.toggleReaction(postId, userId, reactionType).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(currentOffset);
        }
      });
    });
  }

  Future<void> _loadUser() async {
    final user = await _userService.getCurrentUserData();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _pickPostImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedPostImageBytes = bytes;
      });
    }
  }

  void _publishPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty && _selectedPostImageBytes == null) return;

    setState(() => _isPublishing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && _currentUser != null) {
        String? imageUrl;
        if (_selectedPostImageBytes != null) {
          imageUrl = await _postService.processPostImage(_selectedPostImageBytes!);
        }

        await _postService.createPost(
          userId: user.uid,
          userName: _currentUser!.nombre,
          userPhoto: _currentUser!.fotoUrl,
          contenido: text,
          imagenUrl: imageUrl,
        );

        _postController.clear();
        setState(() {
          _selectedPostImageBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _showEditDialog(PostModel post) {
    final editController = TextEditingController(text: post.contenido);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar Publicación'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Escribe tu actualización...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedText = editController.text.trim();
              if (updatedText.isNotEmpty) {
                final navigator = Navigator.of(dialogContext);
                await _postService.updatePost(post.id, updatedText);
                if (mounted) navigator.pop();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String postId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Publicación'),
        content: const Text('¿Estás seguro de que deseas eliminar esta publicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await _postService.deletePost(postId);
              if (mounted) navigator.pop();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context, String postId, String currentUserId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _reactionEmojis.entries.map((entry) {
              return GestureDetector(
                onTap: () {
                  final navigator = Navigator.of(bottomContext);
                  _toggleReactionAndKeepPosition(postId, currentUserId, entry.key);
                  navigator.pop();
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  List<Widget> _buildTopReactionEmojis(Map<String, String> reacciones) {
    if (reacciones.isEmpty) return [];

    Map<String, int> counts = {};
    for (var r in reacciones.values) {
      counts[r] = (counts[r] ?? 0) + 1;
    }

    var sortedReactions = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var topReactions = sortedReactions.take(3).map((e) => e.key).toList();

    return topReactions.map((reactionType) {
      return Container(
        margin: const EdgeInsets.only(right: 2),
        child: Text(
          _reactionEmojis[reactionType] ?? '👍',
          style: const TextStyle(fontSize: 14),
        ),
      );
    }).toList();
  }

  ImageProvider? _getAvatar(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('data:image')) {
      final base64String = photoUrl.split(',').last;
      return MemoryImage(base64Decode(base64String));
    }
    return NetworkImage(photoUrl);
  }

  Widget _buildPostImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
    if (imageUrl.startsWith('data:image')) {
      final base64String = imageUrl.split(',').last;
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final userAvatar = _getAvatar(_currentUser?.fotoUrl);

    return Scaffold(
      appBar: AppBar(
  title: const Text('CampusConnect', style: TextStyle(fontWeight: FontWeight.bold)),
  backgroundColor: Colors.redAccent,
  foregroundColor: Colors.white,
  actions: [
    IconButton(
      icon: const Icon(Icons.search),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        );
      },
    ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              backgroundImage: userAvatar,
              child: userAvatar == null ? const Icon(Icons.person, size: 20, color: Colors.redAccent) : null,
            ),
            
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              } else if (value == 'logout') {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(_currentUser?.nombre ?? 'Usuario', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile',
                child: Row(children: [Icon(Icons.settings, color: Colors.grey), SizedBox(width: 8), Text('Ajustes y Perfil')]),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [Icon(Icons.exit_to_app, color: Colors.redAccent), SizedBox(width: 8), Text('Cerrar Sesión')]),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_showWelcomeBanner && _currentUser != null)
            Container(
              margin: const EdgeInsets.all(12.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.redAccent.shade100.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school, color: Colors.redAccent, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '¡Bienvenid@ a CampusConnect, ${_currentUser!.nombre.split(' ').first}! 🎓',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _showWelcomeBanner = false),
                  ),
                ],
              ),
            ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: userAvatar,
                        child: userAvatar == null ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _postController,
                          decoration: const InputDecoration(
                            hintText: '¿Qué quieres compartir hoy?',
                            border: InputBorder.none,
                          ),
                          maxLines: null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.photo_library, color: Colors.grey),
                        onPressed: _pickPostImage,
                      ),
                      IconButton(
                        icon: _isPublishing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.redAccent),
                        onPressed: _isPublishing ? null : _publishPost,
                      ),
                    ],
                  ),
                  if (_selectedPostImageBytes != null) ...[
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_selectedPostImageBytes!, height: 150, width: double.infinity, fit: BoxFit.cover),
                        ),
                        IconButton(
                          icon: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.close, color: Colors.white, size: 18)),
                          onPressed: () => setState(() => _selectedPostImageBytes = null),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<PostModel>>(
              stream: _postService.getPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay publicaciones comunitarias aún.'));
                }

                final posts = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final postAvatar = _getAvatar(post.userPhoto);
                    final isOwner = currentUserId == post.userId;
                    final userReaction = currentUserId != null ? post.reacciones[currentUserId] : null;

                    return Card(
                      key: ValueKey(post.id),
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(backgroundImage: postAvatar, child: postAvatar == null ? const Icon(Icons.person) : null),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        '${post.fechaCreacion.day}/${post.fechaCreacion.month}/${post.fechaCreacion.year}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isOwner)
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') _showEditDialog(post);
                                      if (value == 'delete') _confirmDelete(post.id);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
                                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                                    ],
                                  ),
                              ],
                            ),
                            if (post.contenido.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(post.contenido, style: const TextStyle(fontSize: 15)),
                            ],
                            if (post.imagenUrl != null && post.imagenUrl!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildPostImage(post.imagenUrl),
                            ],
                            
                            if (post.reacciones.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ..._buildTopReactionEmojis(post.reacciones),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post.reacciones.length}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],

                            const Divider(height: 16),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // BOTÓN DE REACCIÓN
                                InkWell(
                                  onTap: () {
                                    if (currentUserId != null) {
                                      final reactionToSet = userReaction ?? 'me_gusta';
                                      _toggleReactionAndKeepPosition(post.id, currentUserId, reactionToSet);
                                    }
                                  },
                                  onLongPress: () {
                                    if (currentUserId != null) {
                                      _showReactionPicker(context, post.id, currentUserId);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    child: Row(
                                      children: [
                                        Text(
                                          userReaction != null ? _reactionEmojis[userReaction]! : '👍',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          userReaction != null
                                              ? userReaction.replaceAll('_', ' ').toUpperCase()
                                              : 'Me gusta',
                                          style: TextStyle(
                                            color: userReaction != null ? Colors.redAccent : Colors.grey.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // BOTÓN DE COMENTAR
                                InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => CommentsSheet(postId: post.id),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                                        SizedBox(width: 6),
                                        Text(
                                          'Comentar',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}