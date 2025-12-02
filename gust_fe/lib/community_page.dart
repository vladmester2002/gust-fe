import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:another_flushbar/flushbar.dart';
import 'constants.dart'; // <-- baseUrl
import 'services/auth_helper.dart';
import 'package:provider/provider.dart';
import 'state/home_view_model.dart';

class UserRankingResponse {
  final String name;
  final int score;

  UserRankingResponse({
    required this.name,
    required this.score,
  });

  factory UserRankingResponse.fromJson(Map<String, dynamic> json) =>
      UserRankingResponse(
        name: json['name'] ?? '',
        score: json['score'] ?? 0,
      );
}

class CommunityPost {
  final int? id;
  final String userName;
  final String content;
  final String type; // 'achievement', 'milestone', 'tip', 'support'
  final DateTime createdAt;
  final int likesCount;
  final bool likedByUser;

  CommunityPost({
    this.id,
    required this.userName,
    required this.content,
    required this.type,
    required this.createdAt,
    this.likesCount = 0,
    this.likedByUser = false,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'],
      userName: json['userName'] ?? json['user_name'] ?? 'Anonymous',
      content: json['content'] ?? '',
      type: json['type'] ?? 'support',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      likesCount: json['likesCount'] ?? json['likes_count'] ?? 0,
      likedByUser: json['likedByUser'] ?? json['liked_by_user'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'type': type,
    };
  }
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Rankings data
  List<UserRankingResponse> rankings = [];
  bool loadingRankings = true;
  String period = "monthly";
  String? rankingsError;
  
  // Feed data
  List<CommunityPost> posts = [];
  bool loadingPosts = true;
  String? postsError;
  
  String? currentUserName;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // Rebuild on tab change
      }
    });
    _loadUserName();
    _checkGuestMode();
    _fetchRankings();
    _fetchPosts();
  }

  Future<void> _checkGuestMode() async {
    final isGuest = await AuthHelper.isGuestSession();
    if (mounted) {
      setState(() => _isGuest = isGuest);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    // Assumes you save the name at login/registration in prefs
    setState(() {
      currentUserName = prefs.getString('user_name');
    });
  }

  Future<String?> _getToken() => AuthHelper.getNetworkToken();

  Future<void> _fetchRankings() async {
    setState(() {
      loadingRankings = true;
      rankingsError = null;
    });
    try {
      final token = _isGuest ? null : await _getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final resp = await http.get(
        Uri.parse('$baseUrl/api/community/rankings?period=$period'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            rankings = (data as List)
                .map((e) => UserRankingResponse.fromJson(e))
                .toList();
            loadingRankings = false;
          });
        }
        return;
      }
    } catch (e) {
      print('Error fetching rankings: $e');
    }

    if (mounted) {
      setState(() {
        rankings = _getMockRankings();
        loadingRankings = false;
      });
    }
  }

  List<UserRankingResponse> _getMockRankings() {
    return [
      UserRankingResponse(name: currentUserName ?? "You", score: 850),
      UserRankingResponse(name: "Sarah J.", score: 920),
      UserRankingResponse(name: "Mike T.", score: 880),
      UserRankingResponse(name: "Emma R.", score: 850),
      UserRankingResponse(name: "David L.", score: 780),
      UserRankingResponse(name: "Lisa M.", score: 750),
      UserRankingResponse(name: "Alex K.", score: 720),
      UserRankingResponse(name: "Chris P.", score: 690),
      UserRankingResponse(name: "Jordan B.", score: 660),
      UserRankingResponse(name: "Taylor S.", score: 620),
    ]..sort((a, b) => b.score.compareTo(a.score));
  }

  Future<void> _fetchPosts() async {
    setState(() {
      loadingPosts = true;
      postsError = null;
    });

    try {
      // Guests can try to fetch without token, authenticated users use token
      final token = _isGuest ? null : await _getToken();
      
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Try to fetch from backend with timeout
      try {
        final resp = await http.get(
          Uri.parse('$baseUrl/api/community/feed'),
          headers: headers,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            return http.Response('Timeout', 408);
          },
        );
        
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final fetchedPosts = (data as List)
              .map((e) => CommunityPost.fromJson(e))
              .toList();
          
          // Cache the posts locally
          await _savePostsToCache(fetchedPosts);
          
          if (mounted) {
            setState(() {
              posts = fetchedPosts;
              loadingPosts = false;
            });
          }
          return;
        }
      } catch (e) {
        print('Community feed API error: $e');
        // Try to load from cache when offline
        final cachedPosts = await _loadPostsFromCache();
        if (cachedPosts.isNotEmpty) {
          if (mounted) {
            setState(() {
              posts = cachedPosts;
              loadingPosts = false;
            });
          }
          return;
        }
      }
      
      // Final fallback to mock community posts
      if (mounted) {
        setState(() {
          posts = _getMockPosts();
          loadingPosts = false;
        });
      }
    } catch (e) {
      print('Error fetching posts: $e');
      // Try cache before mock data
      final cachedPosts = await _loadPostsFromCache();
      if (mounted) {
        setState(() {
          posts = cachedPosts.isNotEmpty ? cachedPosts : _getMockPosts();
          postsError = null;
          loadingPosts = false;
        });
      }
    }
  }

  Future<void> _savePostsToCache(List<CommunityPost> postsToCache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = postsToCache
          .map((post) => jsonEncode({
                'id': post.id,
                'userName': post.userName,
                'content': post.content,
                'type': post.type,
                'createdAt': post.createdAt.toIso8601String(),
                'likesCount': post.likesCount,
                'likedByUser': post.likedByUser,
              }))
          .toList();
      await prefs.setStringList('cached_community_posts', postsJson);
    } catch (e) {
      print('Error caching posts: $e');
    }
  }

  Future<List<CommunityPost>> _loadPostsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = prefs.getStringList('cached_community_posts');
      if (postsJson == null || postsJson.isEmpty) return [];
      
      return postsJson
          .map((jsonStr) {
            final json = jsonDecode(jsonStr);
            return CommunityPost(
              id: json['id'],
              userName: json['userName'] ?? 'Anonymous',
              content: json['content'] ?? '',
              type: json['type'] ?? 'support',
              createdAt: DateTime.parse(json['createdAt']),
              likesCount: json['likesCount'] ?? 0,
              likedByUser: json['likedByUser'] ?? false,
            );
          })
          .toList();
    } catch (e) {
      print('Error loading cached posts: $e');
      return [];
    }
  }

  Future<bool> _isOnline() async {
    try {
      final token = await _getToken();
      // Try a simple HEAD request to the rankings endpoint (lightweight)
      final response = await http.head(
        Uri.parse('$baseUrl/api/community/rankings?period=daily'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 3));
      return response.statusCode < 500; // Accept any non-server-error response
    } catch (e) {
      // Any network error means we're offline
      return false;
    }
  }

  List<CommunityPost> _getMockPosts() {
    return [
      CommunityPost(
        id: 1,
        userName: "Sarah J.",
        content: "🎉 7 days streak! Stayed under my goal all week!",
        type: "achievement",
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        likesCount: 24,
      ),
      CommunityPost(
        id: 2,
        userName: "Mike T.",
        content: "Tip: I switched to sparkling water with lemon when I crave soda. Game changer! 🍋",
        type: "tip",
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        likesCount: 18,
      ),
      CommunityPost(
        id: 3,
        userName: "Emma R.",
        content: "Had a tough day but logged everything honestly. Progress over perfection! 💪",
        type: "support",
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        likesCount: 31,
      ),
      CommunityPost(
        id: 4,
        userName: "David L.",
        content: "🏆 Hit my 30-day milestone! Down 15g average per day!",
        type: "milestone",
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        likesCount: 45,
      ),
      CommunityPost(
        id: 5,
        userName: "Lisa M.",
        content: "Anyone else find weekends harder? Looking for motivation 🙏",
        type: "support",
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        likesCount: 12,
      ),
      CommunityPost(
        id: 6,
        userName: "Alex K.",
        content: "Reading labels has become second nature now. Small wins add up! 📊",
        type: "achievement",
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        likesCount: 22,
      ),
    ];
  }

  Future<void> _toggleLike(CommunityPost post) async {
    // Check if online first
    final isOnline = await _isOnline();
    if (!isOnline) {
      if (mounted) {
        await Flushbar<void>(
          message: '⚠️ You\'re offline. Please connect to the internet to like posts.',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.orange,
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.wifi_off, color: Colors.white),
        ).show(context);
      }
      return;
    }

    // Optimistic update
    setState(() {
      final index = posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        posts[index] = CommunityPost(
          id: post.id,
          userName: post.userName,
          content: post.content,
          type: post.type,
          createdAt: post.createdAt,
          likesCount: post.likedByUser ? post.likesCount - 1 : post.likesCount + 1,
          likedByUser: !post.likedByUser,
        );
      }
    });

    // Try to update on backend
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('$baseUrl/api/community/posts/${post.id}/like'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
    } catch (e) {
      // Revert on error
      setState(() {
        final index = posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          posts[index] = post;
        }
      });
    }
  }

  void _showCreatePostDialog() async {
    // Check if online first
    final isOnline = await _isOnline();
    if (!isOnline) {
      if (mounted) {
        await Flushbar<void>(
          message: '⚠️ You\'re offline. Please connect to the internet to create posts.',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.orange,
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.wifi_off, color: Colors.white),
        ).show(context);
      }
      return;
    }
    
    void _showDialog() {
    final contentController = TextEditingController();
    String selectedType = 'achievement';
    
    final typeOptions = [
      {'value': 'achievement', 'label': 'Achievement', 'emoji': '🎉', 'color': const Color(0xFFFFA726)},
      {'value': 'milestone', 'label': 'Milestone', 'emoji': '🏆', 'color': const Color(0xFF66BB6A)},
      {'value': 'tip', 'label': 'Tip', 'emoji': '💡', 'color': const Color(0xFFFF9800)},
      {'value': 'support', 'label': 'Support', 'emoji': '🤝', 'color': const Color(0xFFEC407A)},
    ];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF3E5F5),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A1B9A).withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6A1B9A).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.create_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Share with Community',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Post Type',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D1B47),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: typeOptions.map((type) {
                          final isSelected = selectedType == type['value'];
                          final color = type['color'] as Color;
                          
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedType = type['value'] as String;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [color, color.withOpacity(0.7)],
                                      )
                                    : null,
                                color: isSelected ? null : color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? color : color.withOpacity(0.3),
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    type['emoji'] as String,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    type['label'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isSelected ? Colors.white : color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Your Message',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D1B47),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: contentController,
                          maxLines: 5,
                          maxLength: 200,
                          decoration: InputDecoration(
                            hintText: 'Share your thoughts, achievements, or tips...',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Color(0xFF2D1B47),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6A1B9A).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (contentController.text.trim().isNotEmpty) {
                                Navigator.pop(context);
                                _createPost(contentController.text.trim(), selectedType);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Share Post',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    }
    
    _showDialog();
  }

  Future<void> _createPost(String content, String type) async {
    final newPost = CommunityPost(
      userName: currentUserName ?? 'You',
      content: content,
      type: type,
      createdAt: DateTime.now(),
      likesCount: 0,
      likedByUser: false,
    );

    // Try to save to backend
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(newPost.toJson()),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - add to local list
        setState(() {
          posts.insert(0, newPost);
        });
        
        // Show success message
        if (mounted) {
          await Flushbar<void>(
            message: 'Post published successfully!',
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            flushbarPosition: FlushbarPosition.TOP,
            margin: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(8),
            icon: const Icon(Icons.check_circle, color: Colors.white),
          ).show(context);
        }
      } else {
        // Server error
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Check if this is a network error
      final errorString = e.toString().toLowerCase();
      final isNetworkError = errorString.contains('network') || 
                            errorString.contains('connection') || 
                            errorString.contains('offline') ||
                            errorString.contains('socketexception') ||
                            errorString.contains('failed host lookup');
      
      if (mounted) {
        await Flushbar<void>(
          message: isNetworkError 
            ? '⚠️ You\'re offline. Please connect to the internet to post in the community.'
            : 'Failed to create post: ${e.toString()}',
          duration: const Duration(seconds: 4),
          backgroundColor: isNetworkError ? Colors.orange : Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          icon: Icon(
            isNetworkError ? Icons.wifi_off : Icons.error,
            color: Colors.white,
          ),
        ).show(context);
      }
    }
  }

  String getPeriodText(String period) {
    switch (period) {
      case "monthly":
        return "This Month";
      case "daily":
        return "Today";
      case "yearly":
        return "This Year";
      default:
        return "Period";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Community",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Color(0xFF2D1B47),
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6A1B9A),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF6A1B9A),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.feed_rounded, size: 22),
                  text: "Feed",
                ),
                Tab(
                  icon: Icon(Icons.trending_up_rounded, size: 22),
                  text: "My Progress",
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (_tabController.index == 1)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF6A1B9A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (val) {
                  setState(() => period = val);
                  _fetchRankings();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: "daily",
                    child: Row(
                      children: [
                        Icon(Icons.today, size: 18, color: Color(0xFF6A1B9A)),
                        SizedBox(width: 12),
                        Text("Today"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: "monthly",
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, size: 18, color: Color(0xFF6A1B9A)),
                        SizedBox(width: 12),
                        Text("This Month"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: "yearly",
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Color(0xFF6A1B9A)),
                        SizedBox(width: 12),
                        Text("This Year"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedTab(),
          _buildRankingsTab(),
        ],
      ),

    );
  }

  Widget _buildFeedTab() {
    if (loadingPosts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF6A1B9A),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading community feed...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6A1B9A),
              ),
            ),
          ],
        ),
      );
    }

    if (posts.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFF6A1B9A).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A1B9A).withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6A1B9A).withOpacity(0.2),
                      const Color(0xFF8E24AA).withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 64,
                  color: Color(0xFF6A1B9A),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No posts yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D1B47),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to share your journey!',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'Create Post',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                onPressed: _showCreatePostDialog,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPosts,
      color: const Color(0xFF6A1B9A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Tips Section - Most important for users
          _buildQuickTipsSection(),
          const SizedBox(height: 20),
          
          // Daily Motivation Card
          _buildMotivationCard(),
          const SizedBox(height: 20),
          
          // Post+ Button (visible for authenticated users)
          if (!_isGuest)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: InkWell(
                onTap: _showCreatePostDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6A1B9A).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Share Your Journey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Community Posts
          const Row(
            children: [
              Icon(Icons.forum_rounded, color: Color(0xFF6A1B9A), size: 22),
              SizedBox(width: 8),
              Text(
                'Community Feed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D1B47),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          ...posts.map((post) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPostCard(post),
          )),
        ],
      ),
    );
  }

  Widget _buildQuickTipsSection() {
    final tips = [
      {
        'icon': Icons.water_drop_rounded,
        'color': const Color(0xFF42A5F5),
        'title': 'Stay Hydrated',
        'tip': 'Drink water when craving sweets',
      },
      {
        'icon': Icons.restaurant_rounded,
        'color': const Color(0xFF66BB6A),
        'title': 'Read Labels',
        'tip': 'Check sugar content before buying',
      },
      {
        'icon': Icons.self_improvement_rounded,
        'color': const Color(0xFFEC407A),
        'title': 'Stay Active',
        'tip': '10 min walk helps reduce cravings',
      },
      {
        'icon': Icons.bedtime_rounded,
        'color': const Color(0xFF9C27B0),
        'title': 'Sleep Well',
        'tip': 'Better sleep = fewer sugar cravings',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6A1B9A),
            Color(0xFF8E24AA),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A1B9A).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lightbulb_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Tips',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Daily healthy habits',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 145,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: tips.length,
              itemBuilder: (context, index) {
                final tip = tips[index];
                return Container(
                  width: 170,
                  margin: const EdgeInsets.only(left: 8, right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (tip['color'] as Color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            tip['icon'] as IconData,
                            color: tip['color'] as Color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tip['title'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D1B47),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            tip['tip'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard() {
    final motivations = [
      {'text': 'Every small step counts! 🌟', 'emoji': '💪'},
      {'text': 'You\'re doing amazing! Keep it up! 🎉', 'emoji': '🚀'},
      {'text': 'Progress, not perfection! 💫', 'emoji': '⭐'},
      {'text': 'One day at a time! 🌈', 'emoji': '🎯'},
      {'text': 'Believe in yourself! ✨', 'emoji': '💎'},
    ];
    
    final motivation = motivations[DateTime.now().day % motivations.length];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFFFA726).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFA726).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA726).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFA726), Color(0xFFFF9800)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA726).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              motivation['emoji'] as String,
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Motivation',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9800),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  motivation['text'] as String,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D1B47),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post) {
    final isUserPost = post.userName == currentUserName || post.userName == 'You';
    
    IconData typeIcon;
    Color typeColor;
    String typeLabel;
    String typeEmoji;
    
    switch (post.type) {
      case 'achievement':
        typeIcon = Icons.emoji_events_rounded;
        typeColor = const Color(0xFFFFA726);
        typeLabel = 'Achievement';
        typeEmoji = '🎉';
        break;
      case 'milestone':
        typeIcon = Icons.flag_rounded;
        typeColor = const Color(0xFF66BB6A);
        typeLabel = 'Milestone';
        typeEmoji = '🏆';
        break;
      case 'tip':
        typeIcon = Icons.lightbulb_rounded;
        typeColor = const Color(0xFFFF9800);
        typeLabel = 'Tip';
        typeEmoji = '💡';
        break;
      case 'support':
        typeIcon = Icons.favorite_rounded;
        typeColor = const Color(0xFFEC407A);
        typeLabel = 'Support';
        typeEmoji = '🤝';
        break;
      default:
        typeIcon = Icons.chat_bubble_rounded;
        typeColor = const Color(0xFF42A5F5);
        typeLabel = 'Post';
        typeEmoji = '💬';
    }

    final timeAgo = _formatTimeAgo(post.createdAt);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            typeColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: typeColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isUserPost 
              ? const Color(0xFF6A1B9A).withOpacity(0.3)
              : typeColor.withOpacity(0.1),
          width: isUserPost ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {}, // Could add detail view later
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            typeColor.withOpacity(0.3),
                            typeColor.withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: typeColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          typeEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  post.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: Color(0xFF2D1B47),
                                    letterSpacing: -0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUserPost) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6A1B9A),
                                        Color(0xFF8E24AA),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6A1B9A).withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: typeColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(typeIcon, size: 12, color: typeColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      typeLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: typeColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Content
                Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Color(0xFF2D1B47),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        typeColor.withOpacity(0.1),
                        typeColor.withOpacity(0.3),
                        typeColor.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: post.likedByUser 
                            ? Colors.red.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          post.likedByUser ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: post.likedByUser ? Colors.red : Colors.grey[600],
                          size: 22,
                        ),
                        onPressed: () => _toggleLike(post),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: post.likedByUser 
                            ? Colors.red.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${post.likesCount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: post.likedByUser ? Colors.red : Colors.grey[700],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6A1B9A).withOpacity(0.1),
                            const Color(0xFF8E24AA).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton.icon(
                        icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                        label: const Text(
                          'Encourage',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6A1B9A),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () => _toggleLike(post),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildRankingsTab() {
    return Consumer<HomeViewModel>(
      builder: (context, viewModel, child) {
        final logs = viewModel.logs;
        final totalLogs = logs.length;
        final streakDays = viewModel.streak;
        
        // Calculate On Target %
        final onTargetCount = logs.where((l) => l.sugarGrams <= viewModel.dailyGoal).length;
        final onTargetPercentage = totalLogs > 0 ? (onTargetCount / totalLogs * 100).toInt() : 0;
        
        // Calculate Avg Intake
        double avgSugar = 0;
        if (totalLogs > 0) {
          final totalSugar = logs.fold<double>(0, (sum, item) => sum + item.sugarGrams);
          avgSugar = totalSugar / totalLogs;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Personal Stats Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6A1B9A),
                    Color(0xFF8E24AA),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A1B9A).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.insights_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          'Your Journey',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '$streakDays',
                          'Day Streak',
                          Icons.local_fire_department_rounded,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '$totalLogs',
                          'Total Logs',
                          Icons.assignment_turned_in_rounded,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '$onTargetPercentage%',
                          'On Target',
                          Icons.track_changes_rounded,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '${avgSugar.toStringAsFixed(1)}g',
                          'Avg Intake',
                          Icons.trending_down_rounded,
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Achievements Section
            const Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: Color(0xFF6A1B9A), size: 22),
                SizedBox(width: 8),
                Text(
                  'Achievements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D1B47),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            _buildAchievementCard(
              'First Week',
              'Complete 7 days of logging',
              Icons.celebration_rounded,
              const Color(0xFFFFA726),
              isUnlocked: streakDays >= 7,
              progress: streakDays,
              total: 7,
            ),
            const SizedBox(height: 12),
            
            _buildAchievementCard(
              'Consistent Logger',
              'Log sugar intake 30 days in a row',
              Icons.auto_graph_rounded,
              const Color(0xFF66BB6A),
              isUnlocked: streakDays >= 30,
              progress: streakDays,
              total: 30,
            ),
            const SizedBox(height: 12),
            
            _buildAchievementCard(
              'Sugar Tracker',
              'Track 100 sugar logs',
              Icons.track_changes_rounded,
              const Color(0xFF42A5F5),
              isUnlocked: totalLogs >= 100,
              progress: totalLogs,
              total: 100,
            ),
            
            const SizedBox(height: 24),
            
            // Health Tips Based on Progress
            const Row(
              children: [
                Icon(Icons.health_and_safety_rounded, color: Color(0xFF6A1B9A), size: 22),
                SizedBox(width: 8),
                Text(
                  'Personalized Tips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D1B47),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            _buildTipCard(
              'Great Progress!',
              'You\'re consistently staying under your daily goal. Keep up the amazing work!',
              Icons.thumb_up_rounded,
              Colors.green,
            ),
            const SizedBox(height: 12),
            
            _buildTipCard(
              'Weekend Challenge',
              'Try planning your meals ahead for the weekend to maintain your streak.',
              Icons.lightbulb_rounded,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            
            _buildTipCard(
              'Hydration Reminder',
              'Drinking water before meals can help reduce sugar cravings by up to 30%.',
              Icons.water_drop_rounded,
              Colors.blue,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D1B47),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(
    String title,
    String description,
    IconData icon,
    Color color, {
    bool isUnlocked = false,
    int? progress,
    int? total,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color.withOpacity(isUnlocked ? 0.1 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(isUnlocked ? 0.4 : 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isUnlocked
                  ? LinearGradient(colors: [color, color.withOpacity(0.7)])
                  : null,
              color: isUnlocked ? null : Colors.grey[300],
              shape: BoxShape.circle,
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isUnlocked ? Colors.white : Colors.grey[500],
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isUnlocked ? color : Colors.grey[700],
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'UNLOCKED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!isUnlocked && progress != null && total != null) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$progress / $total',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          Text(
                            '${((progress / total) * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress / total,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String title, String tip, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
