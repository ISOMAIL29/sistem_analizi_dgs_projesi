import 'package:flutter/material.dart';

import 'package:dgs_app/bilesenler/matematik_arka_plan_animasyonu.dart';
import 'package:dgs_app/servisler/api_servisi.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniDurumu();
}

class _GirisEkraniDurumu extends State<GirisEkrani> {
  final _emailKontrolcusu = TextEditingController();
  final _sifreKontrolcusu = TextEditingController();
  bool _islemSuruyor = false;

  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _title = Color(0xFF1E3A8A);
  static const Color _muted = Color(0xFF64748B);

  Future<void> _handleLogin() async {
    final email = _emailKontrolcusu.text.trim();
    final sifre = _sifreKontrolcusu.text;

    if (email.isEmpty || sifre.isEmpty) {
      await _showAuthDialog(context, 'E-posta ve şifre alanları zorunludur.');
      return;
    }

    if (!_gecerliEmailMi(email)) {
      await _showAuthDialog(context, 'Geçerli bir e-posta adresi girin.');
      return;
    }

    setState(() => _islemSuruyor = true);
    final isValid = await ApiServisi().girisYap(eposta: email, sifre: sifre);
    if (isValid) {
      await ApiServisi().tamEsitle();
    }

    if (!mounted) return;
    setState(() => _islemSuruyor = false);

    if (isValid) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      await _showAuthDialog(context, 'E-posta veya şifre yanlış.');
    }
  }

  @override
  void dispose() {
    _emailKontrolcusu.dispose();
    _sifreKontrolcusu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const MatematikArkaPlanAnimasyonu(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hoş Geldiniz',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: _title,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'DGS yolculuğuna başlamak için giriş yapın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 15),
                      ),
                      const SizedBox(height: 28),
                      _AuthCard(
                        child: Column(
                          children: [
                            Tooltip(
                              message: 'Kayıtlı e-posta adresinizi yazın.',
                              triggerMode: TooltipTriggerMode.longPress,
                              child: TextField(
                                controller: _emailKontrolcusu,
                                decoration: const InputDecoration(
                                  labelText: 'E-posta',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Tooltip(
                              message: 'Hesabınıza ait şifreyi yazın.',
                              triggerMode: TooltipTriggerMode.longPress,
                              child: TextField(
                                controller: _sifreKontrolcusu,
                                decoration: const InputDecoration(
                                  labelText: 'Şifre',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                obscureText: true,
                                onSubmitted: (_) => _handleLogin(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Tooltip(
                                message: 'Şifre sıfırlama ekranını açar.',
                                triggerMode: TooltipTriggerMode.longPress,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SifremiUnuttumEkrani(),
                                      ),
                                    );
                                  },
                                  child: const Text('Şifremi Unuttum'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Tooltip(
                              message: 'Bilgiler doğruysa ana ekrana geçer.',
                              triggerMode: TooltipTriggerMode.longPress,
                              child: ElevatedButton.icon(
                                onPressed: _islemSuruyor ? null : _handleLogin,
                                style: _primaryButtonStyle(),
                                icon: _islemSuruyor
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: const Text('Giriş Yap'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Hesabınız yok mu?',
                            style: TextStyle(color: _muted),
                          ),
                          Tooltip(
                            message: 'Yeni hesap oluşturma ekranını açar.',
                            triggerMode: TooltipTriggerMode.longPress,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const KayitEkrani(),
                                  ),
                                );
                              },
                              child: const Text('Kayıt Ol'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});

  @override
  State<KayitEkrani> createState() => _KayitEkraniDurumu();
}

class _KayitEkraniDurumu extends State<KayitEkrani> {
  final _usernameKontrolcusu = TextEditingController();
  final _emailKontrolcusu = TextEditingController();
  final _sifreKontrolcusu = TextEditingController();
  final _sifreTekrarKontrolcusu = TextEditingController();
  bool _islemSuruyor = false;

  Future<void> _handleRegister() async {
    final username = _usernameKontrolcusu.text.trim();
    final email = _emailKontrolcusu.text.trim();
    final sifre = _sifreKontrolcusu.text;
    final sifreTekrar = _sifreTekrarKontrolcusu.text;

    if (username.isEmpty ||
        email.isEmpty ||
        sifre.isEmpty ||
        sifreTekrar.isEmpty) {
      await _showAuthDialog(
        context,
        'Kullanıcı adı, e-posta, şifre ve şifre tekrar alanları zorunludur.',
      );
      return;
    }

    if (username.length < 3) {
      await _showAuthDialog(
        context,
        'Kullanıcı adı en az 3 karakter olmalıdır.',
      );
      return;
    }

    if (!_gecerliEmailMi(email)) {
      await _showAuthDialog(
        context,
        'E-posta adresi geçerli bir şablona uymalıdır.',
      );
      return;
    }

    final sifreUyarisi = _sifreUyarisi(sifre);
    if (sifreUyarisi != null) {
      await _showAuthDialog(context, sifreUyarisi);
      return;
    }

    if (sifre != sifreTekrar) {
      await _showAuthDialog(
        context,
        'Şifre ve şifre tekrar alanları eşleşmiyor.',
      );
      return;
    }

    setState(() => _islemSuruyor = true);
    final kayitBasarili = await ApiServisi().kayitOl(
      ad: username,
      eposta: email,
      sifre: sifre,
    );

    if (!mounted) return;
    setState(() => _islemSuruyor = false);

    if (kayitBasarili) {
      await _showAuthDialog(
        context,
        'Hesap oluşturuldu. Giriş yapabilirsiniz.',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      await _showAuthDialog(context, 'Kayıt oluşturulamadı.');
    }
  }

  @override
  void dispose() {
    _usernameKontrolcusu.dispose();
    _emailKontrolcusu.dispose();
    _sifreKontrolcusu.dispose();
    _sifreTekrarKontrolcusu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Kayıt Ol',
      subtitle: 'Çalışma takibini başlatmak için hesabınızı oluşturun.',
      child: Column(
        children: [
          Tooltip(
            message: 'En az 3 karakterlik kullanıcı adınızı yazın.',
            triggerMode: TooltipTriggerMode.longPress,
            child: TextField(
              controller: _usernameKontrolcusu,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı Adı',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 16),
          Tooltip(
            message: 'Geçerli bir e-posta adresi girin.',
            triggerMode: TooltipTriggerMode.longPress,
            child: TextField(
              controller: _emailKontrolcusu,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 16),
          Tooltip(
            message:
                'En az 8 karakter, büyük/küçük harf, rakam ve özel karakter kullanın.',
            triggerMode: TooltipTriggerMode.longPress,
            child: TextField(
              controller: _sifreKontrolcusu,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 16),
          Tooltip(
            message: 'Şifrenizi aynı şekilde tekrar yazın.',
            triggerMode: TooltipTriggerMode.longPress,
            child: TextField(
              controller: _sifreTekrarKontrolcusu,
              decoration: const InputDecoration(
                labelText: 'Şifre Tekrar',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
              obscureText: true,
              onSubmitted: (_) => _handleRegister(),
            ),
          ),
          const SizedBox(height: 24),
          Tooltip(
            message: 'Bilgileri kontrol edip hesabınızı oluşturur.',
            triggerMode: TooltipTriggerMode.longPress,
            child: ElevatedButton.icon(
              onPressed: _islemSuruyor ? null : _handleRegister,
              style: _primaryButtonStyle(),
              icon: _islemSuruyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Hesap Oluştur'),
            ),
          ),
        ],
      ),
    );
  }
}

class SifremiUnuttumEkrani extends StatefulWidget {
  const SifremiUnuttumEkrani({super.key});

  @override
  State<SifremiUnuttumEkrani> createState() => _SifremiUnuttumEkraniDurumu();
}

class _SifremiUnuttumEkraniDurumu extends State<SifremiUnuttumEkrani> {
  final _emailKontrolcusu = TextEditingController();

  Future<void> _handleReset() async {
    final email = _emailKontrolcusu.text.trim();

    if (email.isEmpty) {
      await _showAuthDialog(context, 'E-posta alanı zorunludur.');
      return;
    }

    if (!_gecerliEmailMi(email)) {
      await _showAuthDialog(context, 'Geçerli bir e-posta adresi girin.');
      return;
    }

    await _showAuthDialog(
      context,
      '$email adresine şifre sıfırlama bağlantısı gönderildi.',
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _emailKontrolcusu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Şifremi Unuttum',
      subtitle: 'E-postanızı girin, şifre yenileme adımlarını gönderelim.',
      child: Column(
        children: [
          Tooltip(
            message: 'Şifre sıfırlama bağlantısı için e-postanızı yazın.',
            triggerMode: TooltipTriggerMode.longPress,
            child: TextField(
              controller: _emailKontrolcusu,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _handleReset(),
            ),
          ),
          const SizedBox(height: 24),
          Tooltip(
            message: 'Şifre sıfırlama bağlantısını gönderir.',
            triggerMode: TooltipTriggerMode.longPress,
            child: ElevatedButton.icon(
              onPressed: _handleReset,
              style: _primaryButtonStyle(),
              icon: const Icon(Icons.mark_email_read_outlined),
              label: const Text('Bağlantı Gönder'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _title = Color(0xFF1E3A8A);
  static const Color _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, elevation: 0),
      body: Stack(
        children: [
          const MatematikArkaPlanAnimasyonu(),
          SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: _title,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      _AuthCard(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDFE8F3)),
        boxShadow: [
          const BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

ButtonStyle _primaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF1D4ED8),
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

bool _gecerliEmailMi(String email) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
}

String? _sifreUyarisi(String sifre) {
  if (sifre.length < 8) {
    return 'Şifre en az 8 karakter olmalıdır.';
  }
  if (!RegExp(r'[A-Z]').hasMatch(sifre)) {
    return 'Şifre en az bir büyük harf içermelidir.';
  }
  if (!RegExp(r'[a-z]').hasMatch(sifre)) {
    return 'Şifre en az bir küçük harf içermelidir.';
  }
  if (!RegExp(r'\d').hasMatch(sifre)) {
    return 'Şifre en az bir rakam içermelidir.';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];]').hasMatch(sifre)) {
    return 'Şifre en az bir özel karakter içermelidir.';
  }
  return null;
}

Future<void> _showAuthDialog(BuildContext context, String message) {
  final dialogWidth = MediaQuery.sizeOf(context).width * 0.5;

  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: dialogWidth,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
