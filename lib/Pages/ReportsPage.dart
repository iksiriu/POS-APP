import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // Add to pubspec.yaml: intl: ^0.18.1

import 'DailyTransactionsPage.dart'; // We'll create this next

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Reference the transaction box
    final transactionBox = Hive.box('transactions');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Reports'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: transactionBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('No transactions recorded yet.'));
          }

          // 1. Group transactions by date
          Map<String, List<Map>> dailyReports = {};
          for (var txn in box.values.cast<Map>()) {
            final dateKey = txn['date'] as String;
            if (!dailyReports.containsKey(dateKey)) {
              dailyReports[dateKey] = [];
            }
            dailyReports[dateKey]!.add(txn);
          }

          // Convert to a sortable list of daily summaries
          List<String> sortedDates =
              dailyReports.keys.toList()..sort((a, b) {
                // Assuming date format DD/MM/YYYY for sorting
                final dateA = DateFormat('dd/MM/yyyy').parse(a);
                final dateB = DateFormat('dd/MM/yyyy').parse(b);
                return dateB.compareTo(dateA); // Newest first
              });

          return ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final transactions = dailyReports[date]!;
              final totalIncome = transactions.fold<int>(
                0,
                (sum, txn) => sum + (txn['total'] as int),
              );

              // Use the first transaction to get the day name for the heading
              final dayName = transactions.first['dayOfWeek'] ?? '';

              return InkWell(
                onTap: () {
                  // Navigate to Level 2: DailyTransactionsPage
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => DailyTransactionsPage(
                            date: date,
                            transactions: transactions,
                            dayName: dayName,
                          ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  margin: const EdgeInsets.only(bottom: 1.0), // Divider style
                  color: index.isOdd ? Colors.grey.shade100 : Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // LEFT: Day and Summary
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$dayName Transaction $date',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Transaction: ${transactions.length}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Income: RP ${NumberFormat('#,##0').format(totalIncome)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      // RIGHT: Placeholder for details (as per original image 3309e0.png, but we'll show details on the next screen)
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
