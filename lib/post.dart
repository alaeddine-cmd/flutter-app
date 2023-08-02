import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:full_screen_image_null_safe/full_screen_image_null_safe.dart';
import 'config.dart';

class CreatePost extends StatefulWidget {
  const CreatePost({Key? key}) : super(key: key);

  @override
  _CreatePostState createState() => _CreatePostState();
}

class _CreatePostState extends State<CreatePost> {
  TextEditingController _contentController = TextEditingController();
  File? _imageFile;

  void _createPost() async {
    try {
      final String url = '$baseUrl/posts';
      final Uri uri = Uri.parse(url);

      var request = http.MultipartRequest('POST', uri);
      request.fields['content'] = _contentController.text;

      if (_imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _imageFile!.path,
        ));
      }

      var response = await request.send();

      if (response.statusCode == 201) {
        var responseData = await response.stream.bytesToString();
        var parsedResponse = json.decode(responseData);
        print('Post created: $parsedResponse');
        Navigator.popUntil(context, ModalRoute.withName('/'));
      } else {
        print('Error creating post: ${response.statusCode}');
        print('Error response body: ${await response.stream.bytesToString()}');
      }
    } catch (error) {
      print('Error creating post: $error');
    }
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _imageFile = File(pickedImage.path);
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: 'Enter your post...',
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Pick Image'),
            ),
            const SizedBox(height: 16.0),
            if (_imageFile != null)
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => FullScreenWidget(
                      child: Center(
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 200,
                  width: double.infinity,
                  child: Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _createPost,
              child: const Text('Create Post'),
            ),
          ],
        ),
      ),
    );
  }
}
