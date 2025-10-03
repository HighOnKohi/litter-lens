// import 'package:flutter/material.dart';
// import 'package:litter_lens/theme.dart';

// class CreatePostDialog extends StatelessWidget {
//   final TextEditingController postNameController;
//   final TextEditingController postDetailController;
//   final VoidCallback onSubmit;

//   const CreatePostDialog({
//     super.key,
//     required this.postNameController,
//     required this.postDetailController,
//     required this.onSubmit,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text("Create Post"),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           InputField(
//             inputController: postNameController,
//             label: "Title",
//             obscuring: false,
//           ),
//           const SizedBox(height: 16),
//           InputField(
//             inputController: postDetailController,
//             label: "Details",
//             obscuring: false,
//           ),
//           const SizedBox(height: 24),
//           MediumGreenButton(onPressed: onSubmit, text: "Submit"),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () {
//             Navigator.of(context).pop();
//           },
//           style: TextButton.styleFrom(
//             textStyle: const TextStyle(
//               fontSize: 20,
//               color: Color.fromARGB(255, 255, 35, 35),
//             ),
//           ),
//           child: const Text("Close"),
//         ),
//       ],
//     );
//   }
// }
