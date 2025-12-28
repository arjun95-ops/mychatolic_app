import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/widgets/post_card.dart';
import 'package:mychatolic_app/widgets/radar_feed_card.dart';
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';
// Import halaman notifikasi
import 'package:mychatolic_app/pages/notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final SocialService _socialService = SocialService();
  final RadarService _radarService = RadarService();
  final MasterDataService _masterService = MasterDataService();

  List<dynamic> _feedItems = []; 
  bool _isLoading = false;

  // Filter State
  Country? _selectedCountry;
  Diocese? _selectedDiocese;
  Church? _selectedChurch;

  @override
  void initState() {
    super.initState();
    refreshPosts();
  }

  Future<void> refreshPosts() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final List<UserPost> posts = await _socialService.fetchPosts(); 
      final radars = await _radarService.fetchPublicRadars();

      List<dynamic> combined = [];
      combined.addAll(posts);
      combined.addAll(radars);

      combined.sort((a, b) {
        DateTime timeA = (a is UserPost) ? a.createdAt : DateTime.parse(a['created_at']);
        DateTime timeB = (b is UserPost) ? b.createdAt : DateTime.parse(b['created_at']);
        return timeB.compareTo(timeA); 
      });

      if (mounted) setState(() { _feedItems = combined; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLocationFilter() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24), height: MediaQuery.of(context).size.height * 0.8,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Filter Lokasi", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildFilterItem<Country>("Negara", _selectedCountry?.name, () => _showSelectionSheet<Country>(context, "Pilih Negara", () => _masterService.fetchCountries(), (item) => item.name, (item) => null, (selected) { setModalState(() { _selectedCountry = selected; _selectedDiocese = null; _selectedChurch = null; }); })),
                _buildFilterItem<Diocese>("Keuskupan", _selectedDiocese?.name, () { if (_selectedCountry == null) return; _showSelectionSheet<Diocese>(context, "Pilih Keuskupan", () => _masterService.fetchDioceses(_selectedCountry!.id), (item) => item.name, (item) => null, (selected) { setModalState(() { _selectedDiocese = selected; _selectedChurch = null; }); }); }),
                _buildFilterItem<Church>("Gereja", _selectedChurch?.name, () { if (_selectedDiocese == null) return; _showSelectionSheet<Church>(context, "Pilih Gereja", () => _masterService.fetchChurches(_selectedDiocese!.id), (item) => item.name, (item) => item.address, (selected) { setModalState(() { _selectedChurch = selected; }); }); }),
                const Spacer(),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { Navigator.pop(context); refreshPosts(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0088CC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Terapkan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
            ]),
          );
      }),
    );
  }

  Widget _buildFilterItem<T>(String label, String? value, VoidCallback onTap) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(value ?? "Pilih $label", style: GoogleFonts.outfit(color: value != null ? Colors.black : Colors.grey)), const Icon(Icons.arrow_drop_down, color: Colors.grey)]))));
  }

  void _showSelectionSheet<T>(BuildContext context, String title, Future<List<T>> Function() fetch, String Function(T) getName, String? Function(T) getSubtitle, Function(T) onSelect) {
    showModalBottomSheet(context: context, builder: (ctx) => _SearchableSelectionSheet<T>(title: title, fetch: fetch, getName: getName, getSubtitle: getSubtitle, onSelect: onSelect));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        // KEMBALIKAN WARNA BIRU
        backgroundColor: const Color(0xFF0088CC),
        elevation: 0,
        centerTitle: false,
        title: Text(
          "MyCatholic", 
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)
        ),
        actions: [
          // TOMBOL FILTER (Lebih Menarik)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), // Transparan Putih
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
              tooltip: "Filter Lokasi",
              onPressed: _showLocationFilter,
            ),
          ),
          
          // TOMBOL NOTIFIKASI (Ikon Api)
          IconButton(
            icon: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 28), // Ikon Api
            tooltip: "Notifikasi",
            onPressed: () {
               // Navigasi ke Halaman Notifikasi
               Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshPosts,
        child: CustomScrollView(
          slivers: [
            // List Feed
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _feedItems[index];
                  if (item is UserPost) {
                    return PostCard(post: item, socialService: _socialService);
                  } else {
                    return RadarFeedCard(radarData: Map<String, dynamic>.from(item), onTap: () {});
                  }
                },
                childCount: _feedItems.length,
              ),
            ),
            
            if (_isLoading) 
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())))
            else if (_feedItems.isEmpty) 
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(50), child: Center(child: Text("Belum ada postingan.", style: TextStyle(color: Colors.grey)))))
          ],
        ),
      ),
    );
  }
}

// Helper Class (Tetap Sama)
class _SearchableSelectionSheet<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function() fetch;
  final String Function(T) getName;
  final String? Function(T) getSubtitle;
  final Function(T) onSelect;
  const _SearchableSelectionSheet({required this.title, required this.fetch, required this.getName, required this.getSubtitle, required this.onSelect});
  @override State<_SearchableSelectionSheet<T>> createState() => _SearchableSelectionSheetState<T>();
}
class _SearchableSelectionSheetState<T> extends State<_SearchableSelectionSheet<T>> {
  List<T> _items = []; List<T> _filteredItems = []; bool _loading = true;
  @override void initState() { super.initState(); _loadData(); }
  void _loadData() async { try { final data = await widget.fetch(); if (mounted) setState(() { _items = data; _filteredItems = data; _loading = false; }); } catch (e) { if (mounted) setState(() => _loading = false); } }
  void _filter(String q) { setState(() { _filteredItems = q.isEmpty ? _items : _items.where((i) => widget.getName(i).toLowerCase().contains(q.toLowerCase())).toList(); }); }
  @override Widget build(BuildContext context) { return Container(height: MediaQuery.of(context).size.height * 0.7, padding: const EdgeInsets.all(16), child: Column(children: [Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16), TextField(onChanged: _filter, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: "Cari...", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))), const SizedBox(height: 12), Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(itemCount: _filteredItems.length, itemBuilder: (ctx, i) { final item = _filteredItems[i]; final sub = widget.getSubtitle(item); return ListTile(title: Text(widget.getName(item)), subtitle: sub != null ? Text(sub, style: const TextStyle(color: Colors.grey)) : null, onTap: () { widget.onSelect(item); Navigator.pop(context); }); }))])); }
}
