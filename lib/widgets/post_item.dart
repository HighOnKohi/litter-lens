import 'package:flutter/material.dart';
import 'package:litter_lens/services/post_service.dart';
import 'package:litter_lens/services/share_service.dart';
import 'package:litter_lens/widgets/comments_sheet.dart';
import 'package:litter_lens/widgets/post_actions_bar.dart';

class PostItem extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String? currentUserName;

  final String title;
  final String description;
  final String imageUrl;
  final String contentToShare;

  const PostItem({
    super.key,
    required this.postId,
    required this.currentUserId,
    this.currentUserName,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.contentToShare,
  });

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  bool _sharing = false;
  bool _liking = false;

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
      await PostService.togglePostLike(
        postId: widget.postId,
        userId: widget.currentUserId,
      );
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasTitle || hasDesc)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTitle)
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (hasTitle && hasDesc) const SizedBox(height: 6),
                  if (hasDesc)
                    Text(
                      widget.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
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
          PostActionsBar(
            onLike: _liking ? null : _toggleLike,
            onComment: _openComments,
            onShare: _sharing ? null : _share,
            sharing: _sharing,
          ),
        ],
      ),
    );
  }
}
