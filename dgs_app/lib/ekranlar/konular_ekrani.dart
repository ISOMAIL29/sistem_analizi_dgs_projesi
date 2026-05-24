import 'package:dgs_app/veri/konu_verileri.dart';
import 'package:dgs_app/ekranlar/konu_detay_ekrani.dart';
import 'package:flutter/material.dart';

class KonularEkrani extends StatelessWidget {
  const KonularEkrani({super.key});

  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _primary = Color(0xFF1E3A8A);
  static const Color _mint = Color(0xFFDDEBFF);

  static final List<String> _konular = List.unmodifiable(kKonular);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Matematik Yol Haritası'),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _konular.length,
        itemBuilder: (context, index) {
          final konu = _konular[index];

          return SizedBox(
            height: 102,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KonuDetayEkrani(konuAdi: konu),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _mint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_stories_outlined,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          konu,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
