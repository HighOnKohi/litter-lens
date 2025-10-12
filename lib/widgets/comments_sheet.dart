import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:litter_lens/services/post_service.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String? currentUserName;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.currentUserId,
    this.currentUserName,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  String? _currentUserPhotoUrl;

  static const String _defaultAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserPhoto();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserPhoto() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      String? photo = user.photoURL;

      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = snap.data();
        if (data != null && data['photoUrl'] is String && (data['photoUrl'] as String).trim().isNotEmpty) {
          photo = (data['photoUrl'] as String).trim();
        }
      } catch (_) {
      }

      if (mounted) setState(() => _currentUserPhotoUrl = photo);
    } catch (_) {
    }
  }

  String _fmtTs(Timestamp? ts) {
    final dt = ts?.toDate();
    if (dt == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.take(1).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() + parts.last.characters.take(1).toString()).toUpperCase();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await PostService.addComment(
        postId: widget.postId,
        text: text,
        uid: widget.currentUserId,
        username: widget.currentUserName,
        photoUrl: _currentUserPhotoUrl?.trim().isNotEmpty == true
            ? _currentUserPhotoUrl
            : (_defaultAvatarUrl.trim().isNotEmpty ? _defaultAvatarUrl : null),
      );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: SizedBox(
        height: media.size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            const ListTile(dense: true, title: Text('Comments')),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: PostService.commentsStream(widget.postId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) return const Center(child: Text('No comments yet.'));
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final d = doc.data();
                      final id = doc.id;

                      final text = (d['text'] as String?)?.trim() ?? '';
                      final name = ((d['username'] ?? d['userName']) as String?)?.trim() ?? 'User';
                      final uid = ((d['uid'] ?? d['userId']) as String?)?.trim() ?? '';
                      final createdAt = d['createdAt'] as Timestamp?;
                      final likedBy = List<String>.from(d['likedBy'] ?? const <String>[]);
                      final likesCount = (d['likesCount'] ?? 0) as int;
                      final isLiked = likedBy.contains(widget.currentUserId);

                      final commentPhoto = (d['photoUrl'] as String?)?.trim() ?? '';
                      final avatarUrl = commentPhoto.isNotEmpty
                          ? commentPhoto
                          : (_defaultAvatarUrl.trim().isNotEmpty ? _defaultAvatarUrl : '');

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl.isEmpty ? Text(_initials(name)) : null,
                        ),
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (text.isNotEmpty) Text(text),
                            if (createdAt != null)
                              Text(
                                _fmtTs(createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (likesCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text('$likesCount'),
                              ),
                            IconButton(
                              icon: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.red : null,
                              ),
                              onPressed: () => PostService.toggleCommentLike(
                                postId: widget.postId,
                                commentId: id,
                                userId: widget.currentUserId,
                              ),
                              tooltip: 'Like',
                            ),
                          ],
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    tooltip: 'Send',
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
