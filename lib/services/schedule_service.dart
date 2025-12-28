import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/mass_schedule.dart';

class ScheduleService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<MassSchedule>> fetchSchedules({
    required int dayOfWeek,
    String? churchId,
    String? dioceseId,
    String? countryId, 
  }) async {
    try {
      // PERBAIKAN: Gunakan select('*, churches!inner(*)') agar mengambil semua kolom gereja.
      // Ini lebih aman daripada menebak nama kolom satu per satu.
      var query = _supabase
          .from('mass_schedules')
          .select('*, churches!inner(*)');

      // Filter Utama
      query = query.eq('day_of_week', dayOfWeek);

      if (churchId != null) {
        query = query.eq('church_id', churchId);
      }
      
      // Filter Relasi
      if (dioceseId != null) {
         query = query.eq('churches.diocese_id', dioceseId);
      }
      
      if (countryId != null) {
         query = query.eq('churches.country_id', countryId);
      }

      // Order
      final response = await query.order('time_start', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => MassSchedule.fromJson(json)).toList();

    } catch (e) {
      print("Schedule Fetch Error: $e");
      throw Exception('Gagal memuat jadwal: $e');
    }
  }

  Future<List<MassSchedule>> getUpcomingSchedules() async {
    try {
      final now = DateTime.now();
      final currentDay = now.weekday; 
      final currentTime = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:00";

      final response = await _supabase
          .from('mass_schedules')
          .select('*, churches(*)') // Ambil semua kolom gereja
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
