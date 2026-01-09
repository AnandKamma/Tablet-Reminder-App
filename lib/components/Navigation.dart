import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tablet_reminder/screens/HomePage.dart';
import 'package:tablet_reminder/screens/Calendar.dart';
import 'package:tablet_reminder/Widgets/Liquid_Glass_NavBar.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    this.patientGroupID,
    this.isDoctorView = false,
  });
  final String? patientGroupID;
  final bool isDoctorView;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  // ✅ ONLY use this method to build pages
  List<Widget> _buildPages() {
    return [
      HomePage(
        patientGroupID: widget.patientGroupID,
        isDoctorView: widget.isDoctorView,
      ),
      const MedicationCalendar(),
    ];
  }

  // ❌ REMOVE THIS - Delete the _pages list completely
  // final List<Widget> _pages = [
  //    HomePage(),
  //   const MedicationCalendar(),
  // ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_updateTabIndex);
  }

  void _updateTabIndex() {
    if (_tabController.index != _selectedIndex) {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    }
  }

  void _onTabTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _tabController.animateTo(index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(); // ✅ Build pages here

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: pages, // ✅ Use pages instead of _pages
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: LiquidGlassNavBar(
              currentIndex: _selectedIndex,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }
}