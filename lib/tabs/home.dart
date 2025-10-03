import 'package:flutter/material.dart';
import 'package:litter_lens/theme.dart';
import 'package:litter_lens/widgets/post_card.dart';
import 'package:litter_lens/tabs/post.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _postNameController = TextEditingController();
  final TextEditingController _postDetailController = TextEditingController();

  // dummy posts for now
  final List<PostCard> posts = [
    PostCard(
      username: "Duck Stroker",
      role: "ADMIN",
      roleColor: Color(0xFFF5BD02),
      time: "9/11/2001 8:46 AM",
      text:
          "Lorem ipsum dolor sit amet consectetur. In curabitur nisi ipsum volutpat dolor mattis porttitor fringilla.",
      imageUrl: "assets/images/placeholders/dashboard_placeholder.jpg",
      profileImage: "https://randomuser.me/api/portraits/men/32.jpg",
    ),
    PostCard(
      username: "J. Nolan",
      role: "RESIDENT",
      roleColor: Color(0xFFE73895),
      time: "9/11/2001 9:03 AM",
      text:
          "Lorem ipsum dolor sit amet consectetur. In curabitur nisi ipsum volutpat dolor mattis porttitor fringilla.",
      imageUrl: "assets/images/placeholders/dashboard_placeholder.jpg",
      profileImage: "https://randomuser.me/api/portraits/women/45.jpg",
    ),
  ];

  @override
  void dispose() {
    _postNameController.dispose();
    _postDetailController.dispose();
    super.dispose();
  }

  void _createPost() {
    // for example: open dialog and add to posts
    showDialog(
      context: context,
      builder: (_) => CreatePost(
        postNameController: _postNameController,
        postDetailController: _postDetailController,
        onSubmit: () {
          setState(() {
            posts.add(
              PostCard(
                username: "New User",
                role: "RESIDENT",
                roleColor: Colors.green,
                time: DateTime.now().toString(),
                text: _postDetailController.text,
                imageUrl:
                    "assets/images/placeholders/dashboard_placeholder.jpg",
                profileImage: "https://randomuser.me/api/portraits/lego/1.jpg",
              ),
            );
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(children: posts),
      floatingActionButton: ActionButton(
        onPressed: _createPost,
        icon: Icons.upload_rounded,
      ),
    );
  }
}
