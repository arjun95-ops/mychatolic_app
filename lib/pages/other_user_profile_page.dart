import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/chat_detail_page.dart';
import 'package:mychatolic_app/pages/radars/create_invite_page.dart';
import 'package:mychatolic_app/services/chat_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class OtherUserProfilePage extends StatefulWidget {
  final String userId;

  const OtherUserProfilePage({super.key, required this.userId});

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  final _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  
  // Data
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileAndFollowStatus();
  }

  Future<void> _fetchProfileAndFollowStatus() async {
    final myId = _supabase.auth.currentUser?.id;
    try {
      // 1. Fetch Profile
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();

      // 2. Check Follow Status
      bool following = false;
      if (myId != null) {
        final followCheck = await _supabase
            .from('user_follows')
            .select() // count is easier, but select maybeSingle works
            .eq('follower_id', myId)
            .eq('following_id', widget.userId)
            .maybeSingle();
        following = followCheck != null;
      }

      if (mounted) {
        setState(() {
          _profileData = profile;
          _isFollowing = following;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memuat profil: $e")));
      }
    }
  }

  Future<void> _toggleFollow() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        // Unfollow
        await _supabase
            .from('user_follows')
            .delete()
            .eq('follower_id', myId)
            .eq('following_id', widget.userId);
        setState(() => _isFollowing = false);
      } else {
        // Follow
        await _supabase.from('user_follows').insert({
          'follower_id': myId,
          'following_id': widget.userId,
        });
        setState(() => _isFollowing = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal follow/unfollow: $e")));
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _startChat() async {
    setState(() => _isChatLoading = true);
    try {
      final chatId = await _chatService.getOrCreatePrivateChat(widget.userId);
      if (mounted) {
        final name = _profileData?['full_name'] ?? _profileData?['name'] ?? 'Teman';
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => ChatDetailPage(chatId: chatId, name: name))
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  void _ajakMisa() {
     final name = _profileData?['full_name'] ?? _profileData?['name'] ?? 'Teman';
     // Navigate to create invite with target user pre-filled
     Navigator.push(
       context, 
       MaterialPageRoute(builder: (_) => CreateInvitePage(
         targetUserId: widget.userId,
         targetUserName: name,
       ))
     );
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color bgDarkPurple = Color(0xFF1E1235);
    const Color cardPurple = Color(0xFF352453);
    const Color accentOrange = Color(0xFFFF9F1C);
    
    // Loading
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgDarkPurple,
        body: Center(child: CircularProgressIndicator(color: accentOrange)),
      );
    }

    if (_profileData == null) {
      return const Scaffold(
        backgroundColor: bgDarkPurple,
        body: Center(child: Text("Pengguna tidak ditemukan", style: TextStyle(color: Colors.white))),
      );
    }

    final data = _profileData!;
    final String name = data['full_name'] ?? data['name'] ?? 'Umat';
    final String role = (data['role'] ?? 'umat').toString().toLowerCase(); // Normalize
    final String parish = data['parish'] ?? 'Paroki Tidak Diketahui';
    final String? avatar = data['avatar_url'];

    // Logic: Ajak Misa visible ONLY if Umat/Katekumen
    final bool canInviteToMass = (role == 'umat' || role == 'katekumen');

    // Logic: Role Badge visible if NOT Umat
    final bool showRoleBadge = role != 'umat';

    return Scaffold(
      backgroundColor: bgDarkPurple,
      appBar: AppBar(
        title: Text("Profil $name", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- INFO CARD ---
            Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardPurple,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                ]
              ),
              child: Column(
              children: [
                  // AVATAR
                  Container(
                    padding: const EdgeInsets.all(4),
                     decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Colors.grey, Colors.white24]),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: bgDarkPurple,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: SafeNetworkImage(
                          imageUrl: avatar,
                          width: 100, 
                          height: 100,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.person,
                          iconColor: Colors.white,
                          fallbackColor: bgDarkPurple,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // NAME
                  Text(
                    name, 
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center
                  ),
                  const SizedBox(height: 8),
                  
                  // ROLE BADGE (If applicable)
                  if (showRoleBadge)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentOrange, 
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Text(
                        role.toUpperCase(), 
                        style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)
                      ),
                    ),

                  // PARISH LABEL
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: Text(parish, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 32),

                  // --- ACTIONS ---
                  
                  // 1. FOLLOW BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isFollowLoading ? null : _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.transparent : Colors.white,
                        foregroundColor: _isFollowing ? Colors.white : Colors.black,
                        side: _isFollowing ? const BorderSide(color: Colors.white) : null,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isFollowLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : Text(_isFollowing ? "BERHENTI MENGIKUTI" : "IKUTI", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. CHAT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isChatLoading ? null : _startChat,
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: Text("KIRIM PESAN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardPurple, // Darker
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                  // 3. AJAK MISA BUTTON (Conditional)
                  if (canInviteToMass) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _ajakMisa,
                        icon: const Icon(Icons.church, color: Colors.black),
                        label: Text("AJAK MISA", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentOrange,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ]

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
