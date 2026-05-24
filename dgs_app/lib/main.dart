import 'package:flutter/material.dart';
import 'package:dgs_app/tema/uygulama_temasi.dart';
import 'package:dgs_app/ekranlar/kimlik/giris_ekrani.dart';
import 'package:dgs_app/ekranlar/ana/ana_ekran.dart';
import 'package:dgs_app/ekranlar/acilis_ekrani.dart';

void main() {
  runApp(const DgsUygulamasi());
}

class DgsUygulamasi extends StatelessWidget {
  const DgsUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DGS Soru Bankası',
      debugShowCheckedModeBanner: false,
      theme: UygulamaTemasi.acikTema,
      home: const AcilisEkrani(),
      routes: {
        '/login': (context) => const GirisEkrani(),
        '/home': (context) => const AnaEkran(),
      },
    );
  }
}
