import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/models/mass_invitation.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final RadarService _radarService = RadarService();
  bool _isLoadingAction = false;
  List<Map<String, dynamic>> _invites = []; // Using generic map for now, until we fully migrate to MassInvitation model usage

  @override
  void initState() {
    super.initState();
    _fetchInvites();
  }

  Future<void> _fetchInvites() async {
    final invites = await _radarService.fetchRadarInvites();
    if(mounted) {
      setState(() {
        _invites = invites;
      });
    }
  }

  Future<void> _handleResponse(String inviteId, bool accepted, String senderId) async {
    setState(() => _isLoadingAction = true);
    // TODO: implement logic to handle accept/reject using _radarService
    // For now, removing from list locally
     if (accepted) {
        try {
          await _radarService.acceptPersonalRadar(inviteId, senderId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Undangan diterima! Chat dibuka."), backgroundColor: Colors.green));
          }
        } catch (e) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
     } else {
        // Handle decline if needed in service
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Undangan ditolak"), backgroundColor: Colors.grey));
     }

    if (mounted) {
        setState(() {
          _invites.removeWhere((element) => element['id'] == inviteId);
           _isLoadingAction = false;
        });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text("Notifikasi", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInvites,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION: UNDANGAN MISA
              Text("Undangan Misa", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              if (_invites.isEmpty) 
                 Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Text("Belum ada undangan misa baru.", style: GoogleFonts.outfit(color: Colors.grey)),
                  )
              else
                 ListView.separated(
                    shrinkWrap: true, // Vital for nesting in SingleChildScrollView
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _invites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildInvitationCard(_invites[index]),
                  ),

              const SizedBox(height: 32),

              // SECTION: NOTIFIKASI LAINNYA (Dummy untuk saat ini)
              Text("Lainnya", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildGeneralNotificationItem("Admin", "Selamat datang di MyCatholic App!"),
              _buildGeneralNotificationItem("System", "Lengkapi profil Anda untuk pengalaman lebih baik."),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invite) {
    final senderProfile = invite['profiles'] ?? {};
    final churchName = invite['location_name'] ?? 'Gereja';
    final scheduleTimeStr = invite['schedule_time'];
    DateTime? scheduleTime;
    if (scheduleTimeStr != null) {
       scheduleTime = DateTime.tryParse(scheduleTimeStr);
    }
    final message = invite['description'];
    final senderId = invite['user_id'];


    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: SafeNetworkImage(
                  imageUrl: senderProfile['avatar_url'] ?? '',
                  width: 50, height: 50,
                  fit: BoxFit.cover,
                  // Removed fallbackWidget as requested, rely on widget default
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(color: Colors.black, fontSize: 14),
                        children: [
                          TextSpan(text: senderProfile['full_name'] ?? 'Seseorang', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: " mengajak misa di "),
                          TextSpan(text: churchName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0088CC))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (scheduleTime != null)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('EEEE, d MMM HH:mm', 'id_ID').format(scheduleTime),
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (message != null && message.toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: Text('"$message"', style: GoogleFonts.outfit(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[700])),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoadingAction ? null : () => _handleResponse(invite['id'], false, senderId),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text("Tolak", style: GoogleFonts.outfit(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoadingAction ? null : () => _handleResponse(invite['id'], true, senderId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088CC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text("Terima", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGeneralNotificationItem(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(body, style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
