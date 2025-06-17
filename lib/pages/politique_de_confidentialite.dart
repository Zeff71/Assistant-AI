import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

class PolitiqueConfidentialitePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Politique de Confidentialité")),
      body: FutureBuilder(
        future: rootBundle.loadString(
          'assets/politique_confidentialite_SAE_Assistant.md',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Markdown(data: snapshot.data ?? '');
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
