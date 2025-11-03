import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:litter_lens/tabs/post.dart';
import '../services/post_service.dart';
import '../services/account_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _postNameController = TextEditingController();
  final TextEditingController _postDetailController = TextEditingController();

  @override
  void dispose() {
    _postNameController.dispose();
    _postDetailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? 'guest';
    final currentUserName = currentUser?.displayName;

    return FutureBuilder<String?>(
      future: AccountService.getSubdivisionIdForCurrentUser(),
      builder: (ctx, subsnap) {
        if (subsnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final subdivisionId = (subsnap.data ?? '').trim();

        if (subdivisionId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No subdivision assigned.')),
          );
        }

        return Scaffold(
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: PostService.postsFlattenedStream(
              filterSubdivisionId: subdivisionId,
            ),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final posts = snap.data ?? const <Map<String, dynamic>>[];
              if (posts.isEmpty) {
                return const Center(child: Text('No posts in this subdivision.'));
              }

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (_, i) {
                  final p = posts[i];
                  final id = (p['postId'] ?? '') as String;
                  final title = (p['title'] ?? '') as String;
                  final desc = (p['description'] ?? '') as String;
                  final imageUrl = (p['imageUrl'] ?? '') as String;

                  final contentToShare = [
                    title,
                    desc,
                    imageUrl,
                  ].where((s) => s.isNotEmpty).join('\n\n');

                  return Post(
                    postId: id,
                    currentUserId: currentUserId,
                    currentUserName: currentUserName,
                    title: title,
                    description: desc,
                    imageUrl: imageUrl,
                    contentToShare: contentToShare,
                    authorName: 'User',
                    authorAvatarUrl: null,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
