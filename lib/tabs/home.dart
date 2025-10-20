import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Future<void> _createPost() async {
  //   if (!mounted) return;
  //   showDialog(
  //     context: context,
  //     builder: (_) => CreatePost(
  //       postNameController: _postNameController,
  //       postDetailController: _postDetailController,
  //       onSubmit: (title, desc, imageUrl) async {
  //         await PostService.createPost(
  //           title: title,
  //           description: desc,
  //           imageUrl: imageUrl,
  //         );
  //       },
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? 'guest';
    final currentUserName = currentUser?.displayName;

    return FutureBuilder<String?>(
      future: AccountService.getSubdivisionIdForCurrentUser(),
      builder: (ctx, subsnap) {
        final subdivisionId = subsnap.data;
        return Scaffold(
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: PostService.postsFlattenedStream(
              filterSubdivisionId: subdivisionId,
            ),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final posts = snap.data ?? [];
              if (posts.isEmpty) {
                // Show a more helpful debug view so we can inspect why no
                // posts matched the user's subdivision filter.
                return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('posts').get(),
                  builder: (ctx2, docsSnap) {
                    if (docsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allDocs = docsSnap.data?.docs ?? [];
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No posts for subdivision: ${subdivisionId ?? '<null>'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Found ${allDocs.length} document(s) in collection "posts".\nBelow are their doc ids and SubdivisionID values (if present):',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            ...allDocs.map((d) {
                              final data = d.data();
                              final sId =
                                  (data['SubdivisionID'] ??
                                          data['subdivisionId'] ??
                                          '<none>')
                                      .toString();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(d.id),
                                subtitle: Text('SubdivisionID: $sId'),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                );
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
                  final authorName = 'User';
                  final authorAvatarUrl = null;

                  return Post(
                    postId: id,
                    currentUserId: currentUserId,
                    currentUserName: currentUserName,
                    title: title,
                    description: desc,
                    imageUrl: imageUrl,
                    contentToShare: contentToShare,
                    authorName: authorName,
                    authorAvatarUrl: authorAvatarUrl,
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
