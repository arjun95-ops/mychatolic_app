import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/pages/create_radar_screen.dart';
import 'package:mychatolic_app/services/supabase_service.dart';

class RadarPage extends StatefulWidget {
  const RadarPage({super.key});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  // Streams
  late Stream<List<Map<String, dynamic>>> _publicStream;
  late Stream<List<Map<String, dynamic>>> _myStream;
  late Stream<List<Map<String, dynamic>>> _invitationsStream;

  // PREMIUM COLORS
  static const Color primaryBrand = Color(0xFF0088CC);
  static const Color bgSurface = Color(0xFFF5F5F5);
  
  // Friend Requests Stream
  late Stream<List<Map<String, dynamic>>> _friendReqStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); 
    _initStreams();
  }

  void _initStreams() {
    final user = _supabase.auth.currentUser;

    // 1. Radar Publik (Existing)
    _publicStream = _supabase
        .from('radars')
        .select('*, church:churches(*)')
        .eq('status', 'active')
        .eq('type', 'group') // Filter group only
        .order('created_at', ascending: false)
        .asStream();
    
    if (user != null) {
      // 2. Radar Saya (Existing)
      _myStream = _supabase
          .from('radars')
          .select('*, church:churches(*)')
          .eq('user_id', user.id)
          .neq('status', 'declined') 
          .order('schedule_time', ascending: true)
          .asStream();

      // 3. Undangan (Personal Invites - Mass)
      _invitationsStream = _supabase
          .from('radars')
          .select('*, church:churches(*), sender:profiles!user_id(*)') 
          .eq('type', 'personal')
          .eq('target_user_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .asStream();

      // 4. Friend Requests Stream (NEW)
      _friendReqStream = _supabase
          .from('friend_requests')
          .select('*, sender:profiles!sender_id(*)')
          .eq('receiver_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .asStream();

    } else {
      _myStream = const Stream.empty();
      _invitationsStream = const Stream.empty();
      _friendReqStream = const Stream.empty();
    }
  }

  Future<void> _respondToInvite(String radarId, String senderId, bool isAccepted) async {
    final SupabaseService service = SupabaseService();
    try {
      if (isAccepted) {
        // ACCEPT -> Link Chat
        await service.acceptPersonalRadar(radarId, senderId);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("Undangan diterima. Chat terhubung."), 
             backgroundColor: Color(0xFF2ECC71) // Success Green
           ));
        }
      } else {
        // DECLINE -> Status = declined
        await _supabase.from('radars').update({
          'status': 'declined'
        }).eq('id', radarId);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("Undangan ditolak."), 
             backgroundColor: Colors.grey
           ));
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memproses: $e"), backgroundColor: const Color(0xFFE74C3C))); // Error Red
      }
    }
  }
  
  Future<void> _respondToFriendRequest(String id, String senderId, bool accept) async {
    try {
      if (accept) {
        // 1. Update Status
        await _supabase.from('friend_requests').update({'status': 'accepted'}).eq('id', id);

        // 2. Create or Get Chat Room
        final myId = _supabase.auth.currentUser?.id;
        if (myId != null) {
           // A. Check Existing
           // Note: specific filter syntax for arrays varies. 
           // Using "cs" (contains) for array column 'participants'. 
           // We need to check if participants contains BOTH. Postgres @> operator.
           final existing = await _supabase.from('social_chats')
             .select()
             .contains('participants', [myId, senderId])
             .maybeSingle();

           if (existing != null) {
              // OPTIONAL: Bump chat
              await _supabase.from('social_chats').update({
                'last_message': "Kita sekarang berteman! 👋",
                'updated_at': DateTime.now().toIso8601String()
              }).eq('id', existing['id']);
           } else {
              // B. Create New
              await _supabase.from('social_chats').insert({
                'participants': [myId, senderId],
                'last_message': "Kita sekarang berteman! 👋",
                'created_by': myId,
                'updated_at': DateTime.now().toIso8601String()
              });
           }
        }

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permintaan pertemanan diterima!"), backgroundColor: Colors.green));
      } else {
        await _supabase.from('friend_requests').delete().eq('id', id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permintaan ditolak."), backgroundColor: Colors.grey));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: MyCatholicAppBar(
        title: "Radar Misa",
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 16),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Masuk"), // Renamed
            Tab(text: "Radar Publik"), 
            Tab(text: "Radar Saya")
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Incoming (Mixed: Friend Requests + Mass Invites)
          _buildIncomingTab(),
          // 2. Public Radar
          _buildRadarList(_publicStream, "Belum ada radar publik.", true),
          // 3. My Radar
          _buildRadarList(_myStream, "Kamu belum membuat radar.", false),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateRadarScreen()),
          );
          if (result == true) {
            setState(() => _initStreams());
          }
        },
        backgroundColor: primaryBrand,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildIncomingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SECTION 1: FRIEND REQUESTS
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _friendReqStream,
            builder: (context, snapshot) {
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) return const SizedBox.shrink(); // Hide if empty
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     child: Text("Permintaan Pertemanan", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                   ),
                   const SizedBox(height: 12),
                   SizedBox(
                     height: 140, // Horizontal List
                     child: ListView.separated(
                       padding: const EdgeInsets.symmetric(horizontal: 16),
                       scrollDirection: Axis.horizontal,
                       itemCount: requests.length,
                       separatorBuilder: (_,__) => const SizedBox(width: 12),
                       itemBuilder: (context, index) {
                         final req = requests[index];
                         final sender = req['sender'] ?? {};
                         return Container(
                           width: 250,
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(16),
                             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset:const Offset(0,2))]
                           ),
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Row(
                                 children: [
                                   CircleAvatar(backgroundImage: NetworkImage(sender['avatar_url'] ?? ''), radius: 18),
                                   const SizedBox(width: 10),
                                   Expanded(child: Text(sender['full_name'] ?? 'Teman', style: GoogleFonts.outfit(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))
                                 ],
                               ),
                               const Spacer(),
                               Row(
                                 children: [
                                   Expanded(child: OutlinedButton(onPressed: () => _respondToFriendRequest(req['id'].toString(), sender['id'].toString(), false), style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0,32)), child: const Text("Tolak"))),
                                   const SizedBox(width: 8),
                                   Expanded(child: ElevatedButton(onPressed: () => _respondToFriendRequest(req['id'].toString(), sender['id'].toString(), true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71), padding: EdgeInsets.zero, minimumSize: const Size(0,32)), child: const Text("Terima", style: TextStyle(color: Colors.white)))),
                                 ],
                               )
                             ],
                           ),
                         );
                       },
                     ),
                   ),
                   const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider()),
                ],
              );
            }
          ),

          // SECTION 2: MASS INVITATIONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text("Undangan Misa", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _invitationsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final radars = snapshot.data ?? [];
              if (radars.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(child: Text("Belum ada undangan misa masuk.", style: GoogleFonts.outfit(color: Colors.grey))),
                );
              }

              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: radars.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                   return _InvitationCard(
                     radarData: radars[index],
                     onAccept: () => _respondToInvite(radars[index]['id'].toString(), radars[index]['user_id'].toString(), true),
                     onDecline: () => _respondToInvite(radars[index]['id'].toString(), radars[index]['user_id'].toString(), false),
                   );
                },
              );
            },
          )
        ],
      ),
    );
  }
  
  // Reusing _buildRadarList only for Public & My Radar
  Widget _buildRadarList(Stream<List<Map<String, dynamic>>> stream, String emptyMsg, bool isPublic) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryBrand));
        }
        if (snapshot.hasError) {
          debugPrint("Stream Error: ${snapshot.error}");
          return _buildErrorState("Gagal memuat data.");
        }

        final radars = snapshot.data ?? [];
        if (radars.isEmpty) {
          return _buildEmptyState(emptyMsg);
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          itemCount: radars.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _RadarCard(radarData: radars[index], isPublic: isPublic);
          },
        );
      },
    );
  }


  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _initStreams()),
            icon: const Icon(Icons.refresh_rounded, color: primaryBrand),
            label: Text("Refresh", style: GoogleFonts.outfit(color: primaryBrand, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFE74C3C)),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.outfit(color: const Color(0xFFE74C3C))),
          TextButton(
             onPressed: () => setState(() => _initStreams()),
             child: const Text("Coba Lagi"),
          )
        ],
      ),
    );
  }
}

class _InvitationCard extends StatefulWidget {
  final Map<String, dynamic> radarData;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard({required this.radarData, required this.onAccept, required this.onDecline});

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _isLoading = false;

  Future<void> _handleAction(VoidCallback action) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate delay for effect
    action(); 
    // No need to set isLoading false because card will disappear from list
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.radarData;
    final sender = data['sender'] ?? {};
    final church = data['church'] ?? {};
    final scheduleStr = data['schedule_time'] as String?;
    final dateTime = scheduleStr != null ? DateTime.parse(scheduleStr) : DateTime.now();
    final dateFormatted = DateFormat("EEE, d MMM y • HH:mm", "id_ID").format(dateTime);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Sender Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: NetworkImage(sender['avatar_url'] ?? "https://via.placeholder.com/150"),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sender['full_name'] ?? "Teman", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                      Text("Mengundang Anda", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF0088CC).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text("Personal Invite", style: GoogleFonts.outfit(color: const Color(0xFF0088CC), fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          
          Divider(height: 1, color: Colors.grey.shade100),

          // 2. Body: Event Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mengajak Anda Misa di", style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                   church['name'] ?? data['location_name'] ?? "Lokasi tidak diketahui",
                   style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                     Container(
                       padding: const EdgeInsets.all(6),
                       decoration: BoxDecoration(color: const Color(0xFF0088CC).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                       child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF0088CC), size: 16),
                     ),
                     const SizedBox(width: 10),
                     Text(dateFormatted, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
                  ],
                ),
                
                if (data['description'] != null && data['description'].isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      "\"${data['description']}\"", 
                      style: GoogleFonts.outfit(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 14)
                    ),
                  )
                ],
              ],
            ),
          ),

          // 3. Footer: Actions
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: Color(0xFF0088CC))))
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => _handleAction(widget.onDecline),
                        style: OutlinedButton.styleFrom(
                           foregroundColor: const Color(0xFFE74C3C),
                           side: const BorderSide(color: Color(0xFFE74C3C)),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        child: Text("Tolak", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _handleAction(widget.onAccept),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF2ECC71), // Success Green
                           foregroundColor: Colors.white,
                           elevation: 0,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        child: Text("Terima", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PREMIUM RADAR CARD (Clean White)
// ---------------------------------------------------------------------------
class _RadarCard extends StatelessWidget {
  final Map<String, dynamic> radarData;
  final bool isPublic;

  const _RadarCard({required this.radarData, this.isPublic = true});

  @override
  Widget build(BuildContext context) {
    // Colors
    const primaryColor = Color(0xFF0088CC);

    final church = radarData['church'] as Map<String, dynamic>? ?? {};
    final String title = radarData['title'] ?? 'Misa Bersama';
    final String churchName = church['name'] ?? radarData['location_name'] ?? 'Gereja tidak diketahui';
    final String scheduleRaw = radarData['schedule_time'] ?? DateTime.now().toIso8601String();
    
    final DateTime scheduleTime = DateTime.parse(scheduleRaw);
    final String formattedSchedule = DateFormat("EEEE, d MMM y • HH:mm", "id_ID").format(scheduleTime);
    final String? chatGroupId = radarData['chat_group_id'];
    
    // Check if personal active (accepted)
    final bool isPersonal = radarData['type'] == 'personal';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (chatGroupId != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SocialChatDetailPage(
                chatId: chatGroupId,
                opponentProfile: {
                  'full_name': title,
                  'avatar_url': "https://images.unsplash.com/photo-1548625361-ad8f51ec0429?q=80&w=200", 
                  'is_group': true,
                },
              )));
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(isPersonal ? Icons.person_rounded : Icons.church_rounded, color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(churchName, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16), 
                  child: Divider(height: 1, color: Colors.grey.shade100)
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(formattedSchedule, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87))),
                  ],
                ),
                if (chatGroupId != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => SocialChatDetailPage(
                           chatId: chatGroupId,
                           opponentProfile: {
                             'full_name': title,
                             'avatar_url': "https://images.unsplash.com/photo-1548625361-ad8f51ec0429?q=80&w=200",
                             'is_group': true,
                           },
                         )));
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryColor), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: Text("Buka Chat Radar", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: primaryColor)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
