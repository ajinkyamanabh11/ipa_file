import 'package:flutter/material.dart';
class TransactionScreen extends StatefulWidget{
  const TransactionScreen({super.key});
  @override
  State<TransactionScreen> createState()=> _TransactionScreen();
}

class _TransactionScreen extends State<TransactionScreen>{
  @override
  Widget build (BuildContext context){
    return Scaffold(
        body:Center(child: const Text("TransactionScreen"),)
    );
  }
}