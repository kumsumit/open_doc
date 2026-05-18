import 'package:flutter/material.dart';

import 'src/studio/document_studio.dart';

class OpenDocApp extends StatelessWidget {
  const OpenDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff2563eb);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Open Doc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff4f7fb),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const DocumentStudio(),
    );
  }
}
