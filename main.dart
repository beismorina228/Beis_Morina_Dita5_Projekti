import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// K3 - Incident model
// K4 - REST reading and server-side filters
// K5 - Incident list with ListView.builder
// K6 - StreamBuilder loading, error, empty and data states
// K7 - Supabase Auth and session
// K8 - Incident details
// K9 - Report form and validation
// K10 - POST new incident
// K11 - PATCH owner incident status
// K12 - Owner delete with confirmation
// K13 - Live 5-second StreamController refresh
// K14 - ChoiceChip status filters and My Reports user filter
// K15 - Material 3 theme and dark mode
// K16 - NavigationBar with 3 tabs
// K17 - Profile and logout
// K18 - User feedback after actions

const supabaseUrl = 'https://hwokjawoqvynqlasytiu.supabase.co';
const supabaseKey = 'sb_publishable_ysmENt9oShMvF8IiVD3oLw_6zdQGHWR';

const authUrl = '$supabaseUrl/auth/v1';
const incidentsUrl = '$supabaseUrl/rest/v1/incidents';

const bgDark = Color(0xFF01060B);
const panelDark = Color(0xFF06131D);
const panelDark2 = Color(0xFF091B28);
const borderDark = Color(0xFF173B4D);

const lightBg = Color(0xFFEFF5F8);
const lightPanel = Color(0xFFFFFFFF);
const lightPanel2 = Color(0xFFF5F9FB);
const lightBorder = Color(0xFFB7CDD8);

const bgtBlue = Color(0xFF126A89);
const bgtBlueDeep = Color(0xFF073C59);

const cyberCyan = Color(0xFF26DCEB);
const cyberCyanBright = Color(0xFF75F6FF);
const cyberGreen = Color(0xFF31E5A2);

const dangerRed = Color(0xFFFF3D52);
const dangerOrange = Color(0xFFFF6B40);
const dangerAmber = Color(0xFFFFB21F);

const textLight = Color(0xFFF3F9FC);
const textMuted = Color(0xFF8EA7B7);

const textDark = Color(0xFF081721);
const textDarkMuted = Color(0xFF587181);

bool isDark(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color pageColor(BuildContext context) {
  return isDark(context) ? bgDark : lightBg;
}

Color panelColor(BuildContext context) {
  return isDark(context) ? panelDark : lightPanel;
}

Color panel2Color(BuildContext context) {
  return isDark(context) ? panelDark2 : lightPanel2;
}

Color borderColor(BuildContext context) {
  return isDark(context) ? borderDark : lightBorder;
}

Color mainText(BuildContext context) {
  return isDark(context) ? textLight : textDark;
}

Color mutedText(BuildContext context) {
  return isDark(context) ? textMuted : textDarkMuted;
}

Color systemAccent(BuildContext context) {
  return isDark(context) ? cyberCyan : bgtBlue;
}

// Auth

class Session {
  final String accessToken;
  final String userId;
  final String email;

  const Session({
    required this.accessToken,
    required this.userId,
    required this.email,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return Session(
      accessToken: json['access_token']?.toString() ?? '',
      userId: user?['id']?.toString() ?? '',
      email: user?['email']?.toString() ?? '',
    );
  }
}

Session? currentSession;

Map<String, String> authHeaders({
  bool minimal = false,
}) {
  final headers = <String, String>{
    'apikey': supabaseKey,
    'Content-Type': 'application/json',
  };

  final session = currentSession;

  if (session != null && session.accessToken.isNotEmpty) {
    headers['Authorization'] = 'Bearer ${session.accessToken}';
  }

  if (minimal) {
    headers['Prefer'] = 'return=minimal';
  }

  return headers;
}

String authError(http.Response response) {
  try {
    final data = jsonDecode(response.body);

    return (data['msg'] ??
            data['error_description'] ??
            data['message'] ??
            'Gabim ${response.statusCode}')
        .toString();
  } catch (_) {
    return 'Gabim ${response.statusCode}';
  }
}

Future<Session> signUp(
  String email,
  String password,
) async {
  final response = await http.post(
    Uri.parse('$authUrl/signup'),
    headers: authHeaders(),
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(authError(response));
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;

  if (data['access_token'] == null) {
    throw Exception(
      'Kontrolloni Confirm Email në Supabase.',
    );
  }

  return Session.fromJson(data);
}

Future<Session> signIn(
  String email,
  String password,
) async {
  final response = await http.post(
    Uri.parse(
      '$authUrl/token?grant_type=password',
    ),
    headers: authHeaders(),
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(authError(response));
  }

  return Session.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
}

Future<void> signOut() async {
  if (currentSession == null) return;

  await http.post(
    Uri.parse('$authUrl/logout'),
    headers: authHeaders(),
  );
}

// K3 - Incident model

class Incident {
  final int id;
  final String userId;
  final String author;
  final String title;
  final String description;
  final String category;
  final String location;
  final String severity;
  final String status;
  final DateTime createdAt;

  const Incident({
    required this.id,
    required this.userId,
    required this.author,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.severity,
    required this.status,
    required this.createdAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      location: json['location']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'low',
      status: json['status']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get isMine {
    final session = currentSession;
    if (session == null) return false;
    return userId == session.userId;
  }

  bool get isOpen => status == 'open';

  bool get isHighRisk => severity == 'high' || severity == 'critical';
}

// K4 - Database reading and filters

Future<List<Incident>> fetchIncidents({
  String filter = 'all',
}) async {
  final session = currentSession;

  if (session == null) {
    throw Exception('Session not available.');
  }

  var url = '$incidentsUrl?select=*&order=created_at.desc&limit=100';

  // K4 + K14 - REST filters
  switch (filter) {
    case 'open':
      url = '$url&status=eq.open';
      break;
    case 'resolved':
      url = '$url&status=eq.resolved';
      break;
    case 'high':
      url = '$url&severity=in.(high,critical)';
      break;
    case 'mine':
      url = '$url&user_id=eq.${session.userId}';
      break;
  }

  final response = await http.get(
    Uri.parse(url),
    headers: authHeaders(),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Gabim ${response.statusCode}: ${response.body}',
    );
  }

  final decoded = jsonDecode(response.body);

  if (decoded is! List) {
    return [];
  }

  return decoded
      .map(
        (row) => Incident.fromJson(
          row as Map<String, dynamic>,
        ),
      )
      .toList();
}

// K10 - Create incident

Future<void> addIncident({
  required String title,
  required String description,
  required String category,
  required String location,
  required String severity,
}) async {
  final session = currentSession;

  if (session == null) {
    throw Exception('Session not available.');
  }

  final response = await http.post(
    Uri.parse(incidentsUrl),
    headers: authHeaders(minimal: true),
    body: jsonEncode({
      'author': session.email,
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'severity': severity,
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Gabim ${response.statusCode}: ${response.body}',
    );
  }
}

// K11 - Update incident

Future<void> resolveIncident(int id) async {
  if (currentSession == null) {
    throw Exception('Session not available.');
  }

  final response = await http.patch(
    Uri.parse('$incidentsUrl?id=eq.$id'),
    headers: authHeaders(minimal: true),
    body: jsonEncode({
      'status': 'resolved',
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Gabim ${response.statusCode}: ${response.body}',
    );
  }
}

// K12 - Delete incident

Future<void> deleteIncident(int id) async {
  if (currentSession == null) {
    throw Exception('Session not available.');
  }

  final response = await http.delete(
    Uri.parse('$incidentsUrl?id=eq.$id'),
    headers: authHeaders(minimal: true),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Gabim ${response.statusCode}: ${response.body}',
    );
  }
}

String formatDate(DateTime date) {
  final local = date.toLocal();

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day.$month · $hour:$minute';
}

String cleanName(String value) {
  if (value.isEmpty) return value;

  return '${value[0].toUpperCase()}'
      '${value.substring(1)}';
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'phishing':
      return Icons.phishing;

    case 'account':
      return Icons.manage_accounts_outlined;

    case 'network':
      return Icons.wifi;

    case 'device':
      return Icons.computer;

    default:
      return Icons.security;
  }
}

Color severityColor(String severity) {
  switch (severity) {
    case 'critical':
      return dangerRed;

    case 'high':
      return dangerOrange;

    case 'medium':
      return dangerAmber;

    default:
      return cyberGreen;
  }
}

// Cyber effects

class CyberBackdrop extends StatefulWidget {
  const CyberBackdrop({
    super.key,
  });

  @override
  State<CyberBackdrop> createState() => _CyberBackdropState();
}

class _CyberBackdropState extends State<CyberBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3100),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: CyberPainter(
              progress: controller.value,
              dark: isDark(context),
            ),
          );
        },
      ),
    );
  }
}

class CyberPainter extends CustomPainter {
  final double progress;
  final bool dark;

  const CyberPainter({
    required this.progress,
    required this.dark,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final accent = dark ? cyberCyan : bgtBlue;

    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [
                Color(0xFF01060B),
                Color(0xFF02111A),
                Color(0xFF01060B),
              ]
            : const [
                Color(0xFFF4F9FB),
                Color(0xFFEAF3F7),
                Color(0xFFF5F9FB),
              ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(
      Offset.zero & size,
      background,
    );

    _drawGrid(canvas, size, accent);
    _drawScanlines(canvas, size, accent);
    _drawDataRain(canvas, size, accent);
    _drawSystemCodes(canvas, size, accent);
    _drawBeam(canvas, size, accent);
    _drawCorners(canvas, size, accent);
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    Color accent,
  ) {
    final paint = Paint()
      ..color = accent.withOpacity(
        dark ? 0.085 : 0.04,
      )
      ..strokeWidth = 1;

    const gapY = 37.0;
    const gapX = 43.0;

    final moveY = progress * gapY;

    final sway = math.sin(progress * math.pi * 2) * 7;

    for (double y = -gapY; y < size.height + gapY; y += gapY) {
      canvas.drawLine(
        Offset(0, y + moveY),
        Offset(size.width, y + moveY),
        paint,
      );
    }

    for (double x = -gapX; x < size.width + gapX; x += gapX) {
      canvas.drawLine(
        Offset(x + sway, 0),
        Offset(x - sway, size.height),
        paint,
      );
    }
  }

  void _drawScanlines(
    Canvas canvas,
    Size size,
    Color accent,
  ) {
    final paint = Paint()
      ..color = accent.withOpacity(
        dark ? 0.03 : 0.012,
      )
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 5) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawDataRain(
    Canvas canvas,
    Size size,
    Color accent,
  ) {
    const count = 26;

    for (int i = 0; i < count; i++) {
      final x = (((i * 47) % 101) / 100) * size.width;

      final speed = 0.55 + (i % 7) * 0.08;

      final y = ((progress * speed + i * 0.071) % 1.0) * size.height;

      final length = 10.0 + (i % 5) * 7;

      final particleColor = i % 6 == 0 ? cyberGreen : accent;

      final paint = Paint()
        ..color = particleColor.withOpacity(
          dark ? 0.28 : 0.10,
        )
        ..strokeWidth = i % 5 == 0 ? 2 : 1;

      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + length),
        paint,
      );

      if (i % 4 == 0) {
        canvas.drawCircle(
          Offset(x, y + length),
          1.7,
          Paint()
            ..color = particleColor.withOpacity(
              dark ? 0.65 : 0.25,
            ),
        );
      }
    }
  }

  void _drawSystemCodes(
    Canvas canvas,
    Size size,
    Color accent,
  ) {
    final labels = [
      'NODE_03 / AUTH_OK',
      '0xA4F8',
      'PACKET_17',
      'SYNC_05',
      'RLS_ACTIVE',
      '01011001',
    ];

    for (int i = 0; i < labels.length; i++) {
      final offset = (progress * (0.35 + i * 0.04) + i * 0.17) % 1;

      final x = i.isEven ? 10.0 + i * 6 : size.width - 90 - i * 2;

      final y = offset * size.height;

      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: accent.withOpacity(
              dark ? 0.16 : 0.07,
            ),
            fontSize: 8,
            fontFamily: 'monospace',
            letterSpacing: 0.7,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        Offset(x, y),
      );
    }
  }

  void _drawBeam(
    Canvas canvas,
    Size size,
    Color accent,
  ) {
    final y = size.height * progress;
    final beamHeight = dark ? 96.0 : 72.0;

    final rect = Rect.fromLTWH(
      0,
      y - beamHeight / 2,
      size.width,
      beamHeight,
    );

    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          accent.withOpacity(
            dark ? 0.04 : 0.015,
          ),
          accent.withOpacity(
            dark ? 0.24 : 0.08,
          ),
          accent.withOpacity(
            dark ? 0.06 : 0.02,
          ),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, beam);

    final line = Paint()
      ..color = accent.withOpacity(
        dark ? 0.78 : 0.30,
      )
      ..strokeWidth = 1.4;

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      line,
    );
  }

  void _drawCorners(
    Canvas canvas,
    Size size,
    Color accent,
  ) {
    final pulse = (math.sin(progress * math.pi * 2) + 1) / 2;

    final paint = Paint()
      ..color = accent.withOpacity(
        dark ? 0.35 + pulse * 0.18 : 0.16,
      )
      ..strokeWidth = 2.2;

    const m = 9.0;
    const l = 25.0;

    canvas.drawLine(
      const Offset(m, m),
      const Offset(m + l, m),
      paint,
    );

    canvas.drawLine(
      const Offset(m, m),
      const Offset(m, m + l),
      paint,
    );

    canvas.drawLine(
      Offset(size.width - m, m),
      Offset(size.width - m - l, m),
      paint,
    );

    canvas.drawLine(
      Offset(size.width - m, m),
      Offset(size.width - m, m + l),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    CyberPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress || oldDelegate.dark != dark;
  }
}

class PulseDot extends StatefulWidget {
  final Color color;

  const PulseDot({
    super.key,
    required this.color,
  });

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      lowerBound: 0.3,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: controller,
      child: Icon(
        Icons.circle,
        size: 7,
        color: widget.color,
      ),
    );
  }
}

class BreathingGlow extends StatefulWidget {
  final Widget child;
  final Color color;

  const BreathingGlow({
    super.key,
    required this.child,
    required this.color,
  });

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isDark(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        final value = controller.value;

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(
                  0.04 + value * 0.10,
                ),
                blurRadius: 8 + value * 22,
                spreadRadius: value * 1.2,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

class CyberTitle extends StatefulWidget {
  final String text;
  final double size;
  final TextAlign align;

  const CyberTitle({
    super.key,
    required this.text,
    this.size = 24,
    this.align = TextAlign.left,
  });

  @override
  State<CyberTitle> createState() => _CyberTitleState();
}

class _CyberTitleState extends State<CyberTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final phase = controller.value;

        final glitch = isDark(context) && phase > 0.92 && phase < 0.975;

        final main = Text(
          widget.text,
          textAlign: widget.align,
          style: TextStyle(
            color: mainText(context),
            fontSize: widget.size,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
            height: 1.03,
          ),
        );

        if (!glitch) {
          return main;
        }

        final strength = math.sin(
          (phase - 0.92) / 0.055 * math.pi,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(
                -2.5 * strength,
                0,
              ),
              child: Opacity(
                opacity: 0.55,
                child: Text(
                  widget.text,
                  textAlign: widget.align,
                  style: TextStyle(
                    color: dangerRed,
                    fontSize: widget.size,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    height: 1.03,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(
                2.5 * strength,
                0,
              ),
              child: Opacity(
                opacity: 0.65,
                child: Text(
                  widget.text,
                  textAlign: widget.align,
                  style: TextStyle(
                    color: cyberCyanBright,
                    fontSize: widget.size,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    height: 1.03,
                  ),
                ),
              ),
            ),
            main,
          ],
        );
      },
    );
  }
}

class PulseActionButton extends StatefulWidget {
  final VoidCallback onPressed;

  const PulseActionButton({
    super.key,
    required this.onPressed,
  });

  @override
  State<PulseActionButton> createState() => _PulseActionButtonState();
}

class _PulseActionButtonState extends State<PulseActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> scale;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    scale = Tween<double>(
      begin: 0.985,
      end: 1.035,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scale,
      child: FloatingActionButton.extended(
        onPressed: widget.onPressed,
        backgroundColor: cyberCyan,
        foregroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
        icon: const Icon(
          Icons.add_moderator_outlined,
        ),
        label: const Text(
          'REPORT',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}

// Shared UI

class BgtLogo extends StatelessWidget {
  final double size;

  const BgtLogo({
    super.key,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: systemAccent(context).withOpacity(
              isDark(context) ? 0.22 : 0.08,
            ),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/bgt_logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: bgtBlue,
              child: const Icon(
                Icons.school_outlined,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }
}

class SystemLabel extends StatelessWidget {
  final String text;

  const SystemLabel(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: systemAccent(context),
        fontFamily: 'monospace',
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.55,
      ),
    );
  }
}

class CyberLine extends StatelessWidget {
  const CyberLine({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            systemAccent(context).withOpacity(0.65),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class LiveIndicator extends StatelessWidget {
  const LiveIndicator({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: cyberGreen.withOpacity(
          isDark(context) ? 0.05 : 0.08,
        ),
        border: Border.all(
          color: cyberGreen.withOpacity(0.48),
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(
            color: cyberGreen,
          ),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              color: cyberGreen,
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class TacticalBadge extends StatelessWidget {
  final String text;
  final Color color;

  const TacticalBadge({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(
          isDark(context) ? 0.045 : 0.08,
        ),
        border: Border.all(
          color: color.withOpacity(0.42),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class CommandStat extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const CommandStat({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 11,
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(
            isDark(context) ? 0.045 : 0.075,
          ),
          border: Border.all(
            color: color.withOpacity(0.34),
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontFamily: 'monospace',
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontFamily: 'monospace',
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 42,
      ),
      decoration: BoxDecoration(
        color: panelColor(context),
        border: Border.all(
          color: borderColor(context),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.security_update_good_outlined,
            color: cyberGreen,
            size: 46,
          ),
          const SizedBox(height: 12),
          const SystemLabel(
            'No active signals',
          ),
          const SizedBox(height: 6),
          Text(
            'No incidents detected.',
            style: TextStyle(
              color: mainText(context),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

// K15 - App theme

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool darkMode = true;

  void loggedIn(Session session) {
    currentSession = session;
    setState(() {});
  }

  Future<void> logout() async {
    try {
      await signOut();
    } catch (_) {}

    currentSession = null;

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: bgtBlue,
        brightness: Brightness.light,
      ),
      cardTheme: const CardThemeData(
        color: lightPanel,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: bgtBlue.withOpacity(0.12),
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(
            color: textDark,
            fontSize: 11,
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) {
            if (states.contains(
              MaterialState.selected,
            )) {
              return const IconThemeData(
                color: bgtBlue,
              );
            }

            return const IconThemeData(
              color: textDarkMuted,
            );
          },
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightPanel2,
        labelStyle: const TextStyle(
          color: textDarkMuted,
        ),
        prefixIconColor: bgtBlue,
        suffixIconColor: textDarkMuted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: bgtBlue,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: dangerRed,
          ),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: textDark,
            displayColor: textDark,
          ),
      useMaterial3: true,
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: bgtBlue,
        brightness: Brightness.dark,
      ),
      cardTheme: const CardThemeData(
        color: panelDark,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF050F18),
        indicatorColor: cyberCyan.withOpacity(0.15),
      ),
      dividerColor: borderDark,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panelDark2,
        labelStyle: const TextStyle(
          color: textMuted,
        ),
        prefixIconColor: cyberCyan,
        suffixIconColor: textMuted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: borderDark,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: cyberCyan,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: dangerRed,
          ),
        ),
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BGT Sentinel',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: currentSession == null
          ? LoginPage(
              onLogin: loggedIn,
            )
          : HomeShell(
              darkMode: darkMode,
              onThemeChanged: (value) {
                setState(() {
                  darkMode = value;
                });
              },
              onLogout: logout,
            ),
    );
  }
}

// K7 - Login and registration

class LoginPage extends StatefulWidget {
  final ValueChanged<Session> onLogin;

  const LoginPage({
    super.key,
    required this.onLogin,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit(
    bool register,
  ) async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (!email.contains('@')) {
      setState(() {
        error = 'Shkruani një email të vlefshëm.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        error = 'Fjalëkalimi duhet të ketë së paku 6 karaktere.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final session = register
          ? await signUp(
              email,
              password,
            )
          : await signIn(
              email,
              password,
            );

      if (!mounted) return;

      widget.onLogin(session);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;

        error = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor(context),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackdrop(),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                  ),
                  child: BreathingGlow(
                    color: systemAccent(context),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: panelColor(context).withOpacity(
                          isDark(context) ? 0.95 : 0.97,
                        ),
                        border: Border.all(
                          color: systemAccent(
                            context,
                          ).withOpacity(0.44),
                        ),
                        borderRadius: BorderRadius.circular(
                          5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: BgtLogo(
                              size: 84,
                            ),
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          const Center(
                            child: SystemLabel(
                              'BGT Security Operations',
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Center(
                            child: CyberTitle(
                              text: 'SENTINEL',
                              size: 34,
                              align: TextAlign.center,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            'CYBER DEFENSE / INCIDENT CONTROL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: mutedText(context),
                              fontFamily: 'monospace',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(
                            height: 17,
                          ),
                          const CyberLine(),
                          const SizedBox(
                            height: 17,
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: systemAccent(context),
                                size: 17,
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              Text(
                                'SECURE AUTHENTICATION',
                                style: TextStyle(
                                  color: mainText(context),
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 13,
                          ),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(
                                Icons.alternate_email,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 11,
                          ),
                          TextField(
                            controller: passwordController,
                            obscureText: hidePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    hidePassword = !hidePassword;
                                  });
                                },
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(
                              height: 10,
                            ),
                            Text(
                              error!,
                              style: const TextStyle(
                                color: dangerRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(
                            height: 16,
                          ),
                          if (loading)
                            const Center(
                              child: CircularProgressIndicator(),
                            )
                          else ...[
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: cyberCyan,
                                foregroundColor: bgDark,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    3,
                                  ),
                                ),
                              ),
                              onPressed: () => submit(false),
                              icon: const Icon(
                                Icons.login,
                              ),
                              label: const Text(
                                'ENTER SENTINEL',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    3,
                                  ),
                                ),
                              ),
                              onPressed: () => submit(true),
                              icon: const Icon(
                                Icons.person_add_alt,
                              ),
                              label: const Text(
                                'CREATE ACCESS',
                              ),
                            ),
                          ],
                          const SizedBox(
                            height: 18,
                          ),
                          const CyberLine(),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const PulseDot(
                                color: cyberGreen,
                              ),
                              const SizedBox(
                                width: 6,
                              ),
                              Text(
                                'SUPABASE AUTH / RLS PROTECTED',
                                style: TextStyle(
                                  color: mutedText(context),
                                  fontFamily: 'monospace',
                                  fontSize: 8,
                                  letterSpacing: 0.8,
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
            ),
          ),
        ],
      ),
    );
  }
}

// K16 - Three-tab navigation

class HomeShell extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function() onLogout;

  const HomeShell({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
    required this.onLogout,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  Widget currentPage() {
    switch (index) {
      case 1:
        return const MyReportsPage();

      case 2:
        return ProfilePage(
          darkMode: widget.darkMode,
          onThemeChanged: widget.onThemeChanged,
          onLogout: widget.onLogout,
        );

      default:
        return const DashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor(context),
      body: currentPage(),
      bottomNavigationBar: NavigationBar(
        height: 67,
        selectedIndex: index,
        onDestinationSelected: (newIndex) {
          setState(() {
            index = newIndex;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Sentinel',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'My Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// K6 + K13 + K14 - Live dashboard, states and filters

class DashboardData {
  final List<Incident> all;
  final List<Incident> visible;

  const DashboardData({
    required this.all,
    required this.visible,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final controller = StreamController<DashboardData>();

  Timer? timer;
  String filter = 'all';

  @override
  void initState() {
    super.initState();

    load();

    timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => load(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.close();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final all = await fetchIncidents();

      final visible = filter == 'all'
          ? all
          : await fetchIncidents(
              filter: filter,
            );

      if (!controller.isClosed) {
        controller.add(
          DashboardData(
            all: all,
            visible: visible,
          ),
        );
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  Future<void> openReport() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportIncidentPage(),
      ),
    );

    if (created == true) {
      await load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incident logged into Sentinel.',
          ),
        ),
      );
    }
  }

  Future<void> openIncident(
    Incident incident,
  ) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentDetailPage(
          incident: incident,
        ),
      ),
    );

    if (changed == true) {
      await load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incident database updated.',
          ),
        ),
      );
    }
  }

  Widget commandPanel(
    List<Incident> incidents,
  ) {
    final openCount = incidents.where((x) => x.isOpen).length;

    final highRiskCount = incidents
        .where(
          (x) => x.isOpen && x.isHighRisk,
        )
        .length;

    final criticalCount = incidents
        .where(
          (x) => x.isOpen && x.severity == 'critical',
        )
        .length;

    final resolvedCount = incidents.where((x) => !x.isOpen).length;

    String posture = 'STABLE';
    Color postureColor = cyberGreen;

    if (criticalCount > 0) {
      posture = 'ELEVATED';
      postureColor = dangerRed;
    } else if (highRiskCount > 0) {
      posture = 'GUARDED';
      postureColor = dangerAmber;
    }

    final panel = Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: panelDark.withOpacity(0.96),
        border: Border.all(
          color: cyberCyan.withOpacity(0.40),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BgtLogo(size: 49),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BGT SENTINEL',
                      style: TextStyle(
                        color: textLight,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'SECURITY OPERATIONS',
                      style: TextStyle(
                        color: cyberCyan,
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const LiveIndicator(),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  cyberCyan.withOpacity(
                    0.75,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'THREAT POSTURE',
                  style: TextStyle(
                    color: cyberCyan,
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: postureColor.withOpacity(0.05),
                  border: Border.all(
                    color: postureColor.withOpacity(0.55),
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  posture,
                  style: TextStyle(
                    color: postureColor,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const CyberTitle(
            text: 'REAL-TIME\nINCIDENT CONTROL',
            size: 24,
          ),
          const SizedBox(height: 7),
          const Text(
            'Monitor, classify and resolve BGT security events.',
            style: TextStyle(
              color: textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              CommandStat(
                value: openCount,
                label: 'OPEN',
                color: cyberCyan,
              ),
              const SizedBox(width: 6),
              CommandStat(
                value: highRiskCount,
                label: 'HIGH RISK',
                color: dangerOrange,
              ),
              const SizedBox(width: 6),
              CommandStat(
                value: resolvedCount,
                label: 'RESOLVED',
                color: cyberGreen,
              ),
            ],
          ),
        ],
      ),
    );

    return BreathingGlow(
      color: cyberCyan,
      child: panel,
    );
  }

  Widget filters() {
    const values = [
      ['all', 'ALL'],
      ['open', 'OPEN'],
      ['resolved', 'RESOLVED'],
      ['high', 'HIGH RISK'],
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in values) ...[
            ChoiceChip(
              label: Text(
                item[1],
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              selected: filter == item[0],
              onSelected: (_) {
                setState(() {
                  filter = item[0];
                });
                load();
              },
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor(context),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackdrop(),
          ),
          SafeArea(
            child: StreamBuilder<DashboardData>(
              stream: controller.stream,
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 50,
                            color: dangerRed,
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          const SystemLabel(
                            'Connection failure',
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Text(
                            snapshot.error.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          FilledButton(
                            onPressed: load,
                            child: const Text('RETRY'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data!;

                return RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      95,
                    ),
                    children: [
                      commandPanel(
                        data.all,
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      const SystemLabel(
                        'Incident queue',
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: CyberTitle(
                              text: 'ACTIVE FEED',
                              size: 20,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: panelColor(
                                context,
                              ).withOpacity(
                                0.88,
                              ),
                              border: Border.all(
                                color: borderColor(
                                  context,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                3,
                              ),
                            ),
                            child: Text(
                              'SYNC / 5S',
                              style: TextStyle(
                                color: systemAccent(
                                  context,
                                ),
                                fontFamily: 'monospace',
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        '${data.visible.length.toString().padLeft(2, '0')} EVENTS / CURRENT VIEW',
                        style: TextStyle(
                          color: mutedText(context),
                          fontFamily: 'monospace',
                          fontSize: 8,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      filters(),
                      const SizedBox(
                        height: 12,
                      ),
                      const CyberLine(),
                      const SizedBox(
                        height: 12,
                      ),
                      if (data.visible.isEmpty)
                        const EmptyState()
                      else
                        IncidentList(
                          incidents: data.visible,
                          onTap: openIncident,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: PulseActionButton(
        onPressed: openReport,
      ),
    );
  }
}

// K5 - Incident list

class IncidentList extends StatelessWidget {
  final List<Incident> incidents;
  final ValueChanged<Incident> onTap;

  const IncidentList({
    super.key,
    required this.incidents,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: incidents.length,
      itemBuilder: (context, index) {
        final incident = incidents[index];

        return Padding(
          padding: const EdgeInsets.only(
            bottom: 8,
          ),
          child: IncidentCard(
            incident: incident,
            onTap: () => onTap(incident),
          ),
        );
      },
    );
  }
}

class IncidentCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback onTap;

  const IncidentCard({
    super.key,
    required this.incident,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final severity = severityColor(incident.severity);

    return Material(
      color: panelColor(context).withOpacity(
        isDark(context) ? 0.94 : 0.97,
      ),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor(context),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 132,
                color: severity,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 37,
                            height: 37,
                            decoration: BoxDecoration(
                              color: severity.withOpacity(
                                isDark(context) ? 0.05 : 0.09,
                              ),
                              border: Border.all(
                                color: severity.withOpacity(
                                  0.42,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                3,
                              ),
                            ),
                            child: Icon(
                              categoryIcon(
                                incident.category,
                              ),
                              color: severity,
                              size: 19,
                            ),
                          ),
                          const SizedBox(
                            width: 9,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  incident.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: mainText(context),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  '#INC-${incident.id.toString().padLeft(3, '0')}',
                                  style: TextStyle(
                                    color: mutedText(context),
                                    fontFamily: 'monospace',
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: mutedText(context),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 9,
                      ),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          TacticalBadge(
                            text: cleanName(
                              incident.category,
                            ),
                            color: systemAccent(context),
                          ),
                          TacticalBadge(
                            text: incident.severity.toUpperCase(),
                            color: severity,
                          ),
                          TacticalBadge(
                            text: incident.isOpen ? 'OPEN' : 'RESOLVED',
                            color: incident.isOpen
                                ? const Color(
                                    0xFF5D8DA8,
                                  )
                                : cyberGreen,
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        incident.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedText(context),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(
                        height: 7,
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: mutedText(context),
                          ),
                          const SizedBox(
                            width: 4,
                          ),
                          Expanded(
                            child: Text(
                              incident.location,
                              style: TextStyle(
                                color: mainText(context),
                                fontFamily: 'monospace',
                                fontSize: 8,
                              ),
                            ),
                          ),
                          Text(
                            formatDate(
                              incident.createdAt,
                            ),
                            style: TextStyle(
                              color: mutedText(context),
                              fontFamily: 'monospace',
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// K9 - Report form and validation

class ReportIncidentPage extends StatefulWidget {
  const ReportIncidentPage({
    super.key,
  });

  @override
  State<ReportIncidentPage> createState() => _ReportIncidentPageState();
}

class _ReportIncidentPageState extends State<ReportIncidentPage> {
  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();

  final descriptionController = TextEditingController();

  final locationController = TextEditingController();

  String category = 'phishing';
  String severity = 'medium';
  bool saving = false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await addIncident(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        category: category,
        location: locationController.text.trim(),
        severity: severity,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor(context),
      appBar: AppBar(
        backgroundColor: pageColor(context),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SystemLabel(
              'Sentinel intake',
            ),
            Text(
              'NEW INCIDENT',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackdrop(),
          ),
          Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(
                14,
              ),
              children: [
                BreathingGlow(
                  color: systemAccent(context),
                  child: Container(
                    padding: const EdgeInsets.all(
                      15,
                    ),
                    decoration: BoxDecoration(
                      color: panelColor(
                        context,
                      ).withOpacity(
                        isDark(context) ? 0.94 : 0.97,
                      ),
                      border: Border.all(
                        color: systemAccent(
                          context,
                        ).withOpacity(0.38),
                      ),
                      borderRadius: BorderRadius.circular(
                        4,
                      ),
                    ),
                    child: Row(
                      children: [
                        const BgtLogo(
                          size: 50,
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SystemLabel(
                                'Incident protocol',
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                'REPORT SECURITY EVENT',
                                style: TextStyle(
                                  color: mainText(context),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                'Clear data. Fast response.',
                                style: TextStyle(
                                  color: mutedText(context),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                const SystemLabel(
                  'Incident details',
                ),
                const SizedBox(
                  height: 9,
                ),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Incident title',
                    prefixIcon: Icon(Icons.terminal),
                  ),
                  validator: (value) {
                    if ((value?.trim().length ?? 0) < 3) {
                      return 'At least 3 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 11,
                ),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(
                      Icons.description_outlined,
                    ),
                  ),
                  validator: (value) {
                    if ((value?.trim().length ?? 0) < 5) {
                      return 'At least 5 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 11,
                ),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(
                      Icons.my_location_outlined,
                    ),
                  ),
                  validator: (value) {
                    if ((value?.trim().length ?? 0) < 2) {
                      return 'Enter a location.';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 11,
                ),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(
                      Icons.category_outlined,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'phishing',
                      child: Text('Phishing'),
                    ),
                    DropdownMenuItem(
                      value: 'account',
                      child: Text('Account'),
                    ),
                    DropdownMenuItem(
                      value: 'network',
                      child: Text('Network'),
                    ),
                    DropdownMenuItem(
                      value: 'device',
                      child: Text('Device'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        category = value;
                      });
                    }
                  },
                ),
                const SizedBox(
                  height: 11,
                ),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    prefixIcon: Icon(
                      Icons.warning_amber_rounded,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('Low'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Medium'),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('High'),
                    ),
                    DropdownMenuItem(
                      value: 'critical',
                      child: Text('Critical'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        severity = value;
                      });
                    }
                  },
                ),
                const SizedBox(
                  height: 17,
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cyberCyan,
                    foregroundColor: bgDark,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        3,
                      ),
                    ),
                  ),
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send_outlined,
                        ),
                  label: Text(
                    saving ? 'TRANSMITTING...' : 'SUBMIT TO SENTINEL',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// K8 + K11 + K12 - Details and owner actions

class IncidentDetailPage extends StatefulWidget {
  final Incident incident;

  const IncidentDetailPage({
    super.key,
    required this.incident,
  });

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  bool working = false;

  Future<void> resolve() async {
    setState(() {
      working = true;
    });

    try {
      await resolveIncident(
        widget.incident.id,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        working = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    }
  }

  Future<void> remove() async {
    if (!widget.incident.isMine) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete incident?'),
          content: Text(
            widget.incident.title,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      working = true;
    });

    try {
      await deleteIncident(
        widget.incident.id,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        working = false;
      });

      // K18 - Feedback on delete failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Widget infoLine(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: systemAccent(context),
                fontFamily: 'monospace',
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: mainText(context),
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final severity = severityColor(incident.severity);

    return Scaffold(
      backgroundColor: pageColor(context),
      appBar: AppBar(
        backgroundColor: pageColor(context),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SystemLabel(
              'Sentinel case file',
            ),
            Text(
              'INCIDENT DETAIL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackdrop(),
          ),
          ListView(
            padding: const EdgeInsets.all(13),
            children: [
              BreathingGlow(
                color: severity,
                child: Container(
                  padding: const EdgeInsets.all(
                    15,
                  ),
                  decoration: BoxDecoration(
                    color: panelColor(
                      context,
                    ).withOpacity(
                      isDark(context) ? 0.95 : 0.98,
                    ),
                    border: Border.all(
                      color: severity.withOpacity(0.55),
                    ),
                    borderRadius: BorderRadius.circular(
                      4,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: severity.withOpacity(
                                isDark(context) ? 0.04 : 0.08,
                              ),
                              border: Border.all(
                                color: severity.withOpacity(
                                  0.55,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                3,
                              ),
                            ),
                            child: Icon(
                              categoryIcon(
                                incident.category,
                              ),
                              color: severity,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#INC-${incident.id.toString().padLeft(3, '0')}',
                                  style: TextStyle(
                                    color: mutedText(context),
                                    fontFamily: 'monospace',
                                    fontSize: 8,
                                  ),
                                ),
                                CyberTitle(
                                  text: incident.title,
                                  size: 19,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          TacticalBadge(
                            text: cleanName(
                              incident.category,
                            ),
                            color: systemAccent(context),
                          ),
                          TacticalBadge(
                            text: incident.severity.toUpperCase(),
                            color: severity,
                          ),
                          TacticalBadge(
                            text: incident.isOpen ? 'OPEN' : 'RESOLVED',
                            color: incident.isOpen
                                ? const Color(
                                    0xFF5D8DA8,
                                  )
                                : cyberGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                padding: const EdgeInsets.all(
                  15,
                ),
                decoration: BoxDecoration(
                  color: panelColor(context).withOpacity(
                    isDark(context) ? 0.94 : 0.98,
                  ),
                  border: Border.all(
                    color: borderColor(context),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SystemLabel(
                      'Incident summary',
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      incident.description,
                      style: TextStyle(
                        color: mainText(context),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    const CyberLine(),
                    const SizedBox(
                      height: 8,
                    ),
                    infoLine(
                      'STATUS',
                      incident.isOpen ? 'OPEN' : 'RESOLVED',
                    ),
                    infoLine(
                      'CATEGORY',
                      incident.category.toUpperCase(),
                    ),
                    infoLine(
                      'SEVERITY',
                      incident.severity.toUpperCase(),
                    ),
                    infoLine(
                      'LOCATION',
                      incident.location,
                    ),
                    infoLine(
                      'REPORTER',
                      incident.author,
                    ),
                    infoLine(
                      'CREATED',
                      formatDate(
                        incident.createdAt,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              if (incident.isMine) ...[
                if (incident.isOpen)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: cyberGreen,
                      foregroundColor: bgDark,
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          3,
                        ),
                      ),
                    ),
                    onPressed: working ? null : resolve,
                    icon: const Icon(
                      Icons.verified_outlined,
                    ),
                    label: const Text(
                      'MARK AS RESOLVED',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                if (incident.isOpen)
                  const SizedBox(
                    height: 8,
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dangerRed,
                    side: const BorderSide(
                      color: dangerRed,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        3,
                      ),
                    ),
                  ),
                  onPressed: working ? null : remove,
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  label: const Text(
                    'DELETE INCIDENT',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// K14 - My Reports user filter

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({
    super.key,
  });

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  List<Incident>? incidents;
  String? error;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    load();

    timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => load(),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = await fetchIncidents(
        filter: 'mine',
      );

      if (!mounted) return;

      setState(() {
        incidents = data;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    }
  }

  Future<void> openIncident(
    Incident incident,
  ) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentDetailPage(
          incident: incident,
        ),
      ),
    );

    if (changed == true) {
      await load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incident database updated.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        backgroundColor: pageColor(context),
        body: Center(
          child: FilledButton(
            onPressed: load,
            child: const Text('RETRY'),
          ),
        ),
      );
    }

    if (incidents == null) {
      return Scaffold(
        backgroundColor: pageColor(context),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final data = incidents!;

    final openCount = data.where((x) => x.isOpen).length;

    final resolvedCount = data.length - openCount;

    return Scaffold(
      backgroundColor: pageColor(context),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackdrop(),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  14,
                  12,
                  80,
                ),
                children: [
                  Row(
                    children: [
                      const BgtLogo(
                        size: 46,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SystemLabel(
                              'Personal sector',
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            const CyberTitle(
                              text: 'MY REPORTS',
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      const LiveIndicator(),
                    ],
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  const CyberLine(),
                  const SizedBox(
                    height: 14,
                  ),
                  Row(
                    children: [
                      CommandStat(
                        value: data.length,
                        label: 'TOTAL',
                        color: systemAccent(context),
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      CommandStat(
                        value: openCount,
                        label: 'OPEN',
                        color: dangerAmber,
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      CommandStat(
                        value: resolvedCount,
                        label: 'RESOLVED',
                        color: cyberGreen,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Text(
                    'OWNER-VERIFIED INCIDENTS',
                    style: TextStyle(
                      color: mutedText(context),
                      fontFamily: 'monospace',
                      fontSize: 8,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(
                    height: 9,
                  ),
                  if (data.isEmpty)
                    const EmptyState()
                  else
                    IncidentList(
                      incidents: data,
                      onTap: openIncident,
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

// K15 + K17 - Theme controls, profile and logout

class ProfilePage extends StatelessWidget {
  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function() onLogout;

  const ProfilePage({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final email = currentSession?.email ?? 'Unknown';

    return Scaffold(
      backgroundColor: pageColor(context),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackdrop(),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(
                13,
              ),
              children: [
                BreathingGlow(
                  color: systemAccent(context),
                  child: Container(
                    padding: const EdgeInsets.all(
                      17,
                    ),
                    decoration: BoxDecoration(
                      color: panelColor(
                        context,
                      ).withOpacity(
                        isDark(context) ? 0.94 : 0.98,
                      ),
                      border: Border.all(
                        color: systemAccent(
                          context,
                        ).withOpacity(0.38),
                      ),
                      borderRadius: BorderRadius.circular(
                        4,
                      ),
                    ),
                    child: Column(
                      children: [
                        const BgtLogo(
                          size: 72,
                        ),
                        const SizedBox(
                          height: 13,
                        ),
                        const SystemLabel(
                          'Identity verified',
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        const CyberTitle(
                          text: 'BGT SENTINEL',
                          size: 20,
                          align: TextAlign.center,
                        ),
                        const SizedBox(
                          height: 13,
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(
                            11,
                          ),
                          decoration: BoxDecoration(
                            color: cyberGreen.withOpacity(
                              isDark(context) ? 0.04 : 0.08,
                            ),
                            border: Border.all(
                              color: cyberGreen.withOpacity(
                                0.30,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(
                              3,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                email,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: mainText(context),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              const Text(
                                'AUTHENTICATED / SECURE SESSION',
                                style: TextStyle(
                                  color: cyberGreen,
                                  fontFamily: 'monospace',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
                const SystemLabel(
                  'System controls',
                ),
                const SizedBox(
                  height: 7,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: panelColor(context).withOpacity(
                      isDark(context) ? 0.94 : 0.98,
                    ),
                    border: Border.all(
                      color: borderColor(context),
                    ),
                    borderRadius: BorderRadius.circular(
                      4,
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: darkMode,
                        onChanged: onThemeChanged,
                        secondary: Icon(
                          Icons.dark_mode_outlined,
                          color: systemAccent(context),
                        ),
                        title: Text(
                          'TACTICAL DARK MODE',
                          style: TextStyle(
                            color: mainText(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          'Toggle Sentinel display mode',
                          style: TextStyle(
                            color: mutedText(context),
                          ),
                        ),
                      ),
                      const Divider(
                        height: 1,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.admin_panel_settings_outlined,
                          color: systemAccent(context),
                        ),
                        title: Text(
                          'ROW LEVEL SECURITY',
                          style: TextStyle(
                            color: mainText(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Owner actions protected by Supabase',
                          style: TextStyle(
                            color: mutedText(context),
                          ),
                        ),
                      ),
                      const Divider(
                        height: 1,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.sync_outlined,
                          color: cyberGreen,
                        ),
                        title: Text(
                          'LIVE SYNCHRONIZATION',
                          style: TextStyle(
                            color: mainText(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Refresh every 5 seconds',
                          style: TextStyle(
                            color: mutedText(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 13,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dangerRed,
                    side: const BorderSide(
                      color: dangerRed,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        3,
                      ),
                    ),
                  ),
                  onPressed: () async {
                    await onLogout();
                  },
                  icon: const Icon(
                    Icons.logout,
                  ),
                  label: const Text(
                    'TERMINATE SESSION',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 22,
                ),
                const CyberLine(),
                const SizedBox(
                  height: 9,
                ),
                Text(
                  'BGT SENTINEL // SECURITY OPERATIONS\n'
                  'BUILD 1.0 · DETECT / REPORT / RESOLVE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedText(context),
                    fontFamily: 'monospace',
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
