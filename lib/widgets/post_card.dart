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
    const backgroundColor = Color(0xFFEEFFF7);
    const accentColor = Color(0xFF0B8A4D);

    return Card(
      color: backgroundColor,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withOpacity(0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: accentColor,
            secondary: accentColor,
            onPrimary: Colors.white,
          ),
          iconTheme: const IconThemeData(color: accentColor),
          dividerColor: accentColor.withOpacity(0.3),
          textTheme: Theme.of(
            context,
          ).textTheme.apply(bodyColor: accentColor, displayColor: accentColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              title: Text(
                'Post',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
            const Divider(height: 1),
            PostActionsBar(
              onLike: widget.onLike,
              onComment: widget.onComment,
              onShare: _sharing ? null : _handleShare,
              sharing: _sharing,
            ),
          ],
        ),
      ),
    );
  }
}
