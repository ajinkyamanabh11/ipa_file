import 'package:flutter/material.dart';
class ProfitScreen extends StatefulWidget{
  const ProfitScreen({super.key});
  @override
  State<ProfitScreen> createState()=> _ProfitScreen();
}

class _ProfitScreen extends State<ProfitScreen>{
  @override
  Widget build (BuildContext context){
    return Scaffold(
        body:Center(child: const Text("Profit Screen"))
    );
  }
}