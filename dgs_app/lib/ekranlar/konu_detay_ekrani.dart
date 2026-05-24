import 'package:flutter/material.dart';

class KonuDetayEkrani extends StatelessWidget {
  final String konuAdi;

  const KonuDetayEkrani({super.key, required this.konuAdi});

  static const String _placeholderText =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer '
      'facilisis, sem non luctus eleifend, massa tortor gravida risus, vitae '
      'aliquet ipsum mi sed neque. Donec sed augue sed lorem porttitor '
      'vulputate. Praesent at arcu vitae nibh tempor cursus. Sed non erat '
      'lectus. Nulla facilisi. Morbi vitae justo in risus bibendum posuere.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(konuAdi)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            _placeholderText,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 50,
              height: 120,
              color: const Color(0xFFD1D5DB),
            ),
          ),
        ],
      ),
    );
  }
}
