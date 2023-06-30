import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Post {
  final String author;
  final String content;

  Post({
    required this.author,
    required this.content,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      author: json['author'],
      content: json['content'],
    );
  }
}

Future<List<Post>> fetchPosts() async {
  final response = await http.get(Uri.parse('http://192.168.1.19:8080/api/posts'));
  
  if (response.statusCode == 200) {
    final List<dynamic> responseData = json.decode(response.body);
    
    // Map the JSON data to a list of Post objects
    return responseData.map((postJson) => Post.fromJson(postJson)).toList();
  } else {
    throw Exception('Failed to fetch posts');
  }
}

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

  @override
  void initState() {
    super.initState();
    fetchPosts().then((fetchedPosts) {
      setState(() {
        posts = fetchedPosts;
      });
    }).catchError((error) {
      print('Error fetching posts: $error');
      // Handle the error accordingly
    });
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

          return ListTile(
            title: Text(post.content),
            subtitle: Text('Author: ${post.author}'),
          );
        },
      ),
    );
  }
}
