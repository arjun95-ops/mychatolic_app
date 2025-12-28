import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/create_radar_screen.dart'; // Pastikan ada
// import 'package:mychatolic_app/pages/schedule_page.dart'; // Opsional jika mau link ke jadwal

class RadarPage extends StatefulWidget {
  const RadarPage({super.key});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RadarService _radarService = RadarService();
  final String _myUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("Radar Misa", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kPrimary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Agenda Saya"),
            Tab(text: "Eksplor"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyAgendaTab(),
          _buildPublicRadarTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           // Opsi: Tampilkan modal untuk memilih buat Radar Manual atau dari Jadwal
           Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRadarScreen()));
        },
        backgroundColor: kPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- TAB 1: AGENDA SAYA ---
  Widget _buildMyAgendaTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _radarService.fetchMyRadars(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("Belum ada rencana misa.", style: GoogleFonts.outfit(color: Colors.grey)),
              ],
            ),
          );
        }

        final agendas = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: agendas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _buildAgendaCard(agendas[index]);
          },
        );
      },
    );
  }

  Widget _buildAgendaCard(Map<String, dynamic> item) {
    final churchName = item['location_name'] ?? item['churches']?['name'] ?? 'Gereja';
    final time = DateTime.parse(item['schedule_time']);
    final isCreator = item['user_id'] == _myUserId;
    final status = item['status'];

    // Cari info partner (lawan bicara)
    // Ingat logika: participants array mungkin tidak di-join, tapi kita punya 'profiles' via user_id (creator).
    // Untuk Personal Radar, kita perlu tahu siapa temannya.
    // Logic sederhana: Jika saya creator, tampilkan 'Invited Friend'. Jika saya invited, tampilkan 'Creator'.
    // Karena keterbatasan fetch join kompleks, kita gunakan display dasar dulu.
    
    // Warna Status
    Color statusColor = Colors.green;
    String statusText = "Terjadwal";
    if (status == 'pending') {
      statusColor = Colors.orange;
      statusText = "Menunggu Respon";
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header Tanggal & Jam
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: kPrimary),
                    const SizedBox(width: 8),
                    Text(DateFormat("EEEE, d MMMM yyyy").format(time), style: GoogleFonts.outfit(color: kPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Jam Besar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: Text(DateFormat("HH:mm").format(time), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                ),
                const SizedBox(width: 16),
                // Detail
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(churchName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(item['description'] ?? "Misa Bersama", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: PUBLIC RADAR ---
  Widget _buildPublicRadarTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _radarService.fetchPublicRadars(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final radars = snapshot.data ?? [];
        if (radars.isEmpty) {
          return Center(child: Text("Belum ada radar di sekitarmu.", style: GoogleFonts.outfit(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: radars.length,
          itemBuilder: (context, index) {
            final item = radars[index];
            final creator = item['profiles'] ?? {};
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipOval(
                  child: SafeNetworkImage(imageUrl: creator['avatar_url'] ?? '', width: 50, height: 50, fit: BoxFit.cover),
                ),
                title: Text(creator['full_name'] ?? 'User', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Misa di ${item['churches']?['name'] ?? 'Gereja'}", style: GoogleFonts.outfit(color: Colors.black87)),
                    Text(DateFormat("d MMM HH:mm").format(DateTime.parse(item['schedule_time'])), style: GoogleFonts.outfit(color: kPrimary, fontSize: 12)),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () {}, // Implementasi Join jika perlu
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimary, shape: const CircleBorder(), padding: const EdgeInsets.all(12)),
                  child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
