import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:mychatolic_app/models/story_model.dart';
import 'package:mychatolic_app/services/story_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/pages/story/create_story_page.dart';
import 'package:mychatolic_app/pages/story/story_view_page.dart';

import 'package:mychatolic_app/core/app_colors.dart'; 
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';
import 'package:mychatolic_app/features/social/search_user_page.dart'; 

class SocialInboxPage extends StatefulWidget {
  const SocialInboxPage({super.key});

  @override
  State<SocialInboxPage> createState() => _SocialInboxPageState();
}

class _SocialInboxPageState extends State<SocialInboxPage> {
  final _supabase = Supabase.instance.client;
  final StoryService _storyService = StoryService();

  // State untuk Stories
  List<UserStoryGroup> _activeStories = [];
  UserStoryGroup? _currentUserStory;
  bool _isLoadingStories = true;

  // State untuk Chat & Cache Profile
  Map<String, Map<String, dynamic>> _profileCache = {};
  bool _isFetchingProfiles = false;

  @override
  void initState() {
    super.initState();
    _fetchStories();
  }

  // --- STORY LOGIC ---

  Future<void> _fetchStories() async {
    if (!mounted) return;
    
    // 1. Fetch all active stories grouped by user
    final allStories = await _storyService.fetchActiveStories();
    final myId = _supabase.auth.currentUser?.id;

    List<UserStoryGroup> friendsStories = [];
    UserStoryGroup? myStory;

    // 2. Separate "My Story" from "Friend Stories"
    for (var group in allStories) {
      if (group.userId == myId) {
        myStory = group;
      } else {
        friendsStories.add(group);
      }
    }

    if (mounted) {
      setState(() {
        _activeStories = friendsStories;
        _currentUserStory = myStory;
        _isLoadingStories = false;
      });
    }
  }

  void _onReturn() {
    _fetchStories();
  }

  // --- CHAT & CACHE LOGIC ---

  Future<void> _cacheProfiles(List<String> ids) async {
    // Filter ID yang belum ada di cache dan belum null
    final idsToFetch = ids.where((id) => !_profileCache.containsKey(id)).toSet().toList();
    
    if (idsToFetch.isEmpty) return;

    try {
      // Menggunakan .filter('id', 'in', ids) sebagai pengganti .in_()
      final List<dynamic> data = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .filter('id', 'in', idsToFetch);

      if (mounted) {
        setState(() {
          for (var item in data) {
            _profileCache[item['id']] = item as Map<String, dynamic>;
          }
        });
      }
    } catch (e) {
      debugPrint("Error caching profiles: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: MyCatholicAppBar(
        title: "Pesan",
        actions: [
          IconButton(
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchUserPage())); 
            }, 
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. STORY HEADER
          _buildStoryHeader(),
          
          Container(height: 1, color: Colors.grey.shade100),

          // 2. CHAT BODY (List)
          Expanded(child: _buildChatList()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI: STORY HEADER
  // ---------------------------------------------------------------------------
  Widget _buildStoryHeader() {
    return Container(
      height: 130.0,
      width: double.infinity,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: 1 + _activeStories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildMyStoryItem();
          }
          final friendStory = _activeStories[index - 1];
          return _buildFriendStoryItem(friendStory);
        },
      ),
    );
  }

  Widget _buildMyStoryItem() {
    final user = _supabase.auth.currentUser;
    final hasStory = _currentUserStory != null && _currentUserStory!.stories.isNotEmpty;

    // Jika user belum login, return placeholder
    if (user == null) return const SizedBox.shrink();

    // Cek cache untuk avatar saya sendiri jika belum ada di story
    final myProfile = _profileCache[user.id];
    String? avatarUrl = hasStory ? _currentUserStory!.userAvatar : myProfile?['avatar_url'];

    // Jika belum ada di cache, fetch (optional lazy load)
    if (!hasStory && myProfile == null) {
       _cacheProfiles([user.id]);
    }

    return GestureDetector(
      onTap: () {
        if (hasStory) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewPage(
            stories: _currentUserStory!.stories,
            userProfile: {
              'full_name': 'Saya', 
              'avatar_url': avatarUrl
            },
          ))).then((_) => _onReturn());
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStoryPage()))
              .then((result) { if (result == true) _onReturn(); });
        }
      },
      child: Container(
        width: 80.0,
        color: Colors.transparent,
        child: Column(
          children: [
            SizedBox(
              width: 70, height: 70,
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasStory 
                          ? const LinearGradient(colors: [Colors.purple, Colors.orange])
                          : null,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: SafeNetworkImage(
                        imageUrl: avatarUrl,
                        width: 60, height: 60,
                        borderRadius: BorderRadius.circular(100),
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.person,
                      ),
                    ),
                  ),
                  if (!hasStory)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2.5)),
                        ),
                        child: const Icon(Icons.add, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text("Cerita Anda", style: GoogleFonts.outfit(fontSize: 12.0), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendStoryItem(UserStoryGroup group) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewPage(
           stories: group.stories,
           userProfile: {'full_name': group.userName, 'avatar_url': group.userAvatar},
        ))).then((_) => _onReturn());
      },
      child: Container(
        width: 80.0,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.purple, Colors.orange, Colors.greenAccent]),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: SafeNetworkImage(
                  imageUrl: group.userAvatar,
                  width: 60, height: 60,
                  borderRadius: BorderRadius.circular(100),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(group.userName.split(' ').first, style: GoogleFonts.outfit(fontSize: 12.0), maxLines: 1),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI: CHAT LIST (OPTIMIZED)
  // ---------------------------------------------------------------------------
  Widget _buildChatList() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return const Center(child: Text("Silakan login kembali."));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('social_chats')
          .stream(primaryKey: ['id'])
          .order('updated_at', ascending: false)
          .map((list) {
            return list.where((chat) {
              final participants = List<dynamic>.from(chat['participants'] ?? []);
              final createdBy = chat['created_by'];
              return participants.contains(myId) || createdBy == myId;
            }).toList();
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final chats = snapshot.data ?? [];
        if (chats.isEmpty) {
          return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                 const SizedBox(height: 16),
                 Text("Belum ada percakapan", style: GoogleFonts.outfit(color: Colors.grey)),
               ],
             )
          );
        }

        // --- COLLECT MISSING PROFILES ---
        List<String> missingIds = [];
        for (var chat in chats) {
          final participants = List<dynamic>.from(chat['participants'] ?? []);
          final opponentId = participants.firstWhere((id) => id != myId, orElse: () => null);
          if (opponentId != null && !_profileCache.containsKey(opponentId)) {
            missingIds.add(opponentId.toString());
          }
        }
        
        // Trigger batch fetch jika ada yang hilang
        if (missingIds.isNotEmpty) {
           // Gunakan Future.microtask agar tidak error setState saat build
           Future.microtask(() => _cacheProfiles(missingIds));
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return _buildChatItem(chat, myId);
          },
        );
      },
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, String myId) {
    final participants = List<dynamic>.from(chat['participants'] ?? []);
    final opponentId = participants.firstWhere((id) => id != myId, orElse: () => null);

    if (opponentId == null) return const SizedBox.shrink();

    // BACA DARI CACHE (Synchronous)
    final profile = _profileCache[opponentId];
    
    // Tampilan Loading Sementara (Shimmer-like) jika data belum siap
    if (profile == null) {
      return ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.grey),
        title: Container(width: 100, height: 16, color: Colors.grey[200]),
        subtitle: Container(width: 200, height: 12, color: Colors.grey[100]),
      );
    }

    final name = profile['full_name'] ?? "User";
    final avatarUrl = profile['avatar_url'];
    final lastMsg = chat['last_message'] ?? "Memulai percakapan";
    final updatedAt = chat['updated_at'];
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: SafeNetworkImage(
        imageUrl: avatarUrl,
        width: 50, height: 50,
        borderRadius: BorderRadius.circular(25),
        fit: BoxFit.cover,
        fallbackIcon: Icons.person,
      ),
      title: Text(
        name, 
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        lastMsg,
        style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
         updatedAt != null ? timeago.format(DateTime.parse(updatedAt), locale: 'en_short') : "",
         style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
      ),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SocialChatDetailPage(
          chatId: chat['id'],
          opponentProfile: {
            'id': opponentId,
            'full_name': name,
            'avatar_url': avatarUrl,
          },
        )));
      },
    );
  }
}
