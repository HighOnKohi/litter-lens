import 'package:flutter/material.dart';
import 'package:litter_lens/services/share_service.dart';
import 'package:litter_lens/widgets/post_actions_bar.dart';

class PostCard extends StatefulWidget {
  final String postId;
  final String contentToShare;
  final VoidCallback? onLike;
  final VoidCallback? onComment;

  const PostCard({
    super.key,
    required this.postId,
    required this.contentToShare,
    this.onLike,
    this.onComment,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _sharing = false;

  Future<void> _handleShare() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    await ShareService.shareText(text: widget.contentToShare);
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(title: Text('Post')),
          const Divider(height: 1),
          PostActionsBar(
            onLike: widget.onLike,
            onComment: widget.onComment,
            onShare: _sharing ? null : _handleShare,
            sharing: _sharing,
          ),
        ],
      ),
    );
  }
}
