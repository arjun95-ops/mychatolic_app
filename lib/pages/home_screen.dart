import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:mychatolic_app/pages/notification_screen.dart';
import 'package:mychatolic_app/pages/post_detail_screen.dart';
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/widgets/post_card.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final SocialService _socialService = SocialService();
  final ScrollController _scrollController = ScrollController();

  String _filterLabel = "Semua Lokasi"; 
  String? _filterType; 
  dynamic _filterId; 

  List<UserPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadMoreRunning = false;
  bool _hasNextPage = true;
  int _currentPage = 0;
  final int _limit = 20;
  String? _error;
  
  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    refreshPosts();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && 
        !_isLoading && 
        !_isLoadMoreRunning && 
        _hasNextPage) {
      _loadMorePosts();
    }
  }

  Future<void> refreshPosts({bool clearList = false}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _hasNextPage = true;
      
      if (clearList) {
        _posts = [];
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    });
    
    try {
      final posts = await _socialService.fetchPosts(
        filterType: _filterType,
        filterId: _filterId?.toString(),
        page: _currentPage,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          if (posts.length < _limit) {
            _hasNextPage = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadMoreRunning || !_hasNextPage) return;

    setState(() {
      _isLoadMoreRunning = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final posts = await _socialService.fetchPosts(
        filterType: _filterType,
        filterId: _filterId?.toString(),
        page: nextPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          if (posts.isNotEmpty) {
            _posts.addAll(posts);
            _currentPage = nextPage;
          }
          if (posts.length < _limit) {
            _hasNextPage = false;
          }
          _isLoadMoreRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadMoreRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat: $e')));
      }
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        currentLabel: _filterLabel,
        onSelect: (label, type, id) {
           setState(() {
             _filterLabel = label;
             _filterType = type;
             _filterId = id;
           });
           Navigator.pop(context); // Close Modal
           refreshPosts(clearList: true);
        },
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final Color iconColor = theme.primaryColor;
    final Color textColor = isDark ? Colors.white : const Color(0xFF2D3344);
    final Color subTextColor = isDark ? Colors.white54 : Colors.grey.shade500;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: MyCatholicAppBar(
        title: "MyCatholic",
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())), 
            icon: const Icon(Icons.notifications_outlined, color: Colors.white)
          ),
        ],
      ),
      body: Column(
        children: [
          // FLOATING FILTER BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: GestureDetector(
              onTap: _showFilterModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.tune_rounded, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Lokasi Feed", style: GoogleFonts.outfit(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(_filterLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor, fontSize: 15), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: subTextColor),
                  ],
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : (_error != null)
                  ? Center(child: Text("Terjadi kesalahan koneksi", style: GoogleFonts.outfit(color: Colors.red)))
                  : (_posts.isEmpty)
                      ? _buildPremiumEmptyState(textColor, subTextColor)
                      : RefreshIndicator(
                          onRefresh: () => refreshPosts(clearList: false),
                          color: theme.primaryColor,
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 100),
                            separatorBuilder: (ctx, idx) => Divider(height: 1, color: borderColor),
                            itemCount: _posts.length + (_isLoadMoreRunning ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _posts.length) {
                                return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                              }
                              final post = _posts[index];
                              return PostCard(
                                post: post, 
                                socialService: _socialService, 
                                onTap: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
                                },
                                onPostUpdated: (updatedPost) {
                                  setState(() {
                                    _posts[index] = updatedPost;
                                  });
                                },
                                heroTagPrefix: 'home',
                              );
                            },
                          ),
                        ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumEmptyState(Color titleColor, Color subColor) {
    String msg = "Belum ada postingan terbaru.";
    String subMsg = "Mulai ikuti orang lain atau bagikan cerita Anda!";
    if (_filterType != null) {
      msg = "Lokasi ini masih sepi";
      subMsg = "Jadilah orang pertama yang memposting\ndi lokasi ini!";
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), shape: BoxShape.circle),
              child: Icon(Icons.location_off_rounded, size: 48, color: subColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(msg, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subMsg, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: subColor, fontSize: 14)),
          ],
        ),
      )
    );
  }
}

// --- FILTER MODAL LOGIC ---

class _FilterBottomSheet extends StatefulWidget {
  final Function(String label, String? type, dynamic id) onSelect;
  final String currentLabel;
  const _FilterBottomSheet({required this.onSelect, required this.currentLabel});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  final MasterDataService _masterService = MasterDataService();
  
  List<Country> _countries = [];
  List<Diocese> _dioceses = [];
  List<Church> _churches = [];

  Country? _selectedCountry;
  Diocese? _selectedDiocese;
  Church? _selectedChurch;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() => _isLoading = true);
    try {
      final data = await _masterService.fetchCountries();
      if (mounted) setState(() { _countries = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDioceses(String countryId) async {
    setState(() => _isLoading = true);
    try {
      final data = await _masterService.fetchDioceses(countryId);
      if (mounted) setState(() { _dioceses = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChurches(String dioceseId) async {
    setState(() => _isLoading = true);
    try {
      final data = await _masterService.fetchChurches(dioceseId);
      if (mounted) setState(() { _churches = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    if (_selectedChurch != null) {
      widget.onSelect("${_selectedChurch!.name}", 'church', _selectedChurch!.id);
    } else if (_selectedDiocese != null) {
      widget.onSelect("${_selectedDiocese!.name}", 'diocese', _selectedDiocese!.id);
    } else if (_selectedCountry != null) {
      widget.onSelect("${_selectedCountry!.name}", 'country', _selectedCountry!.id);
    } else {
      widget.onSelect("Semua Lokasi", null, null);
    }
  }

  void _resetFilter() {
    setState(() {
      _selectedCountry = null;
      _selectedDiocese = null;
      _selectedChurch = null;
      _dioceses = [];
      _churches = [];
    });
  }

  // Helper untuk Membuka Modal Pencarian
  void _openSelectionModal<T>({
    required String title,
    required List<T> items,
    required String Function(T) getItemLabel,
    required Function(T?) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchableSelectionSheet<T>(
        title: title,
        items: items,
        getItemLabel: getItemLabel,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final Color bgSheet = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF2D3344);
    final Color dividerColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(color: bgSheet, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: dividerColor, borderRadius: BorderRadius.circular(2))),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Filter Lokasi", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                TextButton(
                  onPressed: _resetFilter, 
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: Text("Reset", style: GoogleFonts.outfit(fontWeight: FontWeight.w600))
                )
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildSelector<Country>(
                    label: "Negara",
                    icon: Icons.flag_rounded,
                    value: _selectedCountry,
                    items: _countries,
                    getItemLabel: (c) => c.name,
                    onChanged: (val) {
                      setState(() {
                        _selectedCountry = val;
                        _selectedDiocese = null; 
                        _selectedChurch = null;
                        _dioceses = [];
                        _churches = [];
                      });
                      if (val != null) _loadDioceses(val.id.toString());
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSelector<Diocese>(
                    label: "Keuskupan",
                    icon: Icons.account_balance_rounded,
                    value: _selectedDiocese,
                    items: _dioceses,
                    enabled: _selectedCountry != null,
                    getItemLabel: (d) => d.name,
                    onChanged: (val) {
                      setState(() {
                        _selectedDiocese = val;
                        _selectedChurch = null;
                        _churches = [];
                      });
                      if (val != null) _loadChurches(val.id.toString());
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSelector<Church>(
                    label: "Gereja / Paroki",
                    icon: Icons.church_rounded,
                    value: _selectedChurch,
                    items: _churches,
                    enabled: _selectedDiocese != null,
                    getItemLabel: (c) => c.name,
                    onChanged: (val) {
                      setState(() => _selectedChurch = val);
                    },
                  ),
                  
                  if (_isLoading) const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator())),
                ],
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(color: bgSheet, border: Border(top: BorderSide(color: dividerColor))),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _applyFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: theme.primaryColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("Terapkan Filter", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSelector<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) getItemLabel,
    required Function(T?) onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final Color labelColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final Color boxColor = enabled ? (isDark ? const Color(0xFF2C2C2C) : Colors.white) : (isDark ? Colors.white10 : Colors.grey.shade50);
    final Color borderColor = enabled ? (isDark ? Colors.white24 : Colors.grey.shade300) : Colors.transparent;
    final Color textColor = enabled ? (isDark ? Colors.white : const Color(0xFF2D3344)) : Colors.grey;

    String displayText = value != null ? getItemLabel(value) : "Pilih $label";
    if (!enabled) displayText = "Pilih $label (Terkunci)";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: enabled ? theme.primaryColor : Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(color: labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        
        GestureDetector(
          onTap: enabled ? () {
            _openSelectionModal<T>(
              title: "Pilih $label",
              items: items,
              getItemLabel: getItemLabel,
              onSelected: onChanged,
            );
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: enabled ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))] : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(displayText, style: GoogleFonts.outfit(color: value != null ? textColor : Colors.grey.shade400, fontWeight: FontWeight.w500)),
                ),
                Icon(Icons.search_rounded, size: 20, color: enabled ? Colors.grey.shade600 : Colors.grey.shade300),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- GENERIC SEARCHABLE SELECTION MODAL ---

class _SearchableSelectionSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) getItemLabel;
  final Function(T?) onSelected;

  const _SearchableSelectionSheet({
    required this.title,
    required this.items,
    required this.getItemLabel,
    required this.onSelected,
  });

  @override
  State<_SearchableSelectionSheet<T>> createState() => _SearchableSelectionSheetState<T>();
}

class _SearchableSelectionSheetState<T> extends State<_SearchableSelectionSheet<T>> {
  List<T> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filterList(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          return widget.getItemLabel(item).toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          // Header
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(widget.title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: text)),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: _filterList,
              style: GoogleFonts.outfit(color: text),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Cari...",
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _filteredItems.length + 1, // +1 for "Semua" option
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                // Option "Semua"
                if (index == 0) {
                  return ListTile(
                    title: Text("Semua ${widget.title.replaceAll('Pilih ', '')}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                    trailing: Icon(Icons.check_circle_outline, color: theme.primaryColor),
                    onTap: () {
                      widget.onSelected(null); // Return null means "All"
                      Navigator.pop(context);
                    },
                  );
                }
                
                final item = _filteredItems[index - 1];
                return ListTile(
                  title: Text(widget.getItemLabel(item), style: GoogleFonts.outfit(color: text)),
                  onTap: () {
                    widget.onSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
