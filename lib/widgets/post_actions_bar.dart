import 'package:flutter/material.dart';

class PostActionsBar extends StatelessWidget {
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  final bool sharing;

  final bool liked;
  final int likeCount;

  const PostActionsBar({
    super.key,
    this.onLike,
    this.onComment,
    this.onShare,
    this.sharing = false,
    this.liked = false,
    this.likeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                color: liked ? Colors.red : null),
            onPressed: onLike,
            tooltip: 'Like',
          ),
          if (likeCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$likeCount'),
            ),
          IconButton(
            icon: const Icon(Icons.mode_comment_outlined),
            onPressed: onComment,
            tooltip: 'Comment',
          ),
          const Spacer(),
          IconButton(
            icon: sharing
                ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_outlined),
            onPressed: sharing ? null : onShare,
            tooltip: 'Share',
          ),
        ],
      ),
    );
  }
}
