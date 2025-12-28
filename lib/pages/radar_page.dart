import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/pages/create_radar_screen.dart';
import 'package:mychatolic_app/services/radar_service.dart';

class RadarPage extends StatefulWidget {
  const RadarPage({super.key});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> with SingleTickerProviderStateMixin {
  final RadarService _radarService = RadarService();
  late TabController _tabController;
  
  // Future States
  Future<List<Map<String, dynamic>>>? _invitesFuture;
  Future<List<Map<String, dynamic>>>? _publicRadarsFuture;
  Future<List<Map<String, dynamic>>>? _myRadarsFuture;

  // PREMIUM COLORS
  static const Color primaryBrand = Color(0xFF0088CC);
  static const Color bgSurface = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); 
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _invitesFuture = _radarService.fetchRadarInvites();
      _publicRadarsFuture = _radarService.fetchPublicRadars();
      _myRadarsFuture = _radarService.fetchMyRadars();
    });
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
          isScrollable: false, // Fixed tabs for better width distribution
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 16),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Undangan"), 
            Tab(text: "Radar Publik"), 
            Tab(text: "Radar Saya")
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Undangan (Invites)
          _buildInvitesTab(),
          // 2. Radar Publik
          _buildRadarList(
            future: _publicRadarsFuture, 
            emptyMsg: "Belum ada aktivitas radar dari teman/paroki Anda.",
            isPublic: true,
          ),
          // 3. Radar Saya
          _buildRadarList(
            future: _myRadarsFuture, 
            emptyMsg: "Anda belum membuat radar. Tekan + untuk buat baru.",
            isPublic: false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateRadarScreen()),
          );
          if (result == true) {
            _refreshData();
          }
        },
        backgroundColor: primaryBrand,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildInvitesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _invitesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryBrand));
        }
        if (snapshot.hasError) {
          return _buildErrorState("Gagal memuat undangan: ${snapshot.error}");
        }

        final invites = snapshot.data ?? [];
        if (invites.isEmpty) {
          return _buildEmptyState("Belum ada undangan misa.");
        }

        return RefreshIndicator(
          onRefresh: () async => _refreshData(),
          color: primaryBrand,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _InvitationCard(
                radarData: invites[index],
                onRefresh: _refreshData,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRadarList({
    required Future<List<Map<String, dynamic>>>? future,
    required String emptyMsg,
    required bool isPublic,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryBrand));
        }
        if (snapshot.hasError) {
          return _buildErrorState("Gagal memuat data.");
        }

        final radars = snapshot.data ?? [];
        if (radars.isEmpty) {
          return _buildEmptyState(emptyMsg);
        }

        return RefreshIndicator(
          onRefresh: () async => _refreshData(),
          color: primaryBrand,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemCount: radars.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _RadarCard(radarData: radars[index], isPublic: isPublic);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radar_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, color: primaryBrand),
              label: Text("Refresh", style: GoogleFonts.outfit(color: primaryBrand, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFE74C3C)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: const Color(0xFFE74C3C))),
            TextButton(
              onPressed: _refreshData,
              child: const Text("Coba Lagi"),
            )
          ],
        ),
      ),
    );
  }
}

class _InvitationCard extends StatefulWidget {
  final Map<String, dynamic> radarData;
  final VoidCallback onRefresh;

  const _InvitationCard({required this.radarData, required this.onRefresh});

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _isLoading = false;
  final RadarService _radarService = RadarService();

  Future<void> _respond(bool accept) async {
    setState(() => _isLoading = true);
    
    try {
      final radarId = widget.radarData['id'].toString();
      // Use 'profiles' key for sender info
      final profiles = widget.radarData['profiles'] as Map<String, dynamic>? ?? {};
      final senderId = widget.radarData['user_id'].toString();

      if (accept) {
        await _radarService.acceptPersonalRadar(radarId, senderId);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("Undangan diterima. Chat terhubung."), 
             backgroundColor: Color(0xFF2ECC71)
           ));
        }
      } else {
        // Decline: Update status to 'declined'
        // Using direct supabase client for now as Service doesn't have decline method exposed yet
        final supabase = Supabase.instance.client;
        await supabase.from('radars').update({
          'status': 'declined'
        }).eq('id', radarId);

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("Undangan ditolak."), 
             backgroundColor: Colors.grey
           ));
        }
      }

      widget.onRefresh();

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memproses: $e"), backgroundColor: const Color(0xFFE74C3C)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.radarData;
    // Map properties based on SupabaseService fetchRadarInvites
    final sender = data['profiles'] as Map<String, dynamic>? ?? {};
    final church = data['churches'] as Map<String, dynamic>? ?? {};
    
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
                ClipOval(
                  child: SafeNetworkImage(
                    imageUrl: sender['avatar_url'] ?? '',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
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
                
                if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
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
                        onPressed: () => _respond(false),
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
                        onPressed: () => _respond(true),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF2ECC71),
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

class _RadarCard extends StatelessWidget {
  final Map<String, dynamic> radarData;
  final bool isPublic;

  const _RadarCard({required this.radarData, this.isPublic = true});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0088CC);

    final church = radarData['churches'] as Map<String, dynamic>? ?? {};
    final String title = radarData['title'] ?? 'Misa Bersama';
    final String churchName = church['name'] ?? radarData['location_name'] ?? 'Gereja tidak diketahui';
    final String scheduleRaw = radarData['schedule_time'] ?? DateTime.now().toIso8601String();
    
    final DateTime scheduleTime = DateTime.parse(scheduleRaw);
    final String formattedSchedule = DateFormat("EEEE, d MMM y • HH:mm", "id_ID").format(scheduleTime);
    final String? chatGroupId = radarData['chat_group_id'];
    
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
