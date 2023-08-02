import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:full_screen_image_null_safe/full_screen_image_null_safe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Post with ChangeNotifier {
  final String id;
  final String content;
  final String postCreator;
  final List<String> media;
  final List<Comment>? comments;
  final Map<String, ValueNotifier<int>> reactions;
  final Map<String, int> initialReactions;
  Map<String, bool>? userReactions;
  bool showAllComments; // New property to indicate whether to show all comments

  final Map<String, Map<String, dynamic>>?
      lastReactionState; // Make it nullable

  Post({
    required this.id,
    required this.content,
    required this.reactions,
    required this.initialReactions,
    this.userReactions,
    required this.media,
    required this.postCreator,
    this.showAllComments = false,
// Add the postCreator property

    Map<String, Map<String, dynamic>>? lastReactionState, // Make it nullable
    this.comments,
  }) : lastReactionState = lastReactionState ?? {};

  void _toggleUserReaction(String emoji, bool hasReacted) {
    userReactions ??= {};
    userReactions![emoji] = !hasReacted;
  }

  Future<void> updateEmoji(Post post, String emoji) async {
    final bool hasReacted = userReactions?[emoji] ?? false;

    if (hasReacted) {
      // If the user has already reacted, decrement the count and remove the reaction
      await _decrementEmoji(post.id, emoji);
      _toggleUserReaction(emoji, hasReacted);
    } else {
      // If the user hasn't reacted, increment the count and add the reaction
      final int currentCount = reactions[emoji]!.value;
      final int apiValue = initialReactions[emoji]!;
      final String url = '$baseUrl/posts/$id/reactions/$emoji';

      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');

      if (userId != null) {
        try {
          final response = await http.put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': userId, 'emoji': emoji}),
          );

          if (response.statusCode == 200) {
            reactions[emoji]!.value = currentCount + 1;
            _toggleUserReaction(emoji, hasReacted);
            notifyListeners(); // Notify listeners that the ValueNotifier has changed.
          } else {
            print('Failed to update emoji count: ${response.statusCode}');
          }
        } catch (error) {
          print('Error updating emoji count: $error');
        }
      } else {
        print('User ID not found in SharedPreferences');
      }
    }
  }

  Future<void> increaseEmojiCount(String postId, String emoji) async {
    final String url = '$baseUrl/posts/$postId/reactions/$emoji';
    final response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json
          .encode({'userId': 'userId', 'count': 1}), // Send the reaction count
    );

    if (response.statusCode == 200) {
      print('Successfully increased emoji count');
    } else {
      print('Failed to increase emoji count: ${response.statusCode}');
    }
  }

  Future<void> _decrementEmoji(String postId, String emoji) async {
    final String url = '$baseUrl/posts/$postId/reactions/$emoji/decrement';
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('userId');

    if (userId != null) {
      try {
        final response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'userId': userId}),
        );

        if (response.statusCode == 200) {
          // Successfully decremented the emoji count on the server.
          // Update the local count in the ValueNotifier.
          reactions[emoji]!.value = reactions[emoji]!.value - 1;
          notifyListeners(); // Notify listeners that the ValueNotifier has changed.
        } else {
          print('Failed to decrement emoji count: ${response.statusCode}');
        }
      } catch (error) {
        print('Error decrementing emoji count: $error');
      }
    } else {
      print('User ID not found in SharedPreferences');
    }
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    final reactions = <String, ValueNotifier<int>>{};
    final initialReactions = <String, int>{};

    final Map<String, dynamic> reactionData = json['reactions'] ?? {};
    for (final entry in reactionData.entries) {
      reactions[entry.key] = ValueNotifier<int>(entry.value ?? 0);
      initialReactions[entry.key] = entry.value ?? 0;
    }

    return Post(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      reactions: reactions,
      initialReactions: initialReactions,
      media: List<String>.from(json['media'] ?? []),
      comments: (json['comments'] as List<dynamic>?)
          ?.map((comment) => Comment.fromJson(comment))
          .toList(),
      postCreator: json['postCreator'] ??
          '', // Map the 'postCreator' from the JSON to the property
    );
  }
}

class Comment {
  final String?
      id; // Add this property to store the MongoDB ObjectId of the comment
  final String? comment;
  final String? username;
  final String?
      userId; // Add this property to store the userId of the comment creator

  Comment({
    required this.id,
    this.comment,
    this.username,
    this.userId,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'],
      comment: json['comment'],
      username: json['username'],
      userId: json['userId'], // Map the 'userId' from the JSON to the property
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Post> posts = [];
  List<TextEditingController> commentControllers = [];
  File? _imageFile;
  TextEditingController _contentController = TextEditingController();
  final ValueNotifier<bool> heartFilled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> likeFilled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> laughFilled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> sadFilled = ValueNotifier<bool>(false);
  bool _isFetchingPosts =
      false; // Add a flag to track whether posts are being fetched

  String usernameVolo = '';
  String userId = '';

  @override
  void initState() {
    super.initState();
    getValue().then((value) {
      setState(() {
        usernameVolo = value;
      });
    });
    getValueID().then((value) {
      setState(() {
        userId = value;
        fetchPosts();
      });
    });
  }

  void editPost(String postId, String content) async {
    final url = '$baseUrl/posts/$postId';
    final headers = {'Content-Type': 'application/json'};
    final body = json.encode({'content': content});

    try {
      final response =
          await http.put(Uri.parse(url), headers: headers, body: body);
      if (response.statusCode == 200) {
        final updatedPostData = json.decode(response.body);
        final updatedPost = Post.fromJson(updatedPostData);
        setState(() {
          final postIndex = posts.indexWhere((post) => post.id == postId);
          if (postIndex != -1) {
            posts[postIndex] = updatedPost;
          }
        });
        print('Post updated successfully');
      } else if (response.statusCode == 404) {
        print('Post not found');
      } else {
        print('Failed to update the post: ${response.statusCode}');
      }
    } catch (error) {
      print('Failed to update the post: $error');
    }
  }

  Future<void> _refreshEmojis(Post post) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/${post.id}/reactions'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Update the emoji counts in the post object based on the API response
        post.reactions['heart']!.value = data['heart'] ?? 0;
        post.reactions['sad']!.value = data['sad'] ?? 0;
        post.reactions['like']!.value = data['like'] ?? 0;
        post.reactions['laugh']!.value = data['laugh'] ?? 0;

        // Since the ValueNotifiers have been updated, the UI will automatically reflect the changes.
        setState(() {});
      } else {
        print('Failed to fetch emoji counts: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching emoji counts: $error');
    }
  }

  void _updateEmoji(Post post, String emoji) async {
    await post.updateEmoji(post, emoji);
    _refreshEmojis(post);
  }

  void _logoutUser(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.clear(); // Clear all data stored in SharedPreferences
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  void _showEditPostDialog(String postId, String initialContent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final contentController = TextEditingController(text: initialContent);

        return AlertDialog(
          title: Text('Edit Post'),
          content: TextField(
            controller: contentController,
            decoration: InputDecoration(
              hintText: 'Enter post content',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.deepOrange),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.deepOrange),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                  primary:
                      Colors.deepOrange), // Change button color to deep orange
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedContent = contentController.text.trim();
                if (updatedContent.isNotEmpty) {
                  editPost(postId, updatedContent);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                  primary:
                      Colors.deepOrange), // Change button color to deep orange
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCommentDialog(Post post, int commentIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final commentToDelete = post.comments?[commentIndex];
        final bool isCurrentUserCommentCreator =
            commentToDelete?.userId == userId;
        final bool isCurrentUserPostCreator = post.postCreator == userId;

        return AlertDialog(
          title: Text('Delete Comment'),
          content: Text('Are you sure you want to delete this comment?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            if (isCurrentUserCommentCreator || isCurrentUserPostCreator)
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteComment(post, commentIndex);
                },
                child: Text('Delete'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _deleteComment(Post post, int commentIndex) async {
    final Comment commentToDelete = post.comments![commentIndex];

    // Assuming userId is the current user's ID
    final prefs = await SharedPreferences.getInstance();
    final String? currentUserId = prefs.getString('userId');

    if (currentUserId != null &&
        (commentToDelete.userId == currentUserId ||
            post.postCreator == currentUserId)) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/posts/${post.id}/comments/${commentToDelete.id}'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          setState(() {
            post.comments!.removeAt(commentIndex);
          });
          print('Comment deleted successfully');
        } else {
          print('Failed to delete comment: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      } catch (error) {
        print('Error deleting comment: $error');
      }
    } else {
      print('Current user does not have permission to delete this comment.');
    }
  }

  void _showEditCommentDialog(
    Post post,
    int commentIndex,
    String initialComment,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final commentController = TextEditingController(text: initialComment);

        return AlertDialog(
          title: Text('Edit Comment'),
          content: TextField(
            controller: commentController,
            decoration: InputDecoration(hintText: 'Edit your comment...'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedComment = commentController.text.trim();
                if (updatedComment.isNotEmpty) {
                  await _editComment(post, commentIndex, updatedComment);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editComment(
      Post post, int commentIndex, String updatedComment) async {
    final Comment commentToEdit = post.comments![commentIndex];

    // Here, you can perform any additional checks if needed before editing the comment
    // For example, check if the current user is the creator of the comment.

    try {
      final String url =
          '$baseUrl/posts/${post.id}/comments/${commentToEdit.id}';
      final Map<String, String> headers = {'Content-Type': 'application/json'};
      final Map<String, dynamic> body = {'comment': updatedComment};

      final response = await http.put(Uri.parse(url),
          headers: headers, body: json.encode(body));

      if (response.statusCode == 200) {
        final updatedCommentData = json.decode(response.body);
        final updatedComment = Comment.fromJson(updatedCommentData);

        setState(() {
          post.comments![commentIndex] = updatedComment;
        });

        print('Comment updated successfully');
      } else {
        print('Failed to update comment: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (error) {
      print('Error updating comment: $error');
    }
  }

  void logoutUser(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  Future<String> getValue() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('usernameVolo');
    return username ?? '';
  }

  Future<String> getValueID() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    return userId ?? '';
  }

  Future<void> fetchPosts() async {
    if (_isFetchingPosts) return; // If already fetching, skip this call
    _isFetchingPosts =
        true; // Set the flag to true to indicate that posts are being fetched

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts'),
        headers: {'Accept': 'application/json'},
      );
      if (!_isFetchingPosts) return;

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        if (responseBody != null && responseBody.isNotEmpty) {
          final List<dynamic> data = json.decode(responseBody);
          final List<Post> fetchedPosts =
              data.map((post) => Post.fromJson(post)).toList();
          setState(() {
            posts = fetchedPosts;
          });
        } else {
          throw Exception('Empty response body');
        }
      } else {
        throw Exception('Failed to fetch posts');
      }
    } catch (error) {
      if (!_isFetchingPosts)
        return; // Check if the flag is still true before handling the error
      print('Error fetching posts: $error');
      // Handle the error gracefully, such as showing a snackbar or error message in the UI.
    } finally {
      // Reset the flag to false when done fetching, regardless of success or error
      _isFetchingPosts = false;
    }
  }

  Future<void> refreshPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId != null) {
        await fetchPosts(); // Fetch and update the posts list
      }
    } catch (error) {
      print('Error refreshing posts: $error');
    }
  }

  Future<void> deletePost(String postId) async {
    final String url = '$baseUrl/posts/$postId';
    final response = await http.delete(Uri.parse(url));
    if (response.statusCode == 200) {
      print('Post deleted successfully');
      await refreshPosts();
    } else {
      print('Failed to delete post: ${response.statusCode}');
    }
  }

  Future<void> signalPost(String postId, String userId) async {
    final url = Uri.parse('$baseUrl/posts/$postId/signal');
    final body = {'userId': userId}; // Include the userId in the request body

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      if (response.statusCode == 201) {
        print('Post signaled successfully');
      } else {
        print('Failed to signal post: ${response.statusCode}');
      }
    } catch (error) {
      print('Error signaling post: $error');
    }
  }

  Future<String> fetchPostImage(String postId) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/posts/$postId/image'));
      if (response.statusCode == 200) {
        return base64Encode(response.bodyBytes);
      } else {
        print('Failed to fetch post image: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching post image: $error');
    }
    return '';
  }

  Future<void> createComment(String postId, String comment, String username,
      String userId, TextEditingController commentController) async {
    final url = Uri.parse('$baseUrl/posts/$postId/comments');
    final body = {
      'comment': comment,
      'username': username,
      'userId': userId, // Include the userId in the request body
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final newComment = Comment(
          id: json.decode(response.body)['_id'],
          comment: comment,
          username: username,
          userId: userId, // Include the userId in the new comment
        );
        setState(() {
          final postIndex = posts.indexWhere((post) => post.id == postId);
          if (postIndex != -1) {
            posts[postIndex].comments?.add(newComment);
          }
        });
        commentController.clear(); // Clear the comment input
      } else {
        print('Failed to create comment: ${response.statusCode}');
      }
    } catch (error) {
      print('Error creating comment: $error');
    }
  }

  Widget _buildPostImage(String base64Image) {
    if (base64Image.isNotEmpty) {
      final decodedImage = base64Decode(base64Image);
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenWidget(
                child: Image.memory(decodedImage),
              ),
            ),
          );
        },
        child: Container(
          height: 200,
          width: double.infinity,
          child: Image.memory(decodedImage, fit: BoxFit.cover),
        ),
      );
    } else {
      return Container();
    }
  }

  void _createPost() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: 'Enter post content',
                ),
              ),
              SizedBox(height: 16),
              _imageFile != null ? Image.file(_imageFile!) : SizedBox.shrink(),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Select Image'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _createPostRequest();
                Navigator.of(context).pop();
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _createPostRequest() async {
    try {
      final String url = '$baseUrl/posts';
      final Uri uri = Uri.parse(url);

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      var request = http.MultipartRequest('POST', uri);
      request.fields['content'] = _contentController.text;
      request.fields['userId'] = userId!;

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
        await refreshPosts();
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
    for (var controller in commentControllers) {
      controller.dispose();
    }
    _isFetchingPosts =
        false; // Make sure to stop fetching posts before disposing the widget

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        leadingWidth: 120.0, // Set the width of the leading widget

        leading: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly, // Adjust the alignment of icons
          children: [
            IconButton(
              icon: Icon(Icons.home),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
            IconButton(
              icon: Icon(Icons.person),
              onPressed: () {
                // Navigate to profile page, replace with your desired route
                Navigator.pushReplacementNamed(context, '/postList');
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              _logoutUser(context);
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[200], // Set a light grey background color

      body: ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts.reversed.toList()[index]; // Reverse the posts list
          // Accessing the postCreator value
          final postCreator = post.postCreator;
          print("post creator id : $postCreator");
          // Create a new TextEditingController for each post comment section
          if (commentControllers.length <= index) {
            commentControllers.add(TextEditingController());
          }

          final commentController = commentControllers[index];

          Color getEmojiColor(String emojiName) {
            int count = post.reactions[emojiName]?.value ?? 0;

            if (count > 0) {
              switch (emojiName) {
                case 'heart':
                  return Colors.red;
                case 'like':
                  return Colors.blue;
                case 'laugh':
                  return const Color.fromARGB(
                      255, 215, 150, 51); // Orange color
                case 'sad':
                  return const Color.fromARGB(255, 184, 199, 7); // Yellow color
              }
            }

            return Colors.transparent; // Default transparent color
          }

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.flag),
                        onPressed: () {
                          print(
                              'User ID: $userId'); // Add this debug print statement
                          final userID = userId ?? '';
                          signalPost(post.id, userID);
                        },
                      ),
                    ],
                  ),
                  Text(
                    post.content,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 18),
                  FutureBuilder<String>(
                    future: fetchPostImage(post.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final base64Image = snapshot.data!;
                        return _buildPostImage(base64Image);
                      } else if (snapshot.hasError) {
                        return Icon(Icons.image_not_supported);
                      } else {
                        return CircularProgressIndicator();
                      }
                    },
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _updateEmoji(post, 'heart');
                          });
                        },
                        child: ValueListenableBuilder<int>(
                          valueListenable: post.reactions['heart']!,
                          builder: (context, value, _) {
                            return Row(
                              children: [
                                ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    getEmojiColor('heart'),
                                    BlendMode.srcATop,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/heart.svg',
                                    width: 24,
                                    height: 24,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  post.reactions['heart']!.value > 0
                                      ? '+$value'
                                      : '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _updateEmoji(post, 'like');
                          });
                        },
                        child: ValueListenableBuilder<int>(
                          valueListenable: post.reactions['like']!,
                          builder: (context, value, _) {
                            return Row(
                              children: [
                                ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    getEmojiColor('like'),
                                    BlendMode.srcATop,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/like.svg',
                                    width: 24,
                                    height: 24,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  post.reactions['like']!.value > 0
                                      ? '+$value'
                                      : '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _updateEmoji(post, 'laugh');
                          });
                        },
                        child: ValueListenableBuilder<int>(
                          valueListenable: post.reactions['laugh']!,
                          builder: (context, value, _) {
                            return Row(
                              children: [
                                ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    getEmojiColor('laugh'),
                                    BlendMode.srcATop,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/laugh.svg',
                                    width: 24,
                                    height: 24,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  post.reactions['laugh']!.value > 0
                                      ? '+$value'
                                      : '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _updateEmoji(post, 'sad');
                          });
                        },
                        child: ValueListenableBuilder<int>(
                          valueListenable: post.reactions['sad']!,
                          builder: (context, value, _) {
                            return Row(
                              children: [
                                ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    getEmojiColor('sad'),
                                    BlendMode.srcATop,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/sad.svg',
                                    width: 24,
                                    height: 24,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  post.reactions['sad']!.value > 0
                                      ? '+$value'
                                      : '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: post.comments != null ? 20 : 0),
                  if (post.comments != null)
                    Column(
                      children: [
                        // Show the first three comments or all comments based on 'showAllComments'
                        ...post.comments!.reversed
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) {
                          final commentIndex = entry.key;
                          final comment = entry.value;

                          if (!post.showAllComments && commentIndex >= 3) {
                            return Container(); // Don't show additional comments
                          }

                          // Determine if the current user is the creator of the comment
                          final bool isCurrentUserCommentCreator = comment
                                  .userId ==
                              userId; // Assuming userId is the current user's ID

                          // Determine if the current user is the post creator
                          final bool isCurrentUserPostCreator =
                              post.postCreator == userId;

                          // Show delete action if the current user is either the comment creator or the post creator
                          final bool showDeleteAction =
                              isCurrentUserCommentCreator ||
                                  isCurrentUserPostCreator;

                          return Slidable(
                            key: ValueKey(comment.id),
                            endActionPane: ActionPane(
                              motion: ScrollMotion(),
                              children: [
                                if (isCurrentUserCommentCreator)
                                  SlidableAction(
                                    onPressed: (context) {
                                      _showEditCommentDialog(
                                        post,
                                        commentIndex,
                                        comment.comment ??
                                            '', // Provide default value when comment.comment is null
                                      );
                                    },
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    icon: Icons.edit,
                                    label: 'Edit',
                                  ),
                                if (showDeleteAction) // Only show delete for the comment creator or the post creator
                                  SlidableAction(
                                    onPressed: (context) {
                                      _showDeleteCommentDialog(
                                          post, commentIndex);
                                    },
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: 'Delete',
                                  ),
                              ],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(comment.username?[0] ?? ''),
                              ),
                              title: Text(comment.comment ?? ''),
                            ),
                          );
                        }).toList(),
                        if (!post.showAllComments && post.comments!.length > 3)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                post.showAllComments = true;
                              });
                            },
                            child: Text('See more comments'),
                          ),
                      ],
                    ),
                  Divider(
                    thickness: 1,
                    height: 0,
                  ),
                  SizedBox(height: post.comments != null ? 20 : 0),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.deepOrange)),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.deepOrange),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () {
                            final commentText = commentController.text.trim();
                            if (commentText.isNotEmpty) {
                              createComment(
                                post.id,
                                commentText,
                                usernameVolo ?? '',
                                userId, // Pass the userId here
                                commentController,
                              );
                              commentController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton(
            onPressed: _createPost,
            child: Text(
              'Create Post',
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              primary: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                    color: Colors.white), // Add border side for cool effect
              ),
            ),
          ),
        ),
      ),
    );
  }
}
