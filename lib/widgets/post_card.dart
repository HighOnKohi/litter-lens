import 'package:flutter/material.dart';
import 'package:litter_lens/theme.dart';

void likePost() {}

void commentOnPost() {}

void sharePost() {}

class PostCard extends StatelessWidget {
  final String username;
  final String role;
  final Color roleColor;
  final String time;
  final String text;
  final String imageUrl;
  final String profileImage;

  const PostCard({
    super.key,
    required this.username,
    required this.role,
    required this.roleColor,
    required this.time,
    required this.text,
    required this.imageUrl,
    required this.profileImage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
      ),
    );
  }
}
