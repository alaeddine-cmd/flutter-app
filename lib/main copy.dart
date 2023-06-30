import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:full_screen_image_null_safe/full_screen_image_null_safe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Media App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Post> posts = [];
  List<TextEditingController> _postTextControllers = [];

  @override
  void dispose() {
    for (final controller in _postTextControllers) {
      controller.dispose();
    }
    super.dispose();
  }



  void _createPost(String content, List<Media> mediaList) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://192.168.1.19:8080/api/posts'));

      // Add content field
      request.fields['content'] = content;

      // Add media files if available
      if (mediaList != null && mediaList.isNotEmpty) {
        for (var media in mediaList) {
          var file = File(media.path);
          request.files
              .add(await http.MultipartFile.fromPath('image', file.path));
        }
      }

      // Send the request
      var response = await request.send();

// Check the response status code
      if (response.statusCode == 201) {
        // Post created successfully
        var responseData = await response.stream.bytesToString();
        var parsedResponse = json.decode(responseData);
        print('Post created: $parsedResponse');
      } else {
        // Failed to create post
        print('Error creating post: ${response.statusCode}');
        print('Error creating post. Response body: ${response}');
        print('Error response headers: ${response.headers}');
      }
    } catch (error) {
      // Handle any exceptions
      print('Error creating post: $error');
    }
  }

  void _reactToPost(Post post, String emoji) {
    if (post.reactions.containsKey(emoji)) {
      if (post.reactions[emoji] == 1) {
        post.reactions.remove(emoji);
      } else {
        post.reactions[emoji] = 1;
      }
    } else {
      post.reactions.clear();
      post.reactions[emoji] = 1;
    }
  }

  void _editPost(Post post, TextEditingController textController) {
    showDialog(
      context: context,
      builder: (context) {
        final editController = TextEditingController(text: post.content);

        return AlertDialog(
          title: const Text('Edit Post'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(
              hintText: 'Enter your post...',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                setState(() {
                  post.content = editController.text;
                  textController.text = editController.text;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deletePost(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                setState(() {
                  posts.removeAt(index);
                  _postTextControllers.removeAt(index);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Media App'),
      ),
      body: ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final textController = _postTextControllers[index];

          return PostItem(
            post: post,
            onComment: (comment) {
              setState(() {
                post.addComment(comment);
              });
            },
            onReact: (emoji) {
              setState(() {
                _reactToPost(post, emoji);
              });
            },
            onEdit: () {
              _editPost(post, textController);
            },
            onDelete: () {
              _deletePost(index);
            },
            onSignal: () {
              setState(() {
                post.signalPost();
              });
            },
            commentTextController: TextEditingController(),
            postTextController: textController,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              final textController = TextEditingController();

              return AlertDialog(
                title: const Text('Create a Post'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: textController,
                        decoration: const InputDecoration(
                          hintText: 'Enter your post...',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final imagePicker = ImagePicker();
                            final pickedImage = await imagePicker.pickImage(
                                source: ImageSource.gallery);
                            if (pickedImage != null) {
                              final media =
                                  Media(pickedImage.path, MediaType.image);
                              _createPost(textController.text, [media]);
                              textController.clear();
                              Navigator.of(context).pop();
                            }
                          } catch (e, stackTrace) {
                            print('Error loading image: $e\n$stackTrace');
                          }
                        },
                        child: const Text('Add Image'),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: const Text('Post'),
                    onPressed: () {
                      final postContent = textController.text;
                      if (postContent.isNotEmpty) {
                        _createPost(postContent, []);
                        textController.clear();
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class Post {
  String content;
  List<Media> media = [];
  List<Comment> comments = [];
  Map<String, int> reactions = {};
  bool signaled = false;

  Post({required this.content, required this.media});

  void addComment(String content) {
    final comment = Comment(content: content);
    comments.add(comment);
  }

  void signalPost() {
    signaled = true;
  }
}

class Media {
  final String path;
  final MediaType type;

  Media(this.path, this.type);
}

enum MediaType {
  image,
  video,
}

class Comment {
  final String content;

  Comment({required this.content});
}

class PostItem extends StatefulWidget {
  const PostItem({
    Key? key,
    required this.post,
    required this.onComment,
    required this.onReact,
    required this.onEdit,
    required this.onDelete,
    required this.onSignal,
    required this.commentTextController,
    required this.postTextController,
  }) : super(key: key);

  final Post post;
  final Function(String) onComment;
  final Function(String) onReact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSignal;
  final TextEditingController commentTextController;
  final TextEditingController postTextController;

  @override
  _PostItemState createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: widget.post.signaled ? Colors.red[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.post.content,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: widget.onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: widget.onDelete,
              ),
              IconButton(
                icon: const Icon(Icons.warning),
                color: widget.post.signaled ? Colors.red : null,
                onPressed: widget.onSignal,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.post.media.isNotEmpty)
            Column(
              children: [
                for (final media in widget.post.media) ...[
                  if (media.type == MediaType.image)
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => FullScreenWidget(
                            child: Center(
                              child: Image.file(
                                File(media.path),
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
                          File(media.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildReactionButton('❤️'), // Heart emoji reaction button
                      const SizedBox(width: 10),
                      _buildReactionButton(
                          '👍'), // Thumbs-up emoji reaction button
                      const SizedBox(width: 10),
                      _buildReactionButton('😢'), // Sad emoji reaction button
                      const SizedBox(width: 10),
                      _buildReactionButton(
                          '😂'), // Laughing emoji reaction button
                    ],
                  ),
                ],
              ],
            ),
          if (widget.post.comments.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Comments:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ListView.builder(
                  itemCount: widget.post.comments.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final comment = widget.post.comments[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.pink,
                        child: Text('A', style: TextStyle(color: Colors.white)),
                      ),
                      title: Text(comment.content),
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.commentTextController,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final commentContent = widget.commentTextController.text;
                  if (commentContent.isNotEmpty) {
                    widget.onComment(commentContent);
                    widget.commentTextController.clear();
                  }
                },
                child: const Text('Comment'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactionButton(String reaction) {
    return ElevatedButton(
      onPressed: () {
        // Handle reaction button pressed
      },
      style: ElevatedButton.styleFrom(
        primary: Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(reaction),
    );
  }
}
