
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

import '../controllers/profit_report_controller.dart';

class ProfitScreen extends StatelessWidget {
  const ProfitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ProfitReportController>();

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
          'Profit • ${ctrl.selectedDate.value.toIso8601String().substring(0,10)}',
        )),
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.error.value != null) {
          return Center(child: Text(ctrl.error.value!));
        }
        return ListView.builder(
          itemCount: ctrl.itemSummaries.length,
          itemBuilder: (_, i) {
            final p = ctrl.itemSummaries[i];
            return ListTile(
              title   : Text(p.itemName),
              subtitle: Text(p.packing),
              trailing: Text('₹${p.totalProfit.toStringAsFixed(2)}'),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: ctrl.selectedDate.value,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) ctrl.setDate(picked);
        },
        child: const Icon(Icons.calendar_today),
      ),
    );
  }
}
