import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';
import '../services/post_service.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();
  CommentModel? _replyingTo;
  bool _isSending = false;

  final Map<String, String> _reactionEmojis = {
    'me_gusta': '👍',
    'dislike': '👎',
    'corazon': '❤️',
    'sorpresa': '😮',
    'tristeza': '😢',
    'me_enoja': '😡',
  };

  ImageProvider? _getAvatar(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('data:image')) {
      return MemoryImage(base64Decode(photoUrl.split(',').last));
    }
    return NetworkImage(photoUrl);
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      await _postService.addComment(
        postId: widget.postId,
        userId: user.uid,
        userName: user.displayName ?? 'Usuario',
        userPhoto: user.photoURL,
        texto: text,
        parentId: _replyingTo?.id,
      );

      _commentController.clear();
      setState(() {
        _replyingTo = null;
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showCommentReactionPicker(String commentId, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _reactionEmojis.entries.map((entry) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(bottomContext);
                _postService.toggleCommentReaction(widget.postId, commentId, userId, entry.key);
              },
              child: Text(entry.value, style: const TextStyle(fontSize: 26)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment, String currentUserId, List<CommentModel> allComments, {bool isReply = false}) {
    final avatar = _getAvatar(comment.userPhoto);
    final isOwner = comment.userId == currentUserId;
    final userReaction = comment.reacciones[currentUserId];

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 36.0 : 0.0, top: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundImage: avatar,
                child: avatar == null ? const Icon(Icons.person, size: 16) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(comment.texto, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  onPressed: () => _postService.deleteComment(widget.postId, comment.id),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48.0, top: 4.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final reaction = userReaction ?? 'me_gusta';
                    _postService.toggleCommentReaction(widget.postId, comment.id, currentUserId, reaction);
                  },
                  onLongPress: () => _showCommentReactionPicker(comment.id, currentUserId),
                  child: Text(
                    userReaction != null ? '${_reactionEmojis[userReaction]} Me gusta' : 'Me gusta',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: userReaction != null ? Colors.redAccent : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _replyingTo = comment;
                    });
                  },
                  child: Text('Responder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                ),
                if (comment.reacciones.isNotEmpty) ...[
                  const Spacer(),
                  Text('${comment.reacciones.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]
              ],
            ),
          ),
          // Dibujar respuestas hijo
          if (!isReply)
            ...allComments
                .where((c) => c.parentId == comment.id)
                .map((reply) => _buildCommentItem(reply, currentUserId, allComments, isReply: true)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text('Comentarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: _postService.getCommentsStream(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snapshot.data ?? [];
                final topComments = comments.where((c) => c.parentId == null).toList();

                if (topComments.isEmpty) {
                  return const Center(child: Text('Sé el primero en comentar.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: topComments.length,
                  itemBuilder: (context, index) {
                    return _buildCommentItem(topComments[index], currentUserId, comments);
                  },
                );
              },
            ),
          ),
          if (_replyingTo != null)
            Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text('Respondiendo a ${_replyingTo!.userName}', style: const TextStyle(fontSize: 12))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un comentario...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSending ? const CircularProgressIndicator() : const Icon(Icons.send, color: Colors.redAccent),
                  onPressed: _isSending ? null : _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}