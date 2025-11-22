import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for TextInputFormatter
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

import 'LoginPage.dart';

class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  _CashierPageState createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  // ALL METHODS AND WIDGETS GO INSIDE HERE
  final inv = Hive.box('inventory');
  // Use a List of Maps for cart items, ensuring each map represents a unique product.
  final cart = <Map>[];

  // List of available categories based on your design
  final List<String> categories = ['ALL', 'FOOD', 'DRINKS', 'THINGS'];
  String _selectedCategory = 'ALL';

  // Calculate total: sum of (price * qty) for all items in cart
  int get total =>
      cart.fold<int>(0, (s, e) => s + (e['price'] as int) * (e['qty'] as int));

  String detectCardType(String cardNumber) {
    // Remove spaces or non-digit characters for reliable checking
    final digits = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return ''; // Or return 'Unknown'
    }

    // Check for VISA (Starts with 4)
    if (digits.startsWith('4')) {
      return 'Visa';
    }

    // Check for MASTERCARD (Starts with 51, 52, 53, 54, or 55)
    // We only need to check the first two digits for Mastercard.
    if (digits.length >= 2) {
      final startTwoDigits = digits.substring(0, 2);
      final startInt = int.tryParse(startTwoDigits);

      if (startInt != null && startInt >= 51 && startInt <= 55) {
        return 'Mastercard';
      }
    }

    // Add other types if needed (e.g., Amex starts with 34 or 37)
    return 'Unknown';
  }

  void _logOut() {
    Navigator.pushAndRemoveUntil(
      context,
      // Changed target to LoginPage without passing a role.
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  // --- CART MANAGEMENT LOGIC ---
  void _showTransactionHistory() {
    final txBox = Hive.box('transactions');
    // Get all transactions and reverse the list so the newest is on top
    final transactions = txBox.values.cast<Map>().toList().reversed.toList();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Receipt History'),
            content: SizedBox(
              // Set a fixed size for the dialog content to make it scrollable
              width: 400,
              height: 600,
              child:
                  transactions.isEmpty
                      ? const Center(
                        child: Text('No transactions recorded yet.'),
                      )
                      : ListView.separated(
                        itemCount: transactions.length,
                        separatorBuilder:
                            (context, index) =>
                                const Divider(height: 1, thickness: 1),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          // Use a List Card to match the Receipt History design (image_27c078.png)
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            onTap: () {
                              // Call existing receipt function to show the detailed receipt
                              _showReceipt(tx);
                            },
                            title: const Text(
                              'Transaction ID',
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHistoryRow('Total', 'Rp ${tx['total']}'),
                                _buildHistoryRow(
                                  'Date',
                                  tx['date'].toString().substring(0, 10),
                                ),
                                _buildHistoryRow(
                                  'Payment',
                                  tx['paymentMethod'],
                                ),
                                _buildHistoryRow(
                                  'Status',
                                  'Paid',
                                ), // Status is always Paid upon saving
                              ],
                            ),
                            trailing: Text(
                              'TXR-${tx['id'].toString().substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  // Helper function to build the rows within the history list tile
  Widget _buildHistoryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _addToCart(Map item) {
    setState(() {
      final index = cart.indexWhere((c) => c['id'] == item['id']);
      if (index != -1) {
        // If item exists, increase quantity
        cart[index]['qty'] += 1;
      } else {
        // If item is new, add it
        cart.add({
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'qty': 1,
        });
      }
    });
  }

  void _updateCartQuantity(int index, int change) {
    setState(() {
      final currentQty = cart[index]['qty'];
      if (currentQty + change > 0) {
        cart[index]['qty'] = currentQty + change;
      } else {
        // Remove item if quantity drops to 0 or below
        cart.removeAt(index);
      }
    });
  }

  void _removeItemFromCart(int index) {
    setState(() => cart.removeAt(index));
  }

  // --- TRANSACTION CONFIRMATION & SAVING LOGIC ---

  void _confirmPayment(String paymentMethod) {
    if (cart.isEmpty) return;

    final txBox = Hive.box('transactions');
    final now = DateTime.now();
    final txId = const Uuid().v4();

    // Note: We need to capture the 'change' value for Cash transactions before clearing the cart.
    // However, since we show the change in the receipt, we need to handle it properly.
    // For now, let's keep the core transaction logic and address the change passing after this fix.

    final tx = {
      'id': txId,
      'date': now.toIso8601String(),
      'total': total,
      'paymentMethod': paymentMethod, // Store payment method
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

    // Update Inventory Stock (Backend Logic)
    for (var c in cart) {
      final item = inv.get(c['id']);
      if (item != null) {
        inv.put(c['id'], {
          ...item,
          'stock': (item['stock'] as int) - (c['qty'] as int),
        });
      }
    }

    // Show receipt and clear cart
    _showReceipt(tx);
    setState(() => cart.clear());
  }

  // --- PAYMENT MODALS / DIALOGS ---

  // NOTE: You are missing a way to pass the 'change' variable from _checkoutCash
  // to _confirmPayment and then to _showReceipt. We'll fix that.

  void _showReceipt(Map tx) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Struk Pembayaran (Receipt)'),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tanggal: ${tx['date'].toString().substring(0, 10)}'),
                  Text('Metode Pembayaran: ${tx['paymentMethod']}'),
                  const Divider(),
                  const Text(
                    'Items:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...(tx['items'] as List<dynamic>).map<Widget>(
                    (it) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${it['name']} x ${it['qty']}'),
                          Text('Rp ${it['subtotal']}'),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Total: Rp ${tx['total']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // The receipt now correctly checks for 'change' in the transaction map
                  if (tx['paymentMethod'] == 'Cash' && tx.containsKey('change'))
                    Text(
                      'Kembali: Rp ${tx['change']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup (Selesai)'),
              ),
            ],
          ),
    );
  }

  void _checkoutQRIS() {
    final payload = const Uuid().v4();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('QRIS Pembayaran'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FIX: Wrap QrImageView in a SizedBox to explicitly enforce constraints
                SizedBox(
                  width: 250, // Giving the QR code a definite container size
                  height: 250,
                  child: QrImageView(data: payload, size: 200),
                ),
                const SizedBox(height: 12),
                Text(
                  'Total: Rp $total',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Pass a change of 0 for non-cash transactions
                  Future.delayed(
                    const Duration(milliseconds: 100),
                    () => _confirmPayment('QRIS'),
                  );
                },
                child: const Text('Print Receipt (Simulate Payment)'),
              ),
            ],
          ),
    );
  }

  void _checkoutCard() {
    final cardNumberC = TextEditingController();
    final cardHolderC = TextEditingController();
    String detectedCardType = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final canPrint = cardNumberC.text.length >= 13;

            return AlertDialog(
              title: const Text('Pembayaran Kartu (Card)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Rp ${total}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(),

                    // Card Type Field (DISABLED, but text is forced to be black/dark)
                    // NOTE: Removed the `counterText` hack and fixed the controller setting
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Card Type',
                        hintText: 'Detected Card Type',
                        // Use a key to force the TextField to rebuild when detectedCardType changes
                        suffixText:
                            detectedCardType.isEmpty
                                ? 'Unknown'
                                : detectedCardType,
                        suffixStyle: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),

                    // Card Number Field
                    TextField(
                      controller: cardNumberC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Card Number',
                        hintText: 'Insert card number.',
                      ),
                      onChanged: (value) {
                        setState(() {
                          // Use the dialog's local setState
                          detectedCardType = detectCardType(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Card Holder Name (NOW ENABLED / FUNCTIONING)
                    TextField(
                      controller: cardHolderC,
                      decoration: const InputDecoration(
                        labelText: 'Card Holder Name',
                        hintText: 'Enter card holder name.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed:
                      canPrint
                          ? () {
                            Navigator.pop(context);
                            // Pass a change of 0 for non-cash transactions
                            Future.delayed(
                              const Duration(milliseconds: 100),
                              () => _confirmPayment('Card'),
                            );
                          }
                          : null,
                  child: const Text('Print Receipt'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // MODIFIED to accept change as a parameter
  void _confirmPaymentWithChange(String paymentMethod, {int change = 0}) {
    if (cart.isEmpty) return;

    final txBox = Hive.box('transactions');
    final now = DateTime.now();
    final txId = const Uuid().v4();
    final tx = {
      'id': txId,
      'date': now.toIso8601String(),
      'total': total,
      'paymentMethod': paymentMethod, // Store payment method
      'change': change, // Include change here
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

    // Update Inventory Stock (Backend Logic)
    for (var c in cart) {
      final item = inv.get(c['id']);
      if (item != null) {
        inv.put(c['id'], {
          ...item,
          'stock': (item['stock'] as int) - (c['qty'] as int),
        });
      }
    }

    // Show receipt and clear cart
    _showReceipt(tx);
    setState(() => cart.clear());
  }

  void _checkoutCash() {
    final receivedC = TextEditingController();

    // Show the cash payment dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          // Use StatefulBuilder to update the dialog's state
          builder: (context, setState) {
            final receivedAmount = int.tryParse(receivedC.text) ?? 0;
            final change = receivedAmount - total; // Calculate change directly
            final canPrint = receivedAmount >= total;

            return AlertDialog(
              title: const Text('Pembayaran Tunai (Cash)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Belanja: Rp $total',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  TextField(
                    controller: receivedC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Uang Diterima (Received)',
                      prefixText: 'Rp ',
                    ),
                    onChanged:
                        (value) => setState(
                          () {},
                        ), // Call setState to trigger recalculation
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kembali (Change): Rp ${change.toString()}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: change >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed:
                      canPrint
                          ? () {
                            Navigator.pop(context);
                            // CALL THE NEW METHOD and pass the calculated change
                            _confirmPaymentWithChange('Cash', change: change);
                          }
                          : null,
                  child: const Text('Print Receipt'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // The initial checkout button that shows the payment selection modal
  void _showPaymentSelection() {
    if (cart.isEmpty) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            title: Center(
              child: Column(
                children: const [
                  Text(
                    "Receipt",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "POS 🛒",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ========= TOTAL =============
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Rp $total",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(thickness: 1),

                const SizedBox(height: 10),
                const Text(
                  "Payment Method",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),

                // ================= Payment Buttons =================
                Row(
                  children: [
                    _paymentSquareButton(
                      label: "QRIS",
                      icon: Icons.qr_code,
                      onTap: () {
                        Navigator.pop(context);
                        _checkoutQRIS();
                      },
                    ),
                    const SizedBox(width: 8),
                    _paymentSquareButton(
                      label: "Cash",
                      icon: Icons.money,
                      onTap: () {
                        Navigator.pop(context);
                        _checkoutCash();
                      },
                    ),
                    const SizedBox(width: 8),
                    _paymentSquareButton(
                      label: "Card",
                      icon: Icons.credit_card,
                      onTap: () {
                        Navigator.pop(context);
                        _checkoutCard();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _paymentSquareButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashier'),
        centerTitle: true, // Center the title for a cleaner look
        actions: [
          // THE HISTORY ICON
          IconButton(
            icon: const Icon(Icons.history), // The clock/history icon
            onPressed: _showTransactionHistory, // Call the history function
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logOut, // Call the log out function
            tooltip: 'Log Out',
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        // The original layout Row with the two Expanded children (Product Grid and Cart)
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT: Inventory Grid (Flex 2)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // 1. Category Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 8.0,
                    ),
                    child: SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (_, i) {
                          final category = categories[i];
                          final isSelected = category == _selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedCategory = category);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 2. Product Grid
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: inv.listenable(),
                      builder: (_, box, __) {
                        final allItems = inv.values.cast<Map>().toList();
                        final filteredItems =
                            _selectedCategory == 'ALL'
                                ? allItems
                                : allItems
                                    .where(
                                      (item) =>
                                          item['category'] == _selectedCategory,
                                    )
                                    .toList();

                        if (filteredItems.isEmpty) {
                          return Center(
                            child: Text(
                              'Tidak ada barang di kategori "$_selectedCategory".',
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8.0,
                                mainAxisSpacing: 8.0,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: filteredItems.length,
                          itemBuilder: (_, i) {
                            final item = filteredItems[i];
                            final isOutOfStock = item['stock'] <= 0;

                            return Card(
                              child: InkWell(
                                onTap:
                                    isOutOfStock
                                        ? null
                                        : () => _addToCart(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child:
                                              item['imagePath'] != null
                                                  ? Image.asset(
                                                    'assets/images/${item['imagePath']}',
                                                    fit: BoxFit.cover,
                                                  )
                                                  : const Icon(
                                                    Icons.image_not_supported,
                                                    size: 40,
                                                  ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Rp ${item['price']}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        'Stok: ${item['stock']}',
                                        style: TextStyle(
                                          color:
                                              isOutOfStock
                                                  ? Colors.red
                                                  : Colors.grey,
                                        ),
                                      ),
                                      if (!isOutOfStock)
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.add_circle,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () => _addToCart(item),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            const VerticalDivider(width: 1),

            // RIGHT: Cart (Flex 1)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Cart List
                    Expanded(
                      child:
                          cart.isEmpty
                              ? const Center(child: Text('Keranjang kosong.'))
                              : ListView.builder(
                                itemCount: cart.length,
                                itemBuilder: (_, i) {
                                  final c = cart[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text('Rp ${c['price']}'),
                                            ],
                                          ),
                                        ),

                                        // Quantity Controls
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove,
                                                size: 18,
                                              ),
                                              onPressed:
                                                  () => _updateCartQuantity(
                                                    i,
                                                    -1,
                                                  ),
                                            ),
                                            Text(
                                              '${c['qty']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add,
                                                size: 18,
                                              ),
                                              onPressed:
                                                  () =>
                                                      _updateCartQuantity(i, 1),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                size: 18,
                                                color: Colors.red,
                                              ),
                                              onPressed:
                                                  () => _removeItemFromCart(i),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                    const Divider(),
                    // Total and Checkout Button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rp $total',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white, // <=== tambahkan ini
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: cart.isEmpty ? null : _showPaymentSelection,
                        child: const Text('Check Out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
