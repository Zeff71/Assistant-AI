import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 51, 142, 165),
      body: SingleChildScrollView(
        child: Stack(children: [Image.asset('assets/images/lol.jpg')]),
      ), //permet de scroller
    );
  }
}
