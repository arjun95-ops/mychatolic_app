import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Pages
import 'package:mychatolic_app/pages/home_screen.dart'; 
import 'package:mychatolic_app/pages/create_post_screen.dart'; 
import 'package:mychatolic_app/pages/schedule_page.dart'; 
import 'package:mychatolic_app/pages/consilium/consilium_page.dart';
import 'package:mychatolic_app/pages/profile_page.dart';
import 'package:mychatolic_app/pages/radar_page.dart';
import 'package:mychatolic_app/pages/social_inbox_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0;

  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  Key _profilePageKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _updateLastActive();
    _checkUserProfile();
  }

  void _checkUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final profile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (profile == null) {
        // Handle missing profile
      }
    }
  }

  Future<void> _updateLastActive() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').update({
          'last_active': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      } catch (e) {
        debugPrint("Error updating last active: $e");
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan urutan children sesuai dengan BottomNavigationBar items
    final List<Widget> children = [
      HomeScreen(key: _homeScreenKey),
      const SchedulePage(),     // Index 1: Jadwal
      const RadarPage(),        // Index 2: Radar
      const ConsiliumPage(),    // Index 3: Consilium
      const SocialInboxPage(),  // Index 4: Chat
      ProfilePage(key: _profilePageKey), // Index 5: Profil
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      body: IndexedStack(
        index: _currentIndex,
        children: children,
      ),
      floatingActionButton: _currentIndex == 0 
          ? FloatingActionButton(
              heroTag: 'home_fab', 
              onPressed: () async {
                 final result = await Navigator.push(
                   context, 
                   MaterialPageRoute(builder: (_) => const CreatePostScreen())
                 );
                 
                 if (result == true) {
                   _homeScreenKey.currentState?.refreshPosts(); 
                   setState(() {
                     _currentIndex = 0;
                     _profilePageKey = UniqueKey(); 
                   });
                 }
              },
              backgroundColor: const Color(0xFF0088CC), 
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Theme.of(context).cardColor, 
          boxShadow: [
             BoxShadow(
               color: Theme.of(context).shadowColor.withOpacity(0.1), 
               blurRadius: 10, 
               offset: const Offset(0, -4) 
             )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          elevation: 0,
          selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Jadwal"),
            BottomNavigationBarItem(icon: Icon(Icons.radar), label: "Radar"),
            BottomNavigationBarItem(icon: Icon(Icons.spa), label: "Consilium"),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: "Chat"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
          ],
        ),
      ),
    );
  }
}
