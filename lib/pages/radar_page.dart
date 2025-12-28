import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/create_radar_screen.dart'; 
import 'package:mychatolic_app/pages/schedule_page.dart';

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

  // Helper delete
  void _handleDelete(String radarId, bool isCreator) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCreator ? "Hapus Rencana?" : "Tolak Undangan?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(isCreator 
            ? "Radar ini akan dihapus permanen." 
            : "Anda akan menolak ajakan misa ini."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _radarService.deleteOrDeclineRadar(radarId);
                setState(() {}); // Refresh UI
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            }, 
            child: Text(isCreator ? "Hapus" : "Tolak", style: const TextStyle(color: Colors.red))
          ),
        ],
      )
    );
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
           // Direct ke Schedule Page untuk flow yang benar
           Navigator.push(context, MaterialPageRoute(builder: (_) => const SchedulePage()));
        },
        backgroundColor: kPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMyAgendaTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _radarService.fetchMyRadars(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        // Filter yang declined tidak usah ditampilkan
        final agendas = (snapshot.data ?? []).where((e) => e['status'] != 'declined').toList();

        if (agendas.isEmpty) {
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

    // Logika Tampilan Status
    Color statusColor;
    String statusText;
    Color cardBgColor = Colors.white;

    if (status == 'active') {
      statusColor = Colors.green;
      statusText = "Terjadwal";
    } else { // pending
      if (isCreator) {
        statusColor = Colors.orange;
        statusText = "Menunggu Respon";
      } else {
        statusColor = Colors.deepOrange;
        statusText = "Undangan Masuk";
        cardBgColor = Colors.orange.withOpacity(0.05); // Highlight undangan masuk
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 48, 12), // Padding kanan extra untuk tombol hapus
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: statusColor),
                    const SizedBox(width: 8),
                    Text(DateFormat("EEEE, d MMM yyyy").format(time), style: GoogleFonts.outfit(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Text(statusText, style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.white),
                      child: Text(DateFormat("HH:mm").format(time), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(churchName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(item['description'] ?? "Misa Bersama", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Tombol Hapus / Tolak (Pojok Kanan Atas)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
              onPressed: () => _handleDelete(item['id'], isCreator),
              tooltip: isCreator ? "Hapus" : "Tolak",
            ),
          )
        ],
      ),
    );
  }

  // --- TAB 2: PUBLIC (Biarkan code lama, hanya refresh UI) ---
  Widget _buildPublicRadarTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _radarService.fetchPublicRadars(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final radars = snapshot.data ?? [];
        if (radars.isEmpty) return Center(child: Text("Belum ada radar di sekitarmu.", style: GoogleFonts.outfit(color: Colors.grey)));

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
                leading: ClipOval(child: SafeNetworkImage(imageUrl: creator['avatar_url'] ?? '', width: 50, height: 50, fit: BoxFit.cover)),
                title: Text(creator['full_name'] ?? 'User', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                subtitle: Text("Misa di ${item['churches']?['name'] ?? 'Gereja'}\n${DateFormat("d MMM HH:mm").format(DateTime.parse(item['schedule_time']))}", style: GoogleFonts.outfit(fontSize: 12)),
              ),
            );
          },
        );
      },
    );
  }
}
