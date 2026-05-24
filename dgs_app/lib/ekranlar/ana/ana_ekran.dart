import 'package:flutter/material.dart';
import 'package:dgs_app/tema/uygulama_temasi.dart';
import 'package:dgs_app/ekranlar/sorular_ekrani.dart';
import 'package:dgs_app/ekranlar/denemeler_ekrani.dart';
import 'package:dgs_app/ekranlar/hesap_ekrani.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranDurumu();
}

class _AnaEkranDurumu extends State<AnaEkran> {
  int _seciliIndeks = 0;

  final List<Widget> _ekranlar = [
    const SorularEkrani(),
    const DenemelerEkrani(),
    const HesapEkrani(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _ekranlar[_seciliIndeks],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _seciliIndeks,
            onDestinationSelected: (index) =>
                setState(() => _seciliIndeks = index),
            backgroundColor: Colors.white,
            indicatorColor: UygulamaTemasi.acikMavi,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.help_outline),
                selectedIcon: Icon(Icons.help),
                label: 'Sorular',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: 'Denemeler',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Hesap',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
