// ═══════════════════════════════════════════════════════════════
// TOUNESBET - APPLICATION DE PARIS SPORTIFS LUXE
// Version: 1.0.0
// Stack: Flutter + Firebase + Flouci + D17 + Crypto
// Design: Midnight Gold (#000000 + #D4AF37)
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
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION - REMPLACER CES VALEURS
// ═══════════════════════════════════════════════════════════════
class Config {
  // Firebase - Récupérer depuis console.firebase.google.com
  static const String firebaseApiKey        = 'VOTRE_FIREBASE_API_KEY';
  static const String firebaseProjectId     = 'tounesbet-prod';
  static const String googleClientId        = 'VOTRE_GOOGLE_CLIENT_ID.apps.googleusercontent.com';

  // Flouci - Récupérer depuis developers.flouci.com
  static const String flouciApiKey          = 'VOTRE_FLOUCI_API_KEY';
  static const String flouciAppSecret       = 'VOTRE_FLOUCI_APP_SECRET';
  static const String flouciBaseUrl         = 'https://developers.flouci.com/api';

  // D17 - Récupérer depuis portail marchand D17
  static const String d17MerchantId         = 'VOTRE_D17_MERCHANT_ID';
  static const String d17BaseUrl            = 'https://www.d17.com.tn/api';

  // Crypto - Vos adresses wallet de réception
  static const String usdtTrc20Address      = 'VOTRE_ADRESSE_USDT_TRC20';
  static const String bitcoinAddress        = 'VOTRE_ADRESSE_BITCOIN';
  static const String ethAddress            = 'VOTRE_ADRESSE_ETH';

  // WebSocket - Votre serveur de cotes en temps réel
  static const String wsOddsUrl             = 'wss://api.tounesbet.com/odds/live';

  // Backend API
  static const String apiBaseUrl            = 'https://api.tounesbet.com/v1';
}

// ═══════════════════════════════════════════════════════════════
// THEME MIDNIGHT GOLD
// ═══════════════════════════════════════════════════════════════
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
  static const Color oddsUp     = Color(0xFF00E676);
  static const Color oddsDown   = Color(0xFFFF1744);

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

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF111111)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ═══════════════════════════════════════════════════════════════
// MODELES DE DONNEES
// ═══════════════════════════════════════════════════════════════
class Match {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String league;
  final String time;
  final String imageUrl;
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
    required this.imageUrl,
    required this.oddsHome,
    required this.oddsDraw,
    required this.oddsAway,
    this.isLive = false,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    id: json['id'],
    homeTeam: json['home_team'],
    awayTeam: json['away_team'],
    league: json['league'],
    time: json['time'],
    imageUrl: json['image_url'] ?? '',
    oddsHome: (json['odds_home'] as num).toDouble(),
    oddsDraw: (json['odds_draw'] as num).toDouble(),
    oddsAway: (json['odds_away'] as num).toDouble(),
    isLive: json['is_live'] ?? false,
  );
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
    this.stake = 0,
  });

  double get potentialWin => stake * odds;
}

// ═══════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forcer le mode portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Style de la barre de statut
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0A0A),
  ));

  // Initialiser Firebase
  // IMPORTANT: Ajouter google-services.json dans android/app/
  // IMPORTANT: Ajouter GoogleService-Info.plist dans ios/Runner/
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.gold,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════════════════════
class ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  ParticlePainter(this.progress)
      : particles = List.generate(80, (i) => _Particle(i));

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
    _logoCtrl = AnimationController(
      duration: const Duration(milliseconds: 2500), vsync: this);
    _particleCtrl = AnimationController(
      duration: const Duration(seconds: 4), vsync: this)..repeat();

    _scale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _glow = Tween<double>(begin: 0.0, end: 40.0).animate(
      CurvedAnimation(parent: _logoCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut)));

    _logoCtrl.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
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
          builder: (_, __) => CustomPaint(
            painter: ParticlePainter(_particleCtrl.value),
            size: Size.infinite,
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _logoCtrl,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 2),
                        boxShadow: [BoxShadow(
                          color: AppColors.gold.withOpacity(0.5),
                          blurRadius: _glow.value,
                          spreadRadius: _glow.value / 4,
                        )],
                      ),
                      child: Center(
                        child: ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.goldGradient.createShader(b),
                          child: const Text('TB',
                            style: TextStyle(
                              fontSize: 52, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: 2,
                            )),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.goldGradient.createShader(b),
                      child: const Text('TOUNESBET',
                        style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 8,
                        )),
                    ),
                    const SizedBox(height: 8),
                    const Text('PARIS SPORTIFS DE LUXE',
                      style: TextStyle(
                        color: AppColors.grey, fontSize: 11,
                        letterSpacing: 5, fontWeight: FontWeight.w300,
                      )),
                  ],
                ),
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
  
