import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/post_service.dart';

class CreatePost extends StatefulWidget {
  final TextEditingController postNameController;
  final TextEditingController postDetailController;
  final Future<void> Function(String title, String desc, String? imageUrl) onSubmit;
  const CreatePost({
    super.key,
    required this.postNameController,
    required this.postDetailController,
    required this.onSubmit,
  });

  @override
  State<CreatePost> createState() => _CreatePostState();
}

class _CreatePostState extends State<CreatePost> {
  Uint8List? _imageBytes;
  bool _loading = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<void> _submit() async {
    final title = widget.postNameController.text.trim();
    final desc = widget.postDetailController.text.trim();
    if (title.isEmpty && desc.isEmpty) return;
    setState(() => _loading = true);
    String? imageUrl;
    try {
      if (_imageBytes != null) {
        imageUrl = await PostService.uploadPostImage(
          _imageBytes!,
          filename: 'post_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }
      await widget.onSubmit(title, desc, imageUrl);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created')),
      );
      widget.postNameController.clear();
      widget.postDetailController.clear();
      setState(() => _imageBytes = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Post'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.postNameController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: widget.postDetailController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_imageBytes!, height: 140, fit: BoxFit.cover),
              ),
            TextButton.icon(
              onPressed: _loading ? null : _pick,
              icon: const Icon(Icons.image),
              label: Text(_imageBytes == null ? 'Add Image' : 'Change Image'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Post'),
        ),
      ],
    );
  }
}
