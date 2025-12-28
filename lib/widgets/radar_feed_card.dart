import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mychatolic_app/widgets/safe_network_image.dart';
// import 'package:mychatolic_app/core/theme.dart'; // Using hardcoded colors for now to ensure consistency with the request

class RadarFeedCard extends StatelessWidget {
  final Map<String, dynamic> radarData;
  final VoidCallback? onTap;

  const RadarFeedCard({super.key, required this.radarData, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Determine creator data safely
    final creator = radarData['profiles'] ?? {};
    // Extract church name safely
    final churchName = radarData['location_name'] ?? radarData['churches']?['name'] ?? 'Gereja';
    
    // Parse times safely
    DateTime? scheduleTime;
    if (radarData['schedule_time'] != null) {
      scheduleTime = DateTime.tryParse(radarData['schedule_time']);
    }
    
    DateTime? createdAt;
    if (radarData['created_at'] != null) {
      createdAt = DateTime.tryParse(radarData['created_at']);
    }

    final notes = radarData['description'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Jarak antar post similar to social feeds
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (User info)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ClipOval(
              child: SafeNetworkImage(
                imageUrl: creator['avatar_url'] ?? '', 
                width: 40, height: 40, 
                fit: BoxFit.cover,
                // Using default fallback behavior of SafeNetworkImage
              ),
            ),
            title: RichText(
              text: TextSpan(
                style: GoogleFonts.outfit(color: Colors.black, fontSize: 14),
                children: [
                  TextSpan(
                    text: creator['full_name'] ?? 'Umat', 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  const TextSpan(text: " membuat rencana misa."),
                ],
              ),
            ),
            subtitle: createdAt != null 
                ? Text(timeago.format(createdAt), style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12))
                : null,
            trailing: const Icon(Icons.radar, color: Color(0xFF0088CC)),
          ),

          // 2. Konten Utama
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF), // Biru sangat muda
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0088CC).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white, 
                            shape: BoxShape.circle, 
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
                          ),
                          child: const Icon(Icons.church, color: Color(0xFF0088CC), size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                churchName, 
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)
                              ),
                              const SizedBox(height: 4),
                              if (scheduleTime != null)
                                Text(
                                  DateFormat("EEEE, d MMM • HH:mm").format(scheduleTime),
                                  style: GoogleFonts.outfit(color: const Color(0xFF0088CC), fontWeight: FontWeight.w600),
                                ),
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

          // 3. Footer Actions
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    label: const Text("Lihat Detail"),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                  ),
                ),
                // Bisa tambah tombol 'Join' disini nanti
              ],
            ),
          ),
          const Divider(thickness: 1, height: 1),
        ],
      ),
    );
  }
}
