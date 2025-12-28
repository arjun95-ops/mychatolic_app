import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/services/supabase_service.dart';
import 'package:mychatolic_app/services/radar_service.dart';
// Import halaman selection
import 'package:mychatolic_app/pages/radars/friend_selection_page.dart';

class CreateInvitePage extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName; // Opsional, untuk display awal jika ada
  
  // Parameter Autofill dari Jadwal
  final String? initialChurchName;
  final String? initialChurchId;
  final DateTime? initialDate;
  final String? initialTime; 

  const CreateInvitePage({
    super.key, 
    this.targetUserId,
    this.targetUserName,
    this.initialChurchName,
    this.initialChurchId,
    this.initialDate,
    this.initialTime,
  });

  @override
  State<CreateInvitePage> createState() => _CreateInvitePageState();
}

class _CreateInvitePageState extends State<CreateInvitePage> {
  final SupabaseService _supabaseService = SupabaseService();
  final RadarService _radarService = RadarService();
  final _supabase = Supabase.instance.client;

  // Form Controllers
  final TextEditingController _countryController = TextEditingController(text: "Indonesia");
  final TextEditingController _dioceseController = TextEditingController();
  final TextEditingController _churchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  // Selection State
  String? _selectedCountryId;
  String? _selectedDioceseId; 
  String? _selectedChurchId; 
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  // Friend State
  Map<String, dynamic>? _selectedTargetUser;
  bool _isFetchingUser = false;

  bool _isLoading = false;

  static const Color primaryBrand = Color(0xFF0088CC);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF555555);

  @override
  void initState() {
    super.initState();
    _performReverseLookup();
    _applyInitialData();
    _initTargetUser();
  }

  void _initTargetUser() async {
    // Skenario 1: Masuk dari Profil User Lain
    if (widget.targetUserId != null) {
      setState(() => _isFetchingUser = true);
      try {
        final data = await _supabase.from('profiles')
            .select('id, full_name, avatar_url, username')
            .eq('id', widget.targetUserId!)
            .single();
        if (mounted) {
          setState(() {
            _selectedTargetUser = data;
            _isFetchingUser = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isFetchingUser = false);
      }
    } 
    // Skenario 2: Masuk dari Jadwal (Target User masih null)
  }

  void _applyInitialData() {
    if (widget.initialChurchName != null) _churchController.text = widget.initialChurchName!;
    if (widget.initialChurchId != null) _selectedChurchId = widget.initialChurchId;
    if (widget.initialDate != null) _selectedDate = widget.initialDate;
    if (widget.initialTime != null) {
      try {
        final parts = widget.initialTime!.split(':');
        if (parts.length >= 2) _selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (e) { debugPrint("Time err: $e"); }
    }
  }

  Future<void> _performReverseLookup() async {
     try {
        if (_countryController.text.isNotEmpty) {
          final cData = await _supabase.from('countries').select('id').ilike('name', _countryController.text).maybeSingle();
          if (cData != null && mounted) setState(() => _selectedCountryId = cData['id'].toString());
        }
     } catch (e) { debugPrint("Lookup failed: $e"); }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: primaryBrand)), child: child!)
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: primaryBrand)), child: child!)
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _openFriendSelector() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const FriendSelectionPage())
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedTargetUser = result;
      });
    }
  }

  Future<void> _submitInvite() async {
    // Validasi Teman
    if (_selectedTargetUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih teman yang ingin diajak!")));
      return;
    }
    // Validasi Gereja
    if (_selectedChurchId == null && _churchController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih Gereja terlebih dahulu!")));
      return;
    }
    // Validasi Waktu
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tentukan Waktu Misa!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final DateTime finalSchedule = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );

      await _radarService.createPersonalRadar(
        targetUserId: _selectedTargetUser!['id'], // Gunakan ID dari user yang dipilih
        churchId: _selectedChurchId ?? '',
        churchName: _churchController.text,
        scheduleTime: finalSchedule,
        message: _messageController.text,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Undangan ke ${_selectedTargetUser!['full_name']} terkirim!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengirim: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSearchableSelection({required String title, required String tableName, required Function(Map<String, dynamic>) onSelect, String? filterColumn, dynamic filterValue}) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SearchableListModal(title: title, tableName: tableName, onSelect: onSelect, supabase: _supabase, filterColumn: filterColumn, filterValue: filterValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
        child: SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitInvite,
            style: ElevatedButton.styleFrom(backgroundColor: primaryBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                              : Text("KIRIM UNDANGAN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false, 
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              color: const Color(0xFFF9FAFB),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                 GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: const Icon(Icons.close, color: textPrimary, size: 20))),
                 const SizedBox(height: 24),
                 Text("Buat Ajakan Misa", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary)),
              ]),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    
                    // SECTION: TEMAN (KEPADA SIAPA?)
                    _buildSectionTitle("KEPADA"),
                    const SizedBox(height: 12),
                    if (_isFetchingUser)
                      const Center(child: LinearProgressIndicator())
                    else if (_selectedTargetUser != null)
                      // TAMPILAN JIKA TEMAN SUDAH DIPILIH
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _selectedTargetUser!['avatar_url'] != null ? NetworkImage(_selectedTargetUser!['avatar_url']) : null,
                              child: _selectedTargetUser!['avatar_url'] == null ? const Icon(Icons.person, color: Colors.grey) : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_selectedTargetUser!['full_name'] ?? "User", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text("@${_selectedTargetUser!['username']}", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            // Jika masuk lewat Profil, tombol ganti disembunyikan. Jika lewat Jadwal, boleh ganti.
                            if (widget.targetUserId == null)
                              IconButton(
                                icon: const Icon(Icons.change_circle_outlined, color: primaryBrand),
                                onPressed: _openFriendSelector,
                              )
                          ],
                        ),
                      )
                    else
                      // TOMBOL PILIH TEMAN (Jika belum ada)
                      GestureDetector(
                        onTap: _openFriendSelector,
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: primaryBrand.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryBrand.withOpacity(0.3), style: BorderStyle.solid),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_alt_1_rounded, color: primaryBrand),
                              const SizedBox(width: 10),
                              Text("Pilih Teman untuk Diajak", style: GoogleFonts.outfit(color: primaryBrand, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // SECTION: LOKASI
                    _buildSectionTitle("LOKASI"), const SizedBox(height: 12),
                    _buildActionCard(
                      label: "Negara", value: _countryController.text, icon: Icons.public,
                      onTap: () => _showSearchableSelection(title: "Pilih Negara", tableName: "countries", onSelect: (item) {
                        setState(() { _countryController.text = item['name']; _selectedCountryId = item['id'].toString(); _dioceseController.clear(); _selectedDioceseId = null; _churchController.clear(); _selectedChurchId = null; });
                      })
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      label: "Keuskupan", value: _dioceseController.text.isEmpty ? "Pilih Keuskupan" : _dioceseController.text, icon: Icons.account_balance,
                      isPlaceholder: _dioceseController.text.isEmpty,
                      onTap: () {
                        if (_selectedCountryId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih Negara Terlebih Dahulu"))); return; }
                        _showSearchableSelection(title: "Pilih Keuskupan", tableName: "dioceses", filterColumn: "country_id", filterValue: _selectedCountryId, onSelect: (item) {
                           setState(() { _dioceseController.text = item['name']; _selectedDioceseId = item['id'].toString(); _churchController.clear(); _selectedChurchId = null; });
                        });
                      }
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      label: "Gereja / Paroki", value: _churchController.text.isEmpty ? "Pilih Gereja" : _churchController.text, icon: Icons.church,
                      isPlaceholder: _churchController.text.isEmpty,
                      onTap: () {
                         if (_selectedDioceseId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih Keuskupan Terlebih Dahulu"))); return; }
                        _showSearchableSelection(title: "Pilih Gereja", tableName: "churches", filterColumn: "diocese_id", filterValue: _selectedDioceseId, onSelect: (item) {
                             setState(() { _churchController.text = item['name']; _selectedChurchId = item['id'].toString(); });
                        });
                      }
                    ),
                    
                    const SizedBox(height: 32), _buildSectionTitle("WAKTU"), const SizedBox(height: 12),
                    Row(children: [
                        Expanded(child: _buildActionCard(label: "Tanggal", value: _selectedDate == null ? "Tanggal" : DateFormat("dd MMM yyyy").format(_selectedDate!), icon: Icons.calendar_today, isPlaceholder: _selectedDate == null, onTap: _pickDate)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildActionCard(label: "Jam", value: _selectedTime == null ? "Jam" : _selectedTime!.format(context), icon: Icons.access_time, isPlaceholder: _selectedTime == null, onTap: _pickTime)),
                    ]),
                    
                    const SizedBox(height: 32), _buildSectionTitle("PESAN"), const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: TextField(controller: _messageController, maxLines: 3, style: GoogleFonts.outfit(color: textPrimary, fontSize: 16), decoration: InputDecoration(border: InputBorder.none, hintText: "Tulis pesan singkat (opsional)...", hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400))),
                    ),
                    const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(left: 4), child: Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)));

  Widget _buildActionCard({required String label, required String value, required IconData icon, required VoidCallback onTap, bool isPlaceholder = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64, padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: primaryBrand, size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.outfit(color: isPlaceholder ? Colors.grey.shade400 : textPrimary, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 16),
        ]),
      ),
    );
  }
}

// --- SEARCHABLE MODAL (Internal Component) ---
class _SearchableListModal extends StatefulWidget {
  final String title, tableName;
  final Function(Map<String, dynamic>) onSelect;
  final SupabaseClient supabase;
  final String? filterColumn;
  final dynamic filterValue;
  const _SearchableListModal({required this.title, required this.tableName, required this.onSelect, required this.supabase, this.filterColumn, this.filterValue});
  @override State<_SearchableListModal> createState() => _SearchableListModalState();
}

class _SearchableListModalState extends State<_SearchableListModal> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _res = []; bool _load = false; Timer? _deb;
  static const Color brand = Color(0xFF0088CC);

  @override void initState() { super.initState(); _runSearch(""); }
  @override void dispose() { _search.dispose(); _deb?.cancel(); super.dispose(); }

  void _runSearch(String q) {
    if (_deb?.isActive ?? false) _deb!.cancel();
    _deb = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _load = true);
      try {
        var db = widget.supabase.from(widget.tableName).select('id, name');
        if (widget.filterColumn != null && widget.filterValue != null) db = db.eq(widget.filterColumn!, widget.filterValue);
        if (widget.tableName == 'churches') db = db.eq('type', 'parish');
        final d = await db.ilike('name', '%$q%').limit(20);
        if (mounted) setState(() => _res = List<Map<String, dynamic>>.from(d));
      } catch (e) { if (mounted) setState(() => _res = []); } 
      finally { if (mounted) setState(() => _load = false); }
    });
  }

  @override Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7, padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text(widget.title, style: GoogleFonts.outfit(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextField(controller: _search, onChanged: _runSearch, style: GoogleFonts.outfit(color: Colors.black), decoration: InputDecoration(prefixIcon: const Icon(Icons.search, color: Colors.grey), hintText: "Cari ${widget.title}...", filled: true, fillColor: const Color(0xFFF0F2F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 16),
          Expanded(child: _load ? const Center(child: CircularProgressIndicator(color: brand)) : _res.isEmpty ? Center(child: Text("Tidak ditemukan", style: GoogleFonts.outfit(color: Colors.grey))) : ListView.separated(itemCount: _res.length, separatorBuilder: (_,__) => Divider(color: Colors.grey.shade100, height: 1), itemBuilder: (ctx, i) => ListTile(title: Text(_res[i]['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w500)), onTap: () { widget.onSelect(_res[i]); Navigator.pop(context); }, trailing: const Icon(Icons.chevron_right, color: Colors.grey))))
      ]),
    );
  }
}
