import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ScanTab extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ScanTab({super.key, required this.cameras});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  CameraController? _controller;
  File? _image;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final image = await _controller!.takePicture();

    final Directory? extDir = await getExternalStorageDirectory();
    final String folderPath = '${extDir!.path}/LitterLens';
    await Directory(folderPath).create(recursive: true);

    // // get app's documents directory
    // final Directory appDir = await getApplicationDocumentsDirectory();
    // final String folderPath = '${appDir.path}/LitterLens';
    // await Directory(folderPath).create(recursive: true); // ensure folder exists

    // create unique filename
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

    // save to the folder
    final String savedPath = '$folderPath/$fileName';
    final File savedImage = await File(image.path).copy(savedPath);

    setState(() {
      _image = savedImage;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _image = null;
        });
      }
    });

    debugPrint("📸 Saved image to: $savedPath");
  }

  Future<void> _pickFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final Directory? extDir = await getExternalStorageDirectory();
      final String folderPath = '${extDir!.path}/LitterLens';
      await Directory(folderPath).create(recursive: true);

      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = '$folderPath/$fileName';

      final File savedImage = await File(pickedFile.path).copy(savedPath);

      setState(() {
        _image = savedImage;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _image = null;
          });
        }
      });

      debugPrint("📂 Saved gallery image to: $savedPath");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // live camera preview
          Positioned.fill(child: CameraPreview(_controller!)),

          // preview of captured/selected image
          if (_image != null)
            Positioned.fill(child: Image.file(_image!, fit: BoxFit.cover)),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // gallery button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(240),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                    ),
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo, color: Colors.black),
                    label: const Text(
                      "Select from Gallery",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // shutter button
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.grey, width: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
