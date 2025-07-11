import 'package:flutter/material.dart';
class SupplierLedgerScreen extends StatefulWidget{
  const SupplierLedgerScreen({super.key});
  @override
  State<SupplierLedgerScreen> createState()=> _SupplierLedgerScreen();
}

class _SupplierLedgerScreen extends State<SupplierLedgerScreen>{
  @override
  Widget build (BuildContext context){
    return Scaffold(
        body:Center(child: const Text("SupplierLedgerScreen"),)
    );
  }
}