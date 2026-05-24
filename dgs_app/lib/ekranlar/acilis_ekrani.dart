import 'package:flutter/material.dart';
import 'package:dgs_app/bilesenler/matematik_arka_plan_animasyonu.dart';
import 'package:dgs_app/ekranlar/ana/ana_ekran.dart';
import 'package:dgs_app/ekranlar/kimlik/giris_ekrani.dart';
import 'package:dgs_app/servisler/api_servisi.dart';

class AcilisEkrani extends StatefulWidget {
  const AcilisEkrani({super.key});

  @override
  State<AcilisEkrani> createState() => _AcilisEkraniDurumu();
}

class _AcilisEkraniDurumu extends State<AcilisEkrani>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Future<bool> _oturumGecerliMi;

  // Colors matching openingscreen.html
  static const Color _bg = Color(0xFFF8F9FF);
  static const Color _primary = Color(0xFF002045);
  static const Color _secondary = Color(0xFF138BED);
  static const Color _surfaceContainer = Color(0xFFE5EEFF);
  static const Color _onSurfaceVariant = Color(0xFF43474E);

  @override
  void initState() {
    super.initState();
    _oturumGecerliMi = ApiServisi().oturumuDogrula();
    // 3 saniyelik yükleme animasyonu
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut, // Daha pürüzsüz dolma
      ),
    );

    _animationController.forward();

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _sonrakiEkranaGec();
      }
    });
  }

  Future<void> _sonrakiEkranaGec() async {
    final oturumGecerliMi = await _oturumGecerliMi;
    if (oturumGecerliMi) {
      await ApiServisi().tamEsitle();
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            oturumGecerliMi ? const AnaEkran() : const GirisEkrani(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const MatematikArkaPlanAnimasyonu(),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container
                Tooltip(
                  message: 'DGS Matematik uygulama logosu.',
                  triggerMode: TooltipTriggerMode.longPress,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFFC4C6CF).withAlpha(76),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Image.asset('logo.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Tooltip(
                  message: 'Uygulamanın ana çalışma alanı.',
                  triggerMode: TooltipTriggerMode.longPress,
                  child: Text(
                    'DGS MATEMATİK',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: _primary,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ),
                const Text(
                  'SORU BANKASI',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                    fontFamily: 'Manrope',
                  ),
                ),
              ],
            ),
          ),

          // Footer (Yükleme Çubuğu ve Made by)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animasyonlu Yükleme Çubuğu
                  Tooltip(
                    message: 'Yükleme tamamlanınca giriş ekranı açılır.',
                    triggerMode: TooltipTriggerMode.longPress,
                    child: SizedBox(
                      width: 200,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _animation.value,
                              backgroundColor: _surfaceContainer,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                _secondary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Made by ISOMAIL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: _onSurfaceVariant.withAlpha(128),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
