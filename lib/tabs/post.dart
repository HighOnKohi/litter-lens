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
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
        parts.last.characters.take(1).toString())
        .toUpperCase();
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
      backgroundColor: const Color(0xFFEEFFF7),
      builder: (_) => CommentsSheet(
        postId: widget.postId,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cardBackground = Color(0xFFEEFFF7);
    const accentColor = Color(0xFF0B8A4D);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: PostService.postMapStream(widget.postId),
      builder: (ctx, snap) {
        final map = snap.data;
        final title = (map?['Title'] ?? widget.title).toString();
        final description =
        (map?['Description'] ?? widget.description).toString();
        final imageUrl = (map?['ImageUrl'] ?? widget.imageUrl).toString();
        final avatarUrl = (widget.authorAvatarUrl ?? '').trim();

        final hasTitle = title.trim().isNotEmpty;
        final hasDesc = description.trim().isNotEmpty;
        final hasImage = imageUrl.trim().isNotEmpty;

        return Card(
          color: cardBackground,
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
                      backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      backgroundColor: accentColor.withOpacity(0.1),
                      child: avatarUrl.isEmpty
                          ? Text(
                        _initials(widget.authorName),
                        style: const TextStyle(color: accentColor),
                      )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasTitle)
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: accentColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            widget.authorName,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                color: accentColor.withOpacity(0.8)),
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
                    description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: accentColor.withOpacity(0.9)),
                  ),
                ),
              if (hasImage) ...[
                const Divider(height: 1, color: accentColor),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: accentColor.withOpacity(0.1),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: accentColor,
                      ),
                    ),
                  ),
                ),
              ],
              Divider(height: 1, color: accentColor.withOpacity(0.3)),

              StreamBuilder<Map<String, dynamic>>(
                stream: PostService.postEngagementStream(widget.postId),
                builder: (context, engSnap) {
                  final eng = engSnap.data ?? const <String, dynamic>{};
                  final likedBy =
                  List<String>.from(eng['likedBy'] ?? const <String>[]);
                  final isLiked = likedBy.contains(widget.currentUserId);
                  final likeCount =
                  (eng['likeCount'] ?? likedBy.length) as int;

                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: accentColor,
                        secondary: accentColor,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: PostActionsBar(
                      onLike: _liking ? null : _toggleLike,
                      onComment: _openComments,
                      onShare: _sharing ? null : _share,
                      sharing: _sharing,
                      liked: isLiked,
                      likeCount: likeCount,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
