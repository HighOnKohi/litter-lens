import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:litter_lens/tabs/post.dart';
import '../theme.dart';
import '../services/post_service.dart';
import '../widgets/create_post.dart';

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

  Future<void> _createPost() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => CreatePost(
        postNameController: _postNameController,
        postDetailController: _postDetailController,
        onSubmit: (title, desc, imageUrl) async {
          await PostService.createPost(
            title: title,
            description: desc,
            imageUrl: imageUrl,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? 'guest';
    final currentUserName = currentUser?.displayName;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: PostService.postsStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No posts yet.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final id = doc.id;
              final data = doc.data();

              final title = (data['title'] as String?)?.trim() ?? '';
              final desc = (data['description'] as String?)?.trim() ?? '';
              final imageUrl = (data['imageUrl'] as String?)?.trim() ?? '';

              final authorName =
                  ((data['userName'] ?? data['username']) as String?)?.trim() ??
                      'User';

              final authorAvatarUrl =
              ((data['userPhotoUrl'] ??
                  data['photoUrl'] ??
                  data['avatarUrl']) as String?)
                  ?.trim()
                  ;

              final parts =
              <String>[title, desc, imageUrl].where((s) => s.isNotEmpty).toList();
              final contentToShare = parts.join('\n\n');

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
      floatingActionButton: ActionButton(
        onPressed: _createPost,
        icon: Icons.upload_rounded,
      ),
    );
  }
}
