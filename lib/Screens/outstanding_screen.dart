import 'package:flutter/material.dart';
class OutStandingScreen extends StatefulWidget{
  const OutStandingScreen({super.key});
  @override
  State<OutStandingScreen> createState()=> _OutStandingScreen();
}

class _OutStandingScreen extends State<OutStandingScreen>{
  @override
  Widget build (BuildContext context){
    return Scaffold(
        body:Center(child: const Text("OutStanding Screen"),)
    );
  }
}