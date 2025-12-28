class MassSchedule {
  final String id;
  final String churchId;
  final String churchName;
  final String? churchParish;
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
    String cName = 'Gereja';
    String? cInfo;
    
    if (json['churches'] != null) {
      final cData = json['churches'];
      cName = cData['name'] ?? cName;
      // PERBAIKAN: Prioritaskan 'address' jika 'parish' kosong
      cInfo = cData['parish'] ?? cData['parish_name'] ?? cData['address']; 
    }

    String time = json['time_start']?.toString() ?? '00:00';
    if (time.length > 5) {
      time = time.substring(0, 5);
    }

    return MassSchedule(
      id: json['id']?.toString() ?? '',
      churchId: json['church_id']?.toString() ?? '',
      churchName: cName,
      churchParish: cInfo, // Data alamat sekarang akan masuk ke sini
      timeStart: time,
      language: json['language'],
      dayOfWeek: json['day_of_week'] is int 
          ? json['day_of_week'] 
          : int.tryParse(json['day_of_week']?.toString() ?? '0') ?? 0,
    );
  }
}
