import 'package:flutter/material.dart';
class CustomerLedgerScreen extends StatefulWidget{
  const CustomerLedgerScreen({super.key});
  @override
  State<CustomerLedgerScreen> createState()=> _CustomerLedgerScreen();
}

class _CustomerLedgerScreen extends State<CustomerLedgerScreen>{
  @override
  Widget build (BuildContext context){
    return Scaffold(
      body:Center(child: const Text("Customer Ledger Screen"),)
    );
  }
}