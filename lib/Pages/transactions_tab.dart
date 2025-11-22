import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'ReceiptPage.dart';

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({Key? key}) : super(key: key);

  @override
  _TransactionsTabState createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  late Box txBox;

  @override
  void initState() {
    super.initState();
    txBox = Hive.box('transactions');
  }

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
