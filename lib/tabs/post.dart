import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:litter_lens/services/post_service.dart';
import 'package:litter_lens/services/share_service.dart';
import 'package:litter_lens/widgets/comments_sheet.dart';
import 'package:litter_lens/widgets/post_actions_bar.dart';

class Post extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String? currentUserName;

  final String title;
  final String description;
  final String imageUrl;
  final String contentToShare;

  final String authorName;
  final String? authorAvatarUrl;

  const Post({
    super.key,
    required this.postId,
    required this.currentUserId,
    this.currentUserName,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.contentToShare,
    required this.authorName,
    this.authorAvatarUrl,
  });

  @override
  State<Post> createState() => _PostState();
}

class _PostState extends State<Post> {
  bool _sharing = false;
  bool _liking = false;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.take(1).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() + parts.last.characters.take(1).toString()).toUpperCase();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    await ShareService.shareText(text: widget.contentToShare);
    if (mounted) setState(() => _sharing = false);
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() => _liking = true);
    try {
      await PostService.toggleLike(widget.postId, widget.currentUserId);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => CommentsSheet(
        postId: widget.postId,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = widget.title.trim().isNotEmpty;
    final hasDesc = widget.description.trim().isNotEmpty;
    final hasImage = widget.imageUrl.trim().isNotEmpty;
    final avatarUrl = widget.authorAvatarUrl?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty ? Text(_initials(widget.authorName)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasTitle)
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        widget.authorName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasDesc)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                widget.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (hasImage) ...[
            const Divider(height: 1),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ],
          const Divider(height: 1),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PostService.postStream(widget.postId),
            builder: (context, snap) {
              final data = snap.data?.data() ?? const <String, dynamic>{};
              final likedBy = List<String>.from(data['likedBy'] ?? const <String>[]);
              final isLiked = likedBy.contains(widget.currentUserId);
              final likeCount = (data['likeCount'] ?? data['likesCount'] ?? likedBy.length) as int;

              return PostActionsBar(
                onLike: _liking ? null : _toggleLike,
                onComment: _openComments,
                onShare: _sharing ? null : _share,
                sharing: _sharing,
                liked: isLiked,
                likeCount: likeCount,
              );
            },
          ),
        ],
      ),
    );
  }
}
