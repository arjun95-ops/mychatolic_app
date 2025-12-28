import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/mass_schedule.dart';

class ScheduleService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Mengambil jadwal misa berdasarkan hari dan filter opsional
  Future<List<MassSchedule>> fetchSchedules({
    required int dayOfWeek,
    String? churchId,
    String? dioceseId,
    String? countryId, // Parameter ini mungkin butuh logika filter manual jika tidak ada relasi langsung
  }) async {
    try {
      // 1. Mulai Query dengan Chaining Filter
      // Supabase Flutter SDK (Postgrest) mendukung chaining query yang dikombinasikan.
      // Kita perlu menyusun objek filter terlebih dahulu.
      
      var query = _supabase
          .from('mass_schedules')
          .select('*, churches!inner(id, name, parish_name, diocese_id, country_id)');

      // 2. Filter Utama
      query = query.eq('day_of_week', dayOfWeek);

      if (churchId != null) {
        query = query.eq('church_id', churchId);
      }
      
      // Filter Relasi (Inner Join)
      // Pastikan nama kolom 'diocese_id' dan 'country_id' ada di tabel 'churches'
      if (dioceseId != null) {
         query = query.eq('churches.diocese_id', dioceseId);
      }
      
      if (countryId != null) {
         query = query.eq('churches.country_id', countryId);
      }

      // 3. Eksekusi dengan Order (Order harus di akhir rantai sebelum await)
      final response = await query.order('time_start', ascending: true);

      // 4. Parsing Data
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => MassSchedule.fromJson(json)).toList();

    } catch (e) {
      // Fallback atau rethrow dengan pesan jelas
      throw Exception('Gagal memuat jadwal: $e');
    }
  }

  // Mengambil jadwal misa terdekat (Next Mass)
  Future<List<MassSchedule>> getUpcomingSchedules() async {
    try {
      final now = DateTime.now();
      final currentDay = now.weekday; // 1=Senin..7=Minggu
      final currentTime = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:00";

      // Cari jadwal hari ini yang jamnya belum lewat
      final response = await _supabase
          .from('mass_schedules')
          .select('*, churches(name, parish_name)')
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
