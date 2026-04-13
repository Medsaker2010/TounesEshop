// ═══════════════════════════════════════════════════════════════
// TOUNESBET - APPLICATION DE PARIS SPORTIFS LUXE
// Version: 1.0.1 (corrigé)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class Config {
  static const String googleClientId   = 'VOTRE_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  static const String flouciApiKey     = 'VOTRE_FLOUCI_API_KEY';
  static const String flouciAppSecret  = 'VOTRE_FLOUCI_APP_SECRET';
  static const String flouciBaseUrl    = 'https://developers.flouci.com/api';
  static const String d17MerchantId    = 'VOTRE_D17_MERCHANT_ID';
  static const String d17BaseUrl       = 'https://www.d17.com.tn/api';
  static const String usdtTrc20Address = 'VOTRE_ADRESSE_USDT_TRC20';
  static const String bitcoinAddress   = 'VOTRE_ADRESSE_BITCOIN';
  static const String ethAddress       = 'VOTRE_ADRESSE_ETH';
  static const String wsOddsUrl        = 'wss://api.tounesbet.com/odds/live';
  static const String apiBaseUrl       = 'https://api.tounesbet.com/v1';
}

class AppColors {
  static const Color gold       = Color(0xFFD4AF37);
  static const Color goldLight  = Color(0xFFF9F295);
  static const Color goldDark   = Color(0xFFB8860B);
  static const Color black      = Color(0xFF000000);
  static const Color darkBg     = Color(0xFF0A0A0A);
  static const Color cardBg     = Color(0xFF111111);
  static const Color cardBorder = Color(0xFF1A1A1A);
  static const Color white      = Color(0xFFFFFFFF);
  static const Color grey       = Color(0xFF888888);
  static const Color success    = Color(0xFF00C853);
  static const Color danger     = Color(0xFFD50000);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFE066), Color(0xFFD4AF37), Color(0xFFB8860B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1500), Color(0xFF0A0A0A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class Match {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String time;
  double oddsHome;
  double oddsDraw;
  double oddsAway;
  bool isLive;

  Match({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.time,
    required this.oddsHome,
    required this.oddsDraw,
    required this.oddsAway,
    this.isLive = false,
  });
}

class BetSlip {
  final String matchId;
  final String matchName;
  final String selection;
  final double odds;
  double stake;

  BetSlip({
    required this.matchId,
    required this.matchName,
    required this.selection,
    required this.odds,
    this.stake = 10.0,
  });

  double get potentialWin => stake * odds;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0A),
  ));
  await Firebase.initializeApp();
  runApp(const TounesBetApp());
}

class TounesBetApp extends StatelessWidget {
  const TounesBetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TounesBet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        fontFamily: 'Poppins',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          secondary: AppColors.goldLight,
          background: AppColors.darkBg,
          surface: AppColors.cardBg,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class _Particle {
  late double x, y, radius, opacity, speedX, speedY;
  _Particle(int seed) {
    final r = Random(seed);
    x = r.nextDouble();
    y = r.nextDouble();
    radius = r.nextDouble() * 2 + 0.5;
    opacity = r.nextDouble() * 0.5 + 0.1;
    speedX = (r.nextDouble() - 0.5) * 0.2;
    speedY = r.nextDouble() * 0.3 + 0.05;
  }
}

class ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  ParticlePainter(this.progress) : particles = List.generate(80, (i) => _Particle(i));

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = AppColors.gold.withOpacity(p.opacity * progress)
        ..style = PaintingStyle.fill;
      final x = (p.x * size.width + progress * p.speedX * size.width) % size.width;
      final y = (p.y * size.height - progress * p.speedY * size.height) % size.height;
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) => true;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _particleCtrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _logoCtrl    = AnimationController(duration: const Duration(milliseconds: 2500), vsync: this);
    _particleCtrl = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
    _scale   = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _glow    = Tween<double>(begin: 0.0, end: 40.0).animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeInOut)));
    _logoCtrl.forward();
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ));
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(children: [
        AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) => CustomPaint(painter: ParticlePainter(_particleCtrl.value), size: Size.infinite),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _logoCtrl,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2),
                      boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.5), blurRadius: _glow.value, spreadRadius: _glow.value / 4)],
                    ),
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                        child: const Text('TB', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                    child: const Text('TOUNESBET', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 8)),
                  ),
                  const SizedBox(height: 8),
                  const Text('PARIS SPORTIFS DE LUXE', style: TextStyle(color: AppColors.grey, fontSize: 11, letterSpacing: 5, fontWeight: FontWeight.w300)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth        = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(clientId: Config.googleClientId);
  final LocalAuthentication _localAuth = LocalAuthentication();
  late AnimationController _cardCtrl;
  late Animation<Offset> _cardSlide;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cardCtrl  = AnimationController(duration: const Duration(milliseconds: 900), vsync: this);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardCtrl.forward();
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    super.dispose();
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256(String input) {
    final bytes  = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _googleAuth() async {
    try {
      HapticFeedback.lightImpact();
      setState(() => _isLoading = true);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      HapticFeedback.heavyImpact();
      if (mounted) _goHome();
    } catch (e) {
      _showError('Erreur Google: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _appleAuth() async {
    try {
      HapticFeedback.lightImpact();
      setState(() => _isLoading = true);
      final rawNonce = _generateNonce();
      final nonce    = _sha256(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      await _auth.signInWithCredential(oauthCredential);
      HapticFeedback.heavyImpact();
      if (mounted) _goHome();
    } catch (e) {
      _showError('Erreur Apple: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FIX #1 : ligne dupliquée/cassée sur AuthenticationOptions corrigée
  Future<void> _biometricAuth() async {
    try {
      HapticFeedback.mediumImpact();
      setState(() => _isLoading = true);
      final bool canAuth = await _localAuth.canCheckBiometrics;
      if (!canAuth) { _showError('Biométrie non disponible'); return; }
      final bool auth = await _localAuth.authenticate(
        localizedReason: 'Confirmez votre identité TounesBet',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (auth && mounted) {
        HapticFeedback.heavyImpact();
        _goHome();
      }
    } catch (e) {
      _showError('Erreur biométrie: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goHome() {
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.cardBg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: AppColors.darkGradient)),
        SafeArea(
          child: Column(children: [
            const SizedBox(height: 60),
            ShaderMask(
              shaderCallback: (b) => AppColors.goldGradient.createShader(b),
              child: const Text('TOUNESBET', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 6)),
            ),
            const SizedBox(height: 6),
            const Text('PARIS SPORTIFS DE LUXE', style: TextStyle(color: AppColors.grey, fontSize: 10, letterSpacing: 5, fontWeight: FontWeight.w300)),
            const Spacer(),
            SlideTransition(
              position: _cardSlide,
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.1), blurRadius: 30, spreadRadius: 5)],
                ),
                child: Column(children: [
                  const Text('CONNEXION SÉCURISÉE', style: TextStyle(color: AppColors.gold, fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Authentification niveau bancaire', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                  const SizedBox(height: 28),
                  _GoldButton(onTap: _isLoading ? null : _biometricAuth, icon: Icons.fingerprint, label: 'FACE ID / TOUCH ID', isGold: true),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('ou continuer avec', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                  ]),
                  const SizedBox(height: 14),
                  _GoldButton(onTap: _isLoading ? null : _googleAuth, icon: Icons.g_mobiledata_rounded, label: 'CONTINUER AVEC GOOGLE', isGold: false),
                  const SizedBox(height: 12),
                  _GoldButton(onTap: _isLoading ? null : _appleAuth, icon: Icons.apple, label: 'CONTINUER AVEC APPLE', isGold: false),
                  const SizedBox(height: 20),
                  if (_isLoading) const CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                  const SizedBox(height: 10),
                  const Text('En vous connectant, vous acceptez nos CGU.\nJeu responsable +18.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.grey, fontSize: 10, height: 1.5)),
                ]),
              ),
            ),
            const SizedBox(height: 30),
          ]),
        ),
      ]),
    );
  }
}

class _GoldButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final bool isGold;

  const _GoldButton({required this.onTap, required this.icon, required this.label, required this.isGold});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isGold ? AppColors.goldGradient : null,
          color: isGold ? null : AppColors.cardBorder,
          borderRadius: BorderRadius.circular(15),
          border: isGold ? null : Border.all(color: AppColors.gold.withOpacity(0.2)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: isGold ? Colors.black : AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(
            color: isGold ? Colors.black : AppColors.white,
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabCtrl;
  late WebSocketChannel _wsChannel;
  Timer? _oddsTimer;
  List<BetSlip> _betSlips = [];
  double _balance = 1250.00;
  bool _showBetSlip = false;

  final List<Match> _matches = [
    Match(id:'1', homeTeam:'PSG',       awayTeam:'Real Madrid',  league:'Champions League', time:'21:00', oddsHome:2.10, oddsDraw:3.40, oddsAway:3.20, isLive:true),
    Match(id:'2', homeTeam:'Barcelona', awayTeam:'Bayern Munich', league:'Champions League', time:'21:00', oddsHome:1.95, oddsDraw:3.60, oddsAway:3.80),
    Match(id:'3', homeTeam:'Man City',  awayTeam:'Liverpool',     league:'Premier League',   time:'18:30', oddsHome:2.30, oddsDraw:3.20, oddsAway:2.90),
    Match(id:'4', homeTeam:'Juventus',  awayTeam:'Inter Milan',   league:'Serie A',          time:'20:45', oddsHome:2.50, oddsDraw:3.10, oddsAway:2.70),
    Match(id:'5', homeTeam:'Espérance', awayTeam:'Club Africain', league:'Ligue 1 TN',       time:'16:00', oddsHome:1.80, oddsDraw:3.50, oddsAway:4.20, isLive:true),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _connectWebSocket();
    _simulateOddsUpdates();
  }

  void _connectWebSocket() {
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(Config.wsOddsUrl));
      _wsChannel.stream.listen((data) {
        final json = jsonDecode(data);
        if (!mounted) return;
        setState(() {
          final idx = _matches.indexWhere((m) => m.id == json['match_id']);
          if (idx != -1) {
            _matches[idx].oddsHome = (json['odds_home'] as num).toDouble();
            _matches[idx].oddsDraw = (json['odds_draw'] as num).toDouble();
            _matches[idx].oddsAway = (json['odds_away'] as num).toDouble();
          }
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  void _simulateOddsUpdates() {
    _oddsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        final r = Random();
        for (var m in _matches) {
          if (m.isLive) {
            m.oddsHome = double.parse((m.oddsHome + (r.nextDouble() - 0.5) * 0.1).clamp(1.1, 10.0).toStringAsFixed(2));
            m.oddsDraw = double.parse((m.oddsDraw + (r.nextDouble() - 0.5) * 0.05).clamp(1.1, 10.0).toStringAsFixed(2));
            m.oddsAway = double.parse((m.oddsAway + (r.nextDouble() - 0.5) * 0.1).clamp(1.1, 10.0).toStringAsFixed(2));
          }
        }
      });
    });
  }

  void _addToBetSlip(Match match, String selection, double odds) {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_betSlips.any((b) => b.matchId == match.id)) {
        _betSlips.add(BetSlip(
          matchId: match.id,
          matchName: '${match.homeTeam} vs ${match.awayTeam}',
          selection: selection,
          odds: odds,
        ));
        _showBetSlip = true;
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _wsChannel.sink.close();
    _oddsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(children: [
        CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 130,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.darkBg,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.darkGradient),
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Bienvenue 👑', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                      ShaderMask(
                        shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                        child: const Text('TOUNESBET', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4)),
                      ),
                    ]),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 10)],
                        ),
                        child: Row(children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.black, size: 16),
                          const SizedBox(width: 6),
                          Text('${_balance.toStringAsFixed(2)} TND',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.gold,
              indicatorWeight: 2,
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.grey,
              labelStyle: const TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700),
              tabs: const [Tab(text: 'EN DIRECT'), Tab(text: 'À VENIR'), Tab(text: 'MES PARIS')],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _MatchCard(
                match: _matches[index],
                onBet: (selection, odds) => _addToBetSlip(_matches[index], selection, odds),
              ),
              childCount: _matches.length,
            ),
          ),
        ]),
        if (_showBetSlip && _betSlips.isNotEmpty)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BetSlipPanel(
              betSlips: _betSlips,
              onClose: () => setState(() => _showBetSlip = false),
              onPlaceBet: () {
                HapticFeedback.heavyImpact();
                setState(() { _betSlips.clear(); _showBetSlip = false; });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Pari placé avec succès !'), backgroundColor: AppColors.success));
              },
            ),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MATCH CARD  — FIX #2 : Row tronquée reconstruite
// ═══════════════════════════════════════════════════════════════

class _MatchCard extends StatelessWidget {
  final Match match;
  final Function(String, double) onBet;
  const _MatchCard({required this.match, required this.onBet});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: match.isLive ? AppColors.gold.withOpacity(0.5) : AppColors.cardBorder),
        boxShadow: match.isLive ? [BoxShadow(color: AppColors.gold.withOpacity(0.1), blurRadius: 15)] : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(match.league, style: const TextStyle(color: AppColors.gold, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(match.time, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
              ]),
              if (match.isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.danger.withOpacity(0.5)),
                  ),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger)),
                    const SizedBox(width: 5),
                    const Text('LIVE', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Teams row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(match.homeTeam, style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
              const Text('VS', style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w300, letterSpacing: 2)),
              Expanded(child: Text(match.awayTeam, style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
            ],
          ),
          const SizedBox(height: 14),
          // Odds row
          Row(children: [
            Expanded(child: _OddsButton(label: '1', value: match.oddsHome, onTap: () => onBet(match.homeTeam, match.oddsHome))),
            const SizedBox(width: 8),
            Expanded(child: _OddsButton(label: 'X', value: match.oddsDraw, onTap: () => onBet('Nul', match.oddsDraw))),
            const SizedBox(width: 8),
            Expanded(child: _OddsButton(label: '2', value: match.oddsAway, onTap: () => onBet(match.awayTeam, match.oddsAway))),
          ]),
        ]),
      ),
    );
  }
}

class _OddsButton extends StatelessWidget {
  final String label;
  final double value;
  final VoidCallback onTap;
  const _OddsButton({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withOpacity(0.25)),
        ),
        child: Column(children: [
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 3),
          Text(value.toStringAsFixed(2), style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BET SLIP PANEL — FIX #5 : widget manquant ajouté
// ═══════════════════════════════════════════════════════════════

class _BetSlipPanel extends StatefulWidget {
  final List<BetSlip> betSlips;
  final VoidCallback onClose;
  final VoidCallback onPlaceBet;
  const _BetSlipPanel({required this.betSlips, required this.onClose, required this.onPlaceBet});

  @override
  State<_BetSlipPanel> createState() => _BetSlipPanelState();
}

class _BetSlipPanelState extends State<_BetSlipPanel> {
  double get totalOdds => widget.betSlips.fold(1.0, (acc, b) => acc * b.odds);
  double get totalStake => widget.betSlips.fold(0.0, (acc, b) => acc + b.stake);
  double get totalWin => totalStake * totalOdds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.15), blurRadius: 30, spreadRadius: 2)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.goldGradient.createShader(b),
            child: Text('TICKET (${widget.betSlips.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          ),
          GestureDetector(onTap: widget.onClose, child: const Icon(Icons.close, color: AppColors.grey)),
        ]),
        const SizedBox(height: 12),
        ...widget.betSlips.map((b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(b.matchName, style: const TextStyle(color: AppColors.grey, fontSize: 11), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(b.selection, style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(b.odds.toStringAsFixed(2), style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        )),
        const Divider(color: AppColors.cardBorder, height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Cote totale', style: TextStyle(color: AppColors.grey, fontSize: 12)),
          Text(totalOdds.toStringAsFixed(2), style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Gain potentiel', style: TextStyle(color: AppColors.grey, fontSize: 12)),
          Text('${totalWin.toStringAsFixed(2)} TND', style: const TextStyle(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: widget.onPlaceBet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.4), blurRadius: 12)],
            ),
            child: const Text('PLACER LE PARI', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PAYMENT SCREEN — FIX #3 : classe StatefulWidget + champs ajoutés
// ═══════════════════════════════════════════════════════════════

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final TextEditingController _amountCtrl = TextEditingController();
  bool _isLoading = false;
  String _selectedCrypto = 'USDT TRC20';

  final Map<String, String> _cryptoAddresses = {
    'USDT TRC20': Config.usdtTrc20Address,
    'Bitcoin':    Config.bitcoinAddress,
    'Ethereum':   Config.ethAddress,
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchFlouci() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) { _showError('Montant invalide'); return; }
    setState(() => _isLoading = true);
    try {
      // Simulated — replace with real Flouci API call
      await Future.delayed(const Duration(seconds: 1));
      final url = Uri.parse('${Config.flouciBaseUrl}/payment?amount=${(amount * 1000).round()}&app_token=${Config.flouciApiKey}');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showError('Erreur Flouci: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchD17() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) { _showError('Montant invalide'); return; }
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(seconds: 1));
      final url = Uri.parse('${Config.d17BaseUrl}/payment?merchant=${Config.d17MerchantId}&amount=$amount');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showError('Erreur D17: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyAddress() async {
    final address = _cryptoAddresses[_selectedCrypto] ?? '';
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Adresse $_selectedCrypto copiée !', style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.gold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (b) => AppColors.goldGradient.createShader(b),
          child: const Text('DÉPÔT VIP',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4)),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.gold,
          indicatorWeight: 2,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.grey,
          labelStyle: const TextStyle(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'FLOUCI'),
            Tab(text: 'D17'),
            Tab(text: 'CRYPTO'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [

          // ─── ONGLET FLOUCI ───────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.1), blurRadius: 20)],
                ),
                child: Column(children: [
                  ShaderMask(
                    shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                    child: const Text('💳 FLOUCI', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  const Text('Paiement mobile instantané', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                  const SizedBox(height: 24),
                  _AmountField(controller: _amountCtrl),
                  const SizedBox(height: 16),
                  _QuickAmountRow(amountCtrl: _amountCtrl, onChanged: () => setState(() {})),
                  const SizedBox(height: 24),
                  _PayButton(isLoading: _isLoading, label: 'OUVRIR FLOUCI', onTap: _isLoading ? null : _launchFlouci),
                ]),
              ),
            ]),
          ),

          // ─── ONGLET D17 ──────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.1), blurRadius: 20)],
                ),
                child: Column(children: [
                  ShaderMask(
                    shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                    child: const Text('🏦 D17 e-DINAR', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  const Text('La Poste Tunisienne - Paiement sécurisé', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                  const SizedBox(height: 24),
                  _AmountField(controller: _amountCtrl),
                  const SizedBox(height: 16),
                  _QuickAmountRow(amountCtrl: _amountCtrl, onChanged: () => setState(() {})),
                  const SizedBox(height: 24),
                  _PayButton(isLoading: _isLoading, label: 'PAYER VIA D17', onTap: _isLoading ? null : _launchD17),
                ]),
              ),
            ]),
          ),

          // ─── ONGLET CRYPTO ───────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.1), blurRadius: 20)],
                ),
                child: Column(children: [
                  ShaderMask(
                    shaderCallback: (b) => AppColors.goldGradient.createShader(b),
                    child: const Text('₿ CRYPTO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  const Text('Bitcoin • USDT TRC20 • Ethereum', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _CryptoSelector(label: 'USDT', isSelected: _selectedCrypto == 'USDT TRC20', onTap: () => setState(() => _selectedCrypto = 'USDT TRC20')),
                    const SizedBox(width: 8),
                    _CryptoSelector(label: 'BTC',  isSelected: _selectedCrypto == 'Bitcoin',    onTap: () => setState(() => _selectedCrypto = 'Bitcoin')),
                    const SizedBox(width: 8),
                    _CryptoSelector(label: 'ETH',  isSelected: _selectedCrypto == 'Ethereum',   onTap: () => setState(() => _selectedCrypto = 'Ethereum')),
                  ]),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 15)],
                    ),
                    child: QrImageView(
                      data: _cryptoAddresses[_selectedCrypto] ?? '',
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFFD4AF37)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          _cryptoAddresses[_selectedCrypto] ?? '',
                          style: const TextStyle(color: AppColors.grey, fontSize: 10, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _copyAddress,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.copy, color: Colors.black, size: 16),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Envoyez uniquement le crypto sélectionné. Les fonds sont crédités après 2 confirmations blockchain.',
                          style: TextStyle(color: AppColors.grey, fontSize: 10, height: 1.5),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED PAYMENT WIDGETS (extraits pour éviter la duplication)
// ═══════════════════════════════════════════════════════════════

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  const _AmountField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Text('TND', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00', hintStyle: TextStyle(color: AppColors.grey)),
          ),
        ),
      ]),
    );
  }
}

class _QuickAmountRow extends StatelessWidget {
  final TextEditingController amountCtrl;
  final VoidCallback onChanged;
  const _QuickAmountRow({required this.amountCtrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: ['20', '50', '100', '200'].map((a) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _QuickAmount(amount: a, onTap: () { amountCtrl.text = a; onChanged(); }),
      ),
    )).toList());
  }
}

class _PayButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback? onTap;
  const _PayButton({required this.isLoading, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.4), blurRadius: 15)],
        ),
        child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : Text(label, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
    );
  }
}

// FIX #4 : "class _class _QuickAmount" → "class _QuickAmount"
class _QuickAmount extends StatelessWidget {
  final String amount;
  final VoidCallback onTap;
  const _QuickAmount({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Text('+$amount',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _CryptoSelector extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CryptoSelector({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.goldGradient : null,
          color: isSelected ? null : AppColors.darkBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.gold : AppColors.gold.withOpacity(0.2)),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 10)] : [],
        ),
        child: Text(label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          )),
      ),
    );
  }
}

