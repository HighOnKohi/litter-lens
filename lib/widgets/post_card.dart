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
<<<<<<< HEAD
      color: Color(0xFFEEFFF7),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(profileImage),
                  radius: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Post text
            Text(text),

            const SizedBox(height: 10),

            // // Post image
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
                // Image.network(imageUrl),
              ),

            const SizedBox(height: 10),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                InteractionTextButton(
                  label: "Like",
                  icon: Icons.thumb_up_rounded,
                  onPressed: likePost,
                ),
                InteractionTextButton(
                  label: "Comment",
                  icon: Icons.comment_rounded,
                  onPressed: commentOnPost,
                ),
                InteractionTextButton(
                  label: "Share",
                  icon: Icons.share_rounded,
                  onPressed: sharePost,
                ),
              ],
            ),
          ],
        ),
=======
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
>>>>>>> 28e14183ea6e53189de539f31fff6b9bbf71d0d7
      ),
    );
  }
}
