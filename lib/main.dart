import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/services/presentation/screens/services_screen.dart';
import 'features/bookings/presentation/screens/bookings_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'core/session/user_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserSession().loadSession();
  runApp(const ShuddhamApp());
}

class ShuddhamApp extends StatelessWidget {
  const ShuddhamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shuddham Water Solutions',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    if (index == 2) {
      BookingsScreen.refresh();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(onNavigate: _onTabSelected),
      ServicesScreen(onNavigate: _onTabSelected),
      const BookingsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.royalBlue.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop, color: AppTheme.royalBlue),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.cleaning_services_outlined),
            selectedIcon: Icon(Icons.cleaning_services, color: AppTheme.royalBlue),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: AppTheme.royalBlue),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.royalBlue),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
