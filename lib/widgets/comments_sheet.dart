import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:litter_lens/services/post_service.dart';
import 'package:litter_lens/theme.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String? currentUserName;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.currentUserId,
    this.currentUserName,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  String? _currentUserPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserPhoto();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserPhoto() async {
    try {
      final authPhoto = FirebaseAuth.instance.currentUser?.photoURL;
      if (authPhoto != null && authPhoto.trim().isNotEmpty) {
        if (!mounted) return;
        setState(() => _currentUserPhotoUrl = authPhoto.trim());
        return;
      }

      final uid = widget.currentUserId;
      if (uid.isEmpty) return;
      final snap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data() ?? const <String, dynamic>{};
      final url = (data['photoUrl'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() => _currentUserPhotoUrl = url.isEmpty ? null : url);
    } catch (_) {
    }
  }

  Future<String> _resolveCurrentUserName() async {
    final fromWidget = widget.currentUserName?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;

    final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;

    try {
      final uid = widget.currentUserId;
      if (uid.isNotEmpty) {
        final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final u = snap.data() ?? const <String, dynamic>{};
        final candidates = [
          (u['username'] ?? '').toString(),
          (u['Username'] ?? '').toString(),
          (u['displayName'] ?? '').toString(),
          (u['name'] ?? '').toString(),
          (u['userName'] ?? '').toString(),
        ];
        for (final c in candidates) {
          final trimmed = c.trim();
          if (trimmed.isNotEmpty) return trimmed;
        }
      }
    } catch (_) {}
    return 'User';
  }

  String _fmtTs(Timestamp? ts) {
    final dt = ts?.toDate();
    if (dt == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _initials(String name) {
    final parts =
    name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      final s = parts.first;
      return s.isEmpty ? 'U' : s[0].toUpperCase();
    }
    final a = parts.first.isEmpty ? 'U' : parts.first[0];
    final b = parts.last.isEmpty ? '' : parts.last[0];
    return (a + b).toUpperCase();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? widget.currentUserId;
      String? photoUrl = user?.photoURL;

      if (photoUrl == null || photoUrl.trim().isEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final u = snap.data() ?? const <String, dynamic>{};
          final p = (u['photoUrl'] ?? '').toString().trim();
          if (p.isNotEmpty) photoUrl = p;
        } catch (_) {}
      }

      final name = await _resolveCurrentUserName();

      await PostService.addComment(
        postId: widget.postId,
        text: text,
        userId: uid,
        userName: name,
        photoUrl: photoUrl,
      );

      _controller.clear();
      FocusScope.of(context).unfocus();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send comment')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return SafeArea(
      child: SizedBox(
        height: media.size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            const ListTile(
              title: Text(
                'Comments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: PostService.commentsStream(widget.postId),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(child: Text('Failed to load comments'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs.toList();

                  docs.sort((a, b) {
                    final ta = a.data()['createdAt'];
                    final tb = b.data()['createdAt'];
                    if (ta is! Timestamp && tb is! Timestamp) return 0;
                    if (ta is! Timestamp) return 1;
                    if (tb is! Timestamp) return -1;
                    return ta.compareTo(tb);
                  });

                  if (docs.isEmpty) {
                    return const Center(child: Text('No comments yet.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final text = (data['text'] ?? '').toString();
                      final uid = (data['uid'] ?? '').toString();
                      final createdAt = data['createdAt'] as Timestamp?;
                      final storedName =
                      (data['username'] ?? data['userName'] ?? 'User')
                          .toString();
                      final storedPhoto =
                      (data['photoUrl'] ?? '').toString().trim();

                      if (uid.isEmpty) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                            AppColors.primaryGreen.withOpacity(0.1),
                            child: Text(
                              _initials(storedName),
                              style:
                              const TextStyle(color: AppColors.primaryGreen),
                            ),
                          ),
                          title: Text(storedName),
                          subtitle: Text(text),
                          trailing: Text(
                            _fmtTs(createdAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                        );
                      }

                      return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .snapshots(),
                        builder: (context, userSnap) {
                          final u = userSnap.data?.data();
                          final liveName = (u?['displayName'] ??
                              u?['name'] ??
                              u?['username'] ??
                              u?['Username'] ??
                              '')
                              .toString()
                              .trim();
                          final livePhoto =
                          (u?['photoUrl'] ?? '').toString().trim();

                          final name = liveName.isNotEmpty ? liveName : storedName;
                          final photoUrl = livePhoto.isNotEmpty
                              ? livePhoto
                              : (storedPhoto.isNotEmpty ? storedPhoto : '');

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                              photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                              backgroundColor:
                              AppColors.primaryGreen.withOpacity(0.1),
                              child: photoUrl.isEmpty
                                  ? Text(
                                _initials(name),
                                style: const TextStyle(
                                    color: AppColors.primaryGreen),
                              )
                                  : null,
                            ),
                            title: Text(name),
                            subtitle: Text(text),
                            trailing: Text(
                              _fmtTs(createdAt),
                              style: const TextStyle(fontSize: 12),
                            ),
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: InputField(
                      inputController: _controller,
                      obscuring: false,
                      label: 'Add a comment...',
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send, color: AppColors.primaryGreen),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
