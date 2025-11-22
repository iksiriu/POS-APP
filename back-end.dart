import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('users');
  await Hive.openBox('inventory');
  await Hive.openBox('transactions');

  // Seed example data if empty
  var users = Hive.box('users');
  if (users.isEmpty) {
    users.put('admin', {
      'username': 'admin',
      'password': 'admin',
      'role': 'admin',
    });
    users.put('cashier', {
      'username': 'cashier',
      'password': 'cashier',
      'role': 'cashier',
    });
  }

  var inv = Hive.box('inventory');
  if (inv.isEmpty) {
    // seed 5 items
    inv.put('1000000', {
      'id': '1000000',
      'name': 'Roti',
      'price': 5000,
      'stock': 20,
    });
    inv.put('1000001', {
      'id': '1000001',
      'name': 'Air Mineral',
      'price': 3000,
      'stock': 30,
    });
    inv.put('1000002', {
      'id': '1000002',
      'name': 'Chips',
      'price': 7000,
      'stock': 15,
    });
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Starter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userC = TextEditingController();
  final _passC = TextEditingController();
  String _error = '';

  void _login() {
    final users = Hive.box('users');
    final username = _userC.text.trim();
    final password = _passC.text.trim();
    for (var key in users.keys) {
      final u = users.get(key);
      if (u['username'] == username && u['password'] == password) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(user: u)),
        );
        return;
      }
    }
    setState(() => _error = 'Login gagal');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('POS Login')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _userC,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passC,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 12),
            ElevatedButton(onPressed: _login, child: Text('Login')),
            if (_error.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(_error, style: TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Map user;
  const HomePage({super.key, required this.user});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'];
    final pages =
        role == 'admin'
            ? [AdminInventoryPage(), ReportsPage()]
            : [CashierPage(), TransactionsTab()];
    final titles =
        role == 'admin' ? ['Inventory', 'Reports'] : ['Kasir', 'Riwayat'];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user['username']} (${role.toUpperCase()})'),
      ),
      body: pages[_selected],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selected,
        onTap: (i) => setState(() => _selected = i),
        items: List.generate(
          titles.length,
          (i) => BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: titles[i],
          ),
        ),
      ),
    );
  }
}

// -------------------- Admin Inventory Page --------------------
class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  _AdminInventoryPageState createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  final inv = Hive.box('inventory');
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();

  void _addItem() {
    final id = (int.parse(inv.keys.last ?? '1000000') + 1).toString();
    inv.put(id, {
      'id': id,
      'name': _name.text,
      'price': int.parse(_price.text),
      'stock': int.parse(_stock.text),
    });
    _name.clear();
    _price.clear();
    _stock.clear();
    setState(() {});
  }

  void _editItem(String key) {
    final item = inv.get(key);
    _name.text = item['name'];
    _price.text = item['price'].toString();
    _stock.text = item['stock'].toString();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Edit Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: 'Nama'),
                ),
                TextField(
                  controller: _price,
                  decoration: InputDecoration(labelText: 'Harga'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _stock,
                  decoration: InputDecoration(labelText: 'Stok'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  inv.put(key, {
                    'id': key,
                    'name': _name.text,
                    'price': int.parse(_price.text),
                    'stock': int.parse(_stock.text),
                  });
                  _name.clear();
                  _price.clear();
                  _stock.clear();
                  Navigator.pop(context);
                  setState(() {});
                },
                child: Text('Simpan'),
              ),
            ],
          ),
    );
  }

  void _deleteItem(String key) {
    inv.delete(key);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: inv.listenable(),
      builder: (context, box, _) {
        final keys = inv.keys.cast<String>().toList();
        return Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: keys.length,
                  itemBuilder: (_, i) {
                    final item = inv.get(keys[i]);
                    return ListTile(
                      title: Text('${item['name']}'),
                      subtitle: Text(
                        'Rp ${item['price']} • Stok: ${item['stock']}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () => _editItem(keys[i]),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _deleteItem(keys[i]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(),
              Text(
                'Tambah Item Baru',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: 'Nama'),
              ),
              TextField(
                controller: _price,
                decoration: InputDecoration(labelText: 'Harga'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _stock,
                decoration: InputDecoration(labelText: 'Stok'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 8),
              ElevatedButton(onPressed: _addItem, child: Text('Tambah')),
            ],
          ),
        );
      },
    );
  }
}

// -------------------- Cashier Page --------------------
class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  _CashierPageState createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  final inv = Hive.box('inventory');
  final cart = <Map>[];

  void _addToCart(Map item) {
    setState(() {
      cart.add({
        'id': item['id'],
        'name': item['name'],
        'price': item['price'],
        'qty': 1,
      });
    });
  }

  int get total => cart.fold<int>(
    0,
    (int s, e) => s + (e['price'] as int) * (e['qty'] as int),
  );

  void _checkout() {
    // generate a simple payload for QR
    final payload = Uuid().v4();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('QR Pembayaran'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(data: payload, size: 200),

                SizedBox(height: 8),
                Text('Total: Rp $total'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Simulate scanning: directly confirm payment
                  _confirmPayment(payload);
                  Navigator.pop(context);
                },
                child: Text('Simulate Scan / Bayar'),
              ),
            ],
          ),
    );
  }

  void _confirmPayment(String code) {
    // Create transaction and reduce stock
    final txBox = Hive.box('transactions');
    final now = DateTime.now();
    final txId = Uuid().v4();
    final tx = {
      'id': txId,
      'date': now.toIso8601String(),
      'total': total,
      'items':
          cart
              .map(
                (e) => {
                  'id': e['id'],
                  'name': e['name'],
                  'qty': e['qty'],
                  'price': e['price'],
                  'subtotal': e['price'] * e['qty'],
                },
              )
              .toList(),
    };
    txBox.put(txId, tx);

    // reduce inventory
    for (var c in cart) {
      final item = inv.get(c['id']);
      if (item != null) {
        final newStock = (item['stock'] as int) - (c['qty'] as int);
        inv.put(c['id'], {...item, 'stock': newStock});
      }
    }

    // clear cart
    setState(() => cart.clear());

    // show receipt page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptPage(tx: tx)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ValueListenableBuilder(
            valueListenable: inv.listenable(),
            builder: (_, box, __) {
              final keys = inv.keys.cast<String>().toList();
              return ListView.builder(
                itemCount: keys.length,
                itemBuilder: (_, i) {
                  final item = inv.get(keys[i]);
                  return ListTile(
                    title: Text(item['name']),
                    subtitle: Text(
                      'Rp ${item['price']} • Stok: ${item['stock']}',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _addToCart(item),
                      child: Text('Add'),
                    ),
                  );
                },
              );
            },
          ),
        ),
        VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Text('Cart', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: cart.length,
                  itemBuilder: (_, i) {
                    final c = cart[i];
                    return ListTile(
                      title: Text(c['name']),
                      subtitle: Text(
                        'Rp ${c['price']} x ${c['qty']} = Rp ${c['price'] * c['qty']}',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => setState(() => cart.removeAt(i)),
                      ),
                    );
                  },
                ),
              ),
              Divider(),
              Text('Total: Rp $total', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: cart.isEmpty ? null : _checkout,
                child: Text('Check Out'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------- Receipt Page --------------------
class ReceiptPage extends StatelessWidget {
  final Map tx;
  const ReceiptPage({super.key, required this.tx});
  @override
  Widget build(BuildContext context) {
    final items = (tx['items'] as List).cast<Map>();
    return Scaffold(
      appBar: AppBar(title: Text('Struk')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tanggal: ${tx['date']}'),
            SizedBox(height: 8),
            ...items.map(
              (it) =>
                  Text('${it['name']} x ${it['qty']} • Rp ${it['subtotal']}'),
            ),
            Divider(),
            Text(
              'Total: Rp ${tx['total']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- Transactions Tab --------------------
class TransactionsTab extends StatelessWidget {
  final txBox = Hive.box('transactions');

  TransactionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: txBox.listenable(),
      builder: (_, box, __) {
        final keys = txBox.keys.cast<String>().toList();
        return ListView.builder(
          itemCount: keys.length,
          itemBuilder: (_, i) {
            final tx = txBox.get(keys[i]);
            return ListTile(
              title: Text('Transaksi ${tx['id'].toString().substring(0, 8)}'),
              subtitle: Text(
                'Tanggal: ${tx['date']} • Total: Rp ${tx['total']}',
              ),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReceiptPage(tx: tx)),
                  ),
            );
          },
        );
      },
    );
  }
}

// -------------------- Reports Page (Admin) --------------------
class ReportsPage extends StatelessWidget {
  final txBox = Hive.box('transactions');

  ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final txs = txBox.values.cast<Map>().toList();
    final today = DateTime.now();
    final todayStr =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final todays =
        txs.where((t) => (DateTime.parse(t['date']).day == today.day)).toList();
    final total = todays.fold(0, (s, e) => s + (e['total'] as int));

    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Laporan Hari Ini',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Jumlah transaksi: ${todays.length}'),
          Text('Total pendapatan: Rp $total'),
          SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: todays.length,
              itemBuilder: (_, i) {
                final t = todays[i];
                return ListTile(
                  title: Text(
                    'Transaksi ${t['id'].toString().substring(0, 8)}',
                  ),
                  subtitle: Text('Total: Rp ${t['total']}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
