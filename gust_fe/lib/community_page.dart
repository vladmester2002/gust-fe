import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart'; // <-- baseUrl

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

class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<UserRankingResponse> rankings = [];
  bool loading = true;
  String period = "monthly";
  String? error;
  String? currentUserName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchRankings();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    // Assumes you save the name at login/registration in prefs
    setState(() {
      currentUserName = prefs.getString('user_name');
    });
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _fetchRankings() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final token = await _getToken();
      final resp = await http.get(
        Uri.parse('$baseUrl/api/community/rankings?period=$period'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      if (resp.statusCode != 200) {
        throw Exception(resp.body);
      }
      final data = jsonDecode(resp.body);
      setState(() {
        rankings = (data as List)
            .map((e) => UserRankingResponse.fromJson(e))
            .toList();
      });
    } catch (e) {
      setState(() {
        error = "Could not load rankings.\n${e.toString().replaceFirst('Exception: ', '')}";
      });
    }
    setState(() => loading = false);
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        backgroundColor: Colors.purple[100],
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Community Rankings",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                getPeriodText(period),
                key: ValueKey(period),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (val) {
              setState(() => period = val);
              _fetchRankings();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(child: Text("Monthly"), value: "monthly"),
              const PopupMenuItem(child: Text("Daily"), value: "daily"),
              const PopupMenuItem(child: Text("Yearly"), value: "yearly"),
            ],
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: loading
            ? Center(
                key: const ValueKey('loading'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading rankings...', style: TextStyle(fontSize: 15)),
                  ],
                ),
              )
            : error != null
                ? Center(
                    key: const ValueKey('error'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                          onPressed: _fetchRankings,
                        ),
                      ],
                    ),
                  )
                : rankings.isEmpty
                    ? Center(
                        key: const ValueKey('empty'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events, size: 48, color: Colors.purple),
                            const SizedBox(height: 10),
                            const Text("No rankings found.",
                                style: TextStyle(fontSize: 16, color: Colors.black54)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('list'),
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
                        itemCount: rankings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final user = rankings[i];
                          final rank = i + 1;
                          final bool isCurrentUser = (user.name.trim().toLowerCase() ==
                              (currentUserName?.trim().toLowerCase() ?? ""));
                          Color? color;
                          Widget? crown;
                          switch (rank) {
                            case 1:
                              color = Colors.amber;
                              crown = const Icon(Icons.emoji_events, color: Colors.amber, size: 26);
                              break;
                            case 2:
                              color = Colors.grey;
                              crown = const Icon(Icons.emoji_events, color: Colors.grey, size: 22);
                              break;
                            case 3:
                              color = Colors.brown;
                              crown = const Icon(Icons.emoji_events, color: Colors.brown, size: 22);
                              break;
                            default:
                              color = Colors.purple[100];
                              crown = null;
                          }
                          return Material(
                            color: Colors.transparent,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? Colors.deepPurple[100]?.withOpacity(.23)
                                    : color!.withOpacity(rank <= 3 ? 0.16 : 0.09),
                                borderRadius: BorderRadius.circular(18),
                                border: isCurrentUser
                                    ? Border.all(
                                        color: Colors.deepPurple, width: 2)
                                    : null,
                                boxShadow: [
                                  if (rank <= 3)
                                    BoxShadow(
                                      color: color!.withOpacity(.25),
                                      offset: const Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                                leading: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: color,
                                      child: Text(
                                        rank.toString(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 20),
                                      ),
                                    ),
                                    if (crown != null)
                                      Positioned(
                                          right: -8, top: -8, child: crown),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        user.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isCurrentUser
                                              ? Colors.deepPurple
                                              : Colors.black87,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                    if (isCurrentUser)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            "You",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: RichText(
                                  text: TextSpan(
                                    children: [
                                      const WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Icon(Icons.leaderboard, size: 20, color: Colors.deepPurple),
                                      ),
                                      TextSpan(
                                        text: '  ${user.score}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: Colors.deepPurple[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
