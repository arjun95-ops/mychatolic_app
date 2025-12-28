import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:share_plus/share_plus.dart'; // Pastikan package share_plus terinstall

class RadarFeedCard extends StatelessWidget {
  final Map<String, dynamic> radarData;
  final VoidCallback? onTap;

  const RadarFeedCard({super.key, required this.radarData, this.onTap});

  @override
  Widget build(BuildContext context) {
    final creator = radarData['profiles'] ?? {};
    final churchName = radarData['location_name'] ?? radarData['churches']?['name'] ?? 'Gereja';
    final scheduleTime = DateTime.parse(radarData['schedule_time']);
    final createdAt = DateTime.parse(radarData['created_at']);
    final notes = radarData['description'];

    // Format tanggal
    final dateStr = DateFormat("EEEE, d MMM • HH:mm").format(scheduleTime);

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8), // Separator antar post
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER (User Info)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ClipOval(
              child: SafeNetworkImage(
                imageUrl: creator['avatar_url'] ?? '',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            title: RichText(
              text: TextSpan(
                style: GoogleFonts.outfit(color: Colors.black, fontSize: 14),
                children: [
                  TextSpan(text: creator['full_name'] ?? 'Umat', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: " · Radar Misa", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            subtitle: Text(timeago.format(createdAt), style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.grey),
              onPressed: () {
                // Fitur Share
                final text = "Yuk Misa bareng di $churchName!\n🗓 $dateStr\n\nGabung via MyCatholic App.";
                Share.share(text);
              },
            ),
          ),

          // 2. BODY (Konten Radar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notes != null && notes.toString().isNotEmpty) ...[
                  Text(notes, style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 12),
                ],

                // Highlight Box Gereja
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF), // Biru muda soft
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0088CC).withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        // Gambar/Icon Gereja Besar
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: const Center(
                            child: Icon(Icons.church_rounded, size: 48, color: Color(0xFF0088CC)),
                          ),
                        ),
                        // Info Detail
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(churchName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.event, size: 14, color: Color(0xFF0088CC)),
                                        const SizedBox(width: 6),
                                        Text(dateStr, style: GoogleFonts.outfit(color: const Color(0xFF0088CC), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. FOOTER (Action Button)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text("Lihat Detail & Gabung", style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const Divider(thickness: 1, height: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }
}
