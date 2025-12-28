import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/other_user_profile_page.dart';

class FriendSearchPage extends StatefulWidget {
  final bool isSelectionMode;
  const FriendSearchPage({super.key, this.isSelectionMode = false});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final _supabase = Supabase.instance.client;
  
  // Filters
  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;
  
  // Names for display
  String? _countryName;
  String? _dioceseName;
  String? _churchName;

  RangeValues _ageRange = const RangeValues(18, 30);

  // Search Results
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  final Set<String> _sentRequests = {};

  // --- HELPERS: CASADING DROPDOWNS (Reusing Logic pattern) ---
  Future<void> _showSearchModal(String table, String? filterCol, String? filterVal, String title, Function(String id, String name) onSelect) async {
      // 1. Fetch Data
      var query = _supabase.from(table).select('id, name');
      if (filterCol != null && filterVal != null) query = query.eq(filterCol, filterVal);
      final res = await query.order('name');
      final allItems = List<Map<String, dynamic>>.from(res);

      if (!mounted) return;

      // 2. Show Modal
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1235), // Hardcoded AppTheme.deepViolet
        isScrollControlled: true,
        builder: (context) {
          List<Map<String, dynamic>> filteredItems = List.from(allItems);

          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
                    const SizedBox(height: 16),
                    
                    // Search Field
                    TextField(
                      onChanged: (val) {
                        setModalState(() {
                           filteredItems = allItems.where((item) => 
                             item['name'].toString().toLowerCase().contains(val.toLowerCase())
                           ).toList();
                        });
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Cari $title...",
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16)
                      ),
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (_, i) {
                          final item = filteredItems[i];
                          return ListTile(
                            title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                            onTap: () {
                               debugPrint("Tap Modal Item: ${item['name']}");
                               onSelect(item['id'].toString(), item['name']);
                               Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    )
                  ],
                ),
              );
            }
          );
        }
      );
  }

  Future<void> _doSearch() async {
    setState(() => _isLoading = true);

    try {
      // Base Query
      var query = _supabase.from('profiles').select();

      // Apply Location Filters
      if (_selectedChurchId != null) {
        query = query.eq('church_id', _selectedChurchId!);
      } else if (_selectedDioceseId != null) {
        query = query.eq('diocese_id', _selectedDioceseId!);
      } else if (_selectedCountryId != null) {
        query = query.eq('country_id', _selectedCountryId!);
      }

      // Execute Query
      final data = await query;
      
      // Client-side Age Filtering (Simpler than raw SQL date math)
      // Standard Age Calc: (Now - BirthDate).years
      final now = DateTime.now();
      final filtered = List<Map<String, dynamic>>.from(data).where((user) {
        if (user['birth_date'] == null) return false;
        final dob = DateTime.parse(user['birth_date']);
        // Age Calc: (DateTime.now() - birth_date).inDays / 365
        final age = (now.difference(dob).inDays / 365).floor();
        return age >= _ageRange.start && age <= _ageRange.end;
      }).toList();

      debugPrint("Found ${filtered.length} users");

      if (filtered.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tidak ada teman ditemukan di paroki ini."), 
            backgroundColor: Colors.orange
          )
        );
      }

      setState(() => _results = filtered);

    } on PostgrestException catch (pgError) {
      debugPrint("Postgrest Error: ${pgError.message} code: ${pgError.code}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Database Error: ${pgError.message}"), 
            backgroundColor: Colors.red
          ),
        );
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red)
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFriendRequest(Map<String, dynamic> targetUser) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Show Loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Memproses permintaan..."), duration: Duration(milliseconds: 1000), backgroundColor: Colors.blue)
    );

    try {
      // 1. Check Existing Request (Sent OR Received)
      final existing = await _supabase.from('friend_requests')
        .select()
        .or('and(sender_id.eq.$currentUserId,receiver_id.eq.${targetUser['id']}),and(sender_id.eq.${targetUser['id']},receiver_id.eq.$currentUserId)')
        .maybeSingle();

      if (existing != null) {
        final status = existing['status'];
        String msg = "";
        if (status == 'pending') {
           msg = (existing['sender_id'] == currentUserId) 
             ? "Permintaan sudah terkirim, menunggu respon."
             : "Orang ini sudah mengirimkan permintaan kepadamu. Cek notifikasi.";
        } else if (status == 'accepted') {
           msg = "Kalian sudah berteman!";
        } else {
           msg = "Status hubungan: $status";
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
          
          // If already pending, update UI to reflect that
          if (status == 'pending') {
            setState(() {
              _sentRequests.add(targetUser['id']);
            });
          }
        }
        return;
      }

      // 2. Send New Request
      await _supabase.from('friend_requests').insert({
        'sender_id': currentUserId,
        'receiver_id': targetUser['id'],
        'status': 'pending'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ajakan berteman dikirim ke ${targetUser['full_name']}!"), 
            backgroundColor: Colors.green
          )
        );
        setState(() {
          _sentRequests.add(targetUser['id']);
        });
      }

    } catch (e) {
      if (mounted) {
         // Check for duplicate key violates unique constraint manually if needed, usually handled by step 1
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengirim: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1235), // Hardcoded AppTheme.deepViolet
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? "Pilih Teman" : "Cari Teman", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // FILTERS SECTION
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF352453), // Hardcoded AppTheme.glassyViolet
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filter Pencarian", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 16),
                  
                  // Location Inputs
                  _buildSelector("Negara", _countryName, () => _showSearchModal('countries', null, null, "Pilih Negara", (id, name) {
                    debugPrint("ROOT SETSTATE: Country selected $name ($id)");
                    setState(() { 
                      _selectedCountryId = id; 
                      _countryName = name; 
                      _selectedDioceseId = null; 
                      _dioceseName = null; 
                      _selectedChurchId = null; 
                      _churchName = null; 
                    });
                  })),
                  const SizedBox(height: 12),
                  if (_selectedCountryId != null)
                    _buildSelector("Keuskupan", _dioceseName, () => _showSearchModal('dioceses', 'country_id', _selectedCountryId, "Pilih Keuskupan", (id, name) {
                        debugPrint("ROOT SETSTATE: Diocese selected $name ($id)");
                        setState(() { 
                          _selectedDioceseId = id; 
                          _dioceseName = name; 
                          _selectedChurchId = null; 
                          _churchName = null; 
                        });
                    })),
                  const SizedBox(height: 12),
                   if (_selectedDioceseId != null)
                    _buildSelector("Paroki", _churchName, () => _showSearchModal('churches', 'diocese_id', _selectedDioceseId, "Pilih Paroki", (id, name) {
                        debugPrint("ROOT SETSTATE: Church selected $name ($id)");
                        setState(() { 
                          _selectedChurchId = id; 
                          _churchName = name; 
                        });
                    })),
                  
                  const SizedBox(height: 24),
                  
                  // Age Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Rentang Umur", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
                      Text("${_ageRange.start.round()} - ${_ageRange.end.round()} thn", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF9F1C))),
                    ],
                  ),
                  RangeSlider(
                    values: _ageRange,
                    min: 17, max: 60,
                    divisions: 43,
                    activeColor: const Color(0xFFFF9F1C), // Hardcoded AppTheme.vibrantOrange
                    inactiveColor: Colors.black26,
                    labels: RangeLabels("${_ageRange.start.round()}", "${_ageRange.end.round()}"),
                    onChanged: (vals) => setState(() => _ageRange = vals),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                         debugPrint("BTN CHECK: Country=$_selectedCountryId, Diocese=$_selectedDioceseId, Church=$_selectedChurchId");
                         
                         if (_selectedCountryId == null || _selectedDioceseId == null || _selectedChurchId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Harap pilih Negara, Keuskupan, dan Paroki!"), backgroundColor: Colors.red)
                            );
                            return;
                         }
                         
                         _doSearch();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9F1C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text("CARI TEMAN", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // RESULTS
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF9F1C)))
                : _results.isEmpty 
                    ? const Center(child: Text("Hasil pencarian akan tampil di sini.", style: TextStyle(color: Colors.white38)))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_,__) => const SizedBox(height: 16),
                        itemBuilder: (_, i) {
                          final user = _results[i];
                          final isSelf = _supabase.auth.currentUser?.id == user['id'];
                          
                          // STATE for individual item loading/status is hard in a simple ListView without state separation. 
                          // For simplicity, we trigger the logic and show global feedback or generic feedback.
                          // Ideally, extract UserCard into a StatefulWidget.
                          // For this implementation, we will use a dialog or snackbar flow.

                          final isPending = _sentRequests.contains(user['id']);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            tileColor: const Color(0xFF352453), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: CircleAvatar(
                              backgroundColor: Colors.white10,
                              child: SafeNetworkImage(
                                imageUrl: user['avatar_url'],
                                width: 40, height: 40,
                                borderRadius: BorderRadius.circular(20),
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.person,
                                iconColor: Colors.white54,
                                fallbackColor: Colors.white10,
                              ),
                            ),
                            title: Text(user['full_name'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            subtitle: Text((user['role'] ?? "Umat").toString().toUpperCase(), style: const TextStyle(color: Color(0xFFFF9F1C), fontSize: 10, fontWeight: FontWeight.bold)),
                            trailing: widget.isSelectionMode 
                              ? null 
                              : isSelf ? null : (isPending 
                                  ? const IconButton(
                                      icon: Icon(Icons.hourglass_empty, color: Colors.grey),
                                      onPressed: null,
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.person_add_rounded, color: Color(0xFFFF9F1C)),
                                      onPressed: () => _handleFriendRequest(user),
                                    )
                                ),
                            onTap: () {
                              if (widget.isSelectionMode) {
                                Navigator.pop(context, user); 
                              } else if (!isSelf) {
                                // Optional: Open profile OR trigger add. Let's stick to Add Logic requested.
                                // If tapping card also triggers add, it might be annoying. 
                                // Let's open Profile for Tap, and "Add" button for Request.
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OtherUserProfilePage(userId: user['id'])),
                                );
                              }
                            },
                          );
                        },
                      ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSelector(String hint, String? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white10, // Hardcoded AppTheme.darkInputFill
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? hint, 
                style: TextStyle(color: value == null ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Color(0xFFFF9F1C)) // Hardcoded AppTheme.vibrantOrange
          ],
        ),
      ),
    );
  }
}
