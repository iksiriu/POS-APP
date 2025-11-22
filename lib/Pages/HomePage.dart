import 'package:flutter/material.dart';
import 'CashierPage.dart';
import 'AdminInventoryPage.dart';
import 'ReportsPage.dart'; // Assuming you still need Reports page for admin

class HomePage extends StatefulWidget {
  final String role;
  const HomePage({required this.role, super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Use 0 for Cashier, 1 for Admin Inventory, 2 for Admin Reports
  int _selectedIndex = 0;
  late final List<Widget> _cashierPages;
  late final List<Widget> _adminPages;

  // Define a simple list of pages based on role
  List<Widget> get _pages =>
      widget.role == 'admin' ? _adminPages : _cashierPages;

  @override
  void initState() {
    super.initState();
    _cashierPages = [const CashierPage()];
    _adminPages = [
      const CashierPage(),
      const AdminInventoryPage(),
      const ReportsPage(),
    ];

    // If the user is an admin, start on the Admin Inventory page (index 1)
    if (widget.role == 'admin') {
      _selectedIndex = 1;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Define the items for the new navigation structure (e.g., using a Drawer for Admin)
  List<BottomNavigationBarItem> _buildAdminNavItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.shopping_cart),
        label: 'Cashier',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
      BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Cashier role only gets the CashierPage, no bottom bar needed.
    if (widget.role == 'cashier') {
      return const CashierPage();
    }

    // Admin role needs navigation between pages. We can keep the BottomBar for Admin
    // to navigate the different Admin functions, or switch to a Drawer/Side Menu.
    // Given your original structure, I'll keep a minimal BottomBar for Admin navigation:
    return Scaffold(
      // The content of the selected page
      body: Center(child: _pages.elementAt(_selectedIndex)),
      // Only show the navigation bar for the Admin role to switch between management tasks
      bottomNavigationBar:
          widget.role == 'admin'
              ? BottomNavigationBar(
                items: _buildAdminNavItems(),
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
              )
              : null, // No BottomNavigationBar for the Cashier role
    );
  }
}
