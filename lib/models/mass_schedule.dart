class MassSchedule {
  final String id;
  final String churchId;
  final String churchName;
  final String? churchParish; // Bisa berisi nama paroki atau alamat
  final String timeStart;
  final String? language;
  final int dayOfWeek;

  MassSchedule({
    required this.id,
    required this.churchId,
    required this.churchName,
    this.churchParish,
    required this.timeStart,
    this.language,
    required this.dayOfWeek,
  });

  factory MassSchedule.fromJson(Map<String, dynamic> json) {
    // Handling relasi nested 'churches'
    String cName = 'Gereja';
    String? cInfo;
    
    if (json['churches'] != null) {
      final cData = json['churches'];
      cName = cData['name'] ?? cName;
      // Coba ambil 'parish', jika null ambil 'parish_name', jika null ambil 'address'
      cInfo = cData['parish'] ?? cData['parish_name'] ?? cData['address']; 
    }

    // Parsing Time (HH:MM)
    String time = json['time_start']?.toString() ?? '00:00';
    if (time.length > 5) {
      time = time.substring(0, 5);
    }

    return MassSchedule(
      id: json['id']?.toString() ?? '',
      churchId: json['church_id']?.toString() ?? '',
      churchName: cName,
      churchParish: cInfo,
      timeStart: time,
      language: json['language'],
      dayOfWeek: json['day_of_week'] is int 
          ? json['day_of_week'] 
          : int.tryParse(json['day_of_week']?.toString() ?? '0') ?? 0,
    );
  }
}
