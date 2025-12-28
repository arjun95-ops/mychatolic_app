import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/mass_schedule.dart';

class ScheduleService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // dayOfWeek sekarang Opsi (nullable)
  Future<List<MassSchedule>> fetchSchedules({
    int? dayOfWeek, 
    String? churchId,
    String? dioceseId,
    String? countryId, 
  }) async {
    try {
      // Ambil data jadwal + info gereja
      var query = _supabase
          .from('mass_schedules')
          .select('*, churches!inner(*)');

      // Filter Opsional
      if (dayOfWeek != null) {
        query = query.eq('day_of_week', dayOfWeek);
      }

      if (churchId != null) {
        query = query.eq('church_id', churchId);
      }
      
      if (dioceseId != null) {
         query = query.eq('churches.diocese_id', dioceseId);
      }
      
      if (countryId != null) {
         query = query.eq('churches.country_id', countryId);
      }

      // Order: Hari dulu (1-7), baru Jam
      final response = await query.order('day_of_week', ascending: true).order('time_start', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => MassSchedule.fromJson(json)).toList();

    } catch (e) {
      print("Schedule Fetch Error: $e");
      // Return list kosong agar UI tidak crash, atau rethrow jika ingin handle di UI
      return [];
    }
  }

  // Helper untuk fitur Next Mass (tetap sama)
  Future<List<MassSchedule>> getUpcomingSchedules() async {
    try {
      final now = DateTime.now();
      final currentDay = now.weekday; 
      final currentTime = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:00";

      final response = await _supabase
          .from('mass_schedules')
          .select('*, churches(*)')
          .eq('day_of_week', currentDay)
          .gte('time_start', currentTime)
          .order('time_start', ascending: true)
          .limit(3);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => MassSchedule.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}
