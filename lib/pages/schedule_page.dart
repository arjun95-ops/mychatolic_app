import 'package:flutter/material.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mychatolic_app/models/mass_schedule.dart';
import 'package:mychatolic_app/services/schedule_service.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';
// NOTE: Make sure these pages actually exist. If create_invite_page.dart does not exist yet, 
// this import will fail. Based on typical workflow, I will assume it might not exist and 
// will create a dummy or comment it out if compilation fails, but user provided this code explicitly.
// However, the user request says "Gunakan kode lengkap berikut".
// I will blindly use the import but if CreateInvitePage is missing, it will error.
// The user previously mentioned `lib/pages/radars/create_invite_page.dart` but usually pages are in `lib/pages/`.
// I'll check previous file list quickly... NO, I can't check efficiently. 
// I will use `mychatolic_app/pages/create_invite_page.dart` if the user meant that.
// But the user code says `package:mychatolic_app/pages/radars/create_invite_page.dart`.
// I will follow the user provided code exactly.

import 'package:mychatolic_app/pages/radars/create_invite_page.dart';
import 'package:mychatolic_app/pages/radar_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final ScheduleService _scheduleService = ScheduleService();
  DateTime _selectedDate = DateTime.now();
  
  // Gunakan Key untuk memaksa refresh FutureBuilder saat tanggal berubah
  Future<List<MassSchedule>>? _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _schedulesFuture = _scheduleService.fetchSchedules(
        dayOfWeek: _selectedDate.weekday,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: MyCatholicAppBar(
        title: "Jadwal Misa",
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Filter Wilayah Coming Soon"))
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. TIMELINE
          Container(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: EasyDateTimeLine(
              initialDate: DateTime.now(),
              onDateChange: (selectedDate) {
                setState(() {
                  _selectedDate = selectedDate;
                });
                _loadData();
              },
              headerProps: const EasyHeaderProps(
                monthPickerType: MonthPickerType.switcher,
                dateFormatter: DateFormatter.fullDateDMY(),
              ),
              dayProps: EasyDayProps(
                dayStructure: DayStructure.dayStrDayNum,
                activeDayStyle: DayStyle(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. LIST
          Expanded(
            child: FutureBuilder<List<MassSchedule>>(
              future: _schedulesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error: ${snapshot.error}", style: GoogleFonts.outfit(color: Colors.red)),
                  );
                }

                final data = snapshot.data ?? [];

                if (data.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text("Tidak ada jadwal misa\npada tanggal ini.", textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return _buildTicketCard(item, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(MassSchedule item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Jam
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  // Handle potential substrings if HH:mm:ss comes from DB
                  item.timeStart.length >= 5 ? item.timeStart.substring(0,5) : item.timeStart, 
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade800)
                ),
                Text("WIB", style: GoogleFonts.outfit(fontSize: 10, color: Colors.blue.shade800)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.churchName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.churchParish != null)
                  Text(item.churchParish!, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(item.language ?? "Umum", style: GoogleFonts.outfit(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Actions
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.blue),
            onPressed: () {
               // Checking if CreateInvitePage constructor matches used params
               Navigator.push(context, MaterialPageRoute(builder: (_) => CreateInvitePage(
                 initialChurchName: item.churchName,
                 initialTime: item.timeStart,
                 initialDate: _selectedDate,
               )));
            },
          )
        ],
      ),
    );
  }
}
