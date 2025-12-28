import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/services/supabase_service.dart';

class RadarService {
  final _supabase = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();

  // 1. Create Radar from Schedule
  Future<void> createRadarFromSchedule({
    required String scheduleId,
    required String notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      final scheduleData = await _supabase
          .from('mass_schedules')
          .select('church_id, time_start, day_of_week')
          .eq('id', scheduleId)
          .single();

      final churchId = scheduleData['church_id'];
      final timeStart = scheduleData['time_start'] as String;
      final dayOfWeek = scheduleData['day_of_week'] as int;

      final now = DateTime.now();
      int currentDayDb = (now.weekday == 7) ? 0 : now.weekday; 
      
      int daysToAdd = (dayOfWeek - currentDayDb + 7) % 7;
      final parts = timeStart.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (daysToAdd == 0) {
         final timeNow = now.hour * 60 + now.minute;
         final timeMass = hour * 60 + minute;
         if (timeNow > timeMass) daysToAdd = 7;
      }

      final scheduleTime = DateTime(now.year, now.month, now.day + daysToAdd, hour, minute);
      final expiresAt = scheduleTime.add(const Duration(hours: 24));

      await _supabase.from('radars').insert({
        'user_id': user.id,
        'type': 'mass',
        'visibility': 'public',
        'status': 'active',
        'title': 'Misa Bersama',
        'description': notes,
        'church_id': churchId,
        'schedule_id': scheduleId,
        'schedule_time': scheduleTime.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'participants': [user.id], // Creator otomatis jadi participant
        'created_at': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      print("Failed to create mass radar: $e");
      throw Exception("Gagal membuat radar jadwal: $e");
    }
  }

  // 2. Create Personal Radar
  Future<void> createPersonalRadar({
    required String targetUserId,
    required String churchId,
    required String churchName,
    required DateTime scheduleTime,
    required String message,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    try {
      final radar = await _supabase.from('radars').insert({
        'user_id': currentUser.id,
        'target_user_id': targetUserId,
        'type': 'personal',
        'visibility': 'private',
        'status': 'pending',
        'title': 'Ajakan Misa Bersama',
        'description': message,
        'church_id': churchId,
        'location_name': churchName,
        'schedule_time': scheduleTime.toIso8601String(),
        'participants': [currentUser.id, targetUserId],
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      await _supabase.from('notifications').insert({
        'user_id': targetUserId,
        'actor_id': currentUser.id,
        'type': 'invite_misa',
        'title': 'Ajakan Misa',
        'body': 'mengajak Anda Misa di $churchName',
        'related_id': radar['id'],
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

    } catch (e) {
      throw Exception("Gagal mengirim undangan radar: $e");
    }
  }

  // 3. Accept Personal Radar
  Future<void> acceptPersonalRadar(String radarId, String senderId) async {
    try {
      final chatId = await _supabaseService.startChat(senderId);
      await _supabase.from('radars').update({
        'status': 'active',
        'chat_group_id': chatId 
      }).eq('id', radarId);

    } catch (e) {
      throw Exception("Gagal menerima undangan: $e");
    }
  }

  // 4. Fetch My Radars (UPDATED)
  Future<List<Map<String, dynamic>>> fetchMyRadars() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // PERBAIKAN: Mengambil radar buatan sendiri ATAU radar di mana saya jadi participant
      // Syntax 'participants.cs.{uid}' artinya column participants CONTAINS (cs) array {uid}
      final response = await _supabase
          .from('radars')
          .select('*, churches(name), profiles:user_id(full_name, avatar_url)')
          .or('user_id.eq.${user.id},participants.cs.{${user.id}}') 
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error fetching my radars: $e");
      return [];
    }
  }

  // 5. Fetch Radar Invites
  Future<List<Map<String, dynamic>>> fetchRadarInvites() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('radars')
          .select('*, churches(name), profiles:user_id(full_name, avatar_url)')
          .eq('type', 'personal')
          .eq('target_user_id', user.id)
          .neq('status', 'active') 
          .neq('status', 'declined') 
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // 6. Fetch Public Radars
  Future<List<Map<String, dynamic>>> fetchPublicRadars() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final List<Future<dynamic>> tasks = [
        _supabase.from('profiles').select('diocese_id').eq('id', user.id).single(),
        _supabase.from('follows').select('following_id').eq('follower_id', user.id),
      ];

      final results = await Future.wait(tasks);

      final myDioceseId = (results[0] as Map)['diocese_id'];
      final followingList = (results[1] as List).map((e) => e['following_id']).toSet();

      final response = await _supabase
          .from('radars')
          .select('*, churches(name), profiles:user_id(full_name, avatar_url, diocese_id)')
          .eq('visibility', 'public')
          .neq('user_id', user.id)
          .order('created_at', ascending: false);

      final allRadars = List<Map<String, dynamic>>.from(response);

      final filtered = allRadars.where((radar) {
        final ownerData = radar['profiles'];
        if (ownerData == null) return false;

        final ownerId = radar['user_id'];
        final ownerDiocese = ownerData['diocese_id'];

        final isFriend = followingList.contains(ownerId);
        final isSameDiocese = (myDioceseId != null && ownerDiocese == myDioceseId);

        return isFriend || isSameDiocese;
      }).toList();

      return filtered;

    } catch (e) {
      return [];
    }
  }

  // 7. Delete (Creator) or Decline (Invitee)
  Future<void> deleteOrDeclineRadar(String radarId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Cek owner radar
      final data = await _supabase
          .from('radars')
          .select('user_id')
          .eq('id', radarId)
          .single();
      
      final ownerId = data['user_id'];

      if (ownerId == user.id) {
        // Saya Creator -> Hapus Permanen
        await _supabase.from('radars').delete().eq('id', radarId);
      } else {
        // Saya Invitee -> Tolak Undangan (Set status declined)
        // Atau bisa juga remove user dari array participants jika logikanya array based.
        // Untuk saat ini kita set status declined agar aman.
        await _supabase.from('radars').update({'status': 'declined'}).eq('id', radarId);
      }
    } catch (e) {
      throw Exception("Gagal menghapus/menolak radar: $e");
    }
  }
}
