import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../entrance/presentation/entrance_screen.dart';
import '../../admin/presentation/admin_screen.dart';
import '../../finance/presentation/finance_screen.dart';

class RoleGateScreen extends StatefulWidget {
  const RoleGateScreen({super.key});

  @override
  State<RoleGateScreen> createState() => _RoleGateScreenState();
}

class _RoleGateScreenState extends State<RoleGateScreen> {
  String? _activeRole;
  bool _isVerifyingPin = false;

  Future<void> _promptPinAndEnter(
    String role,
    String roleTitle,
    Color accentColor,
    IconData roleIcon,
  ) async {
    final pinController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submitPin() async {
              if (pinController.text.trim().isEmpty) {
                setDialogState(() => errorText = 'Please enter your access PIN.');
                return;
              }
              setDialogState(() {
                _isVerifyingPin = true;
                errorText = null;
              });
              try {
                final res = await ApiClient.post(
                  '/api/auth/verify-pin',
                  body: {
                    'role': role,
                    'pin': pinController.text.trim(),
                  },
                );
                if (res['default_seminar_fee'] != null) {
                  AppConfig.defaultSeminarFee =
                      (res['default_seminar_fee'] as num).toDouble();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() => _activeRole = role);
                }
              } catch (e) {
                setDialogState(() {
                  errorText = e.toString();
                });
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => _isVerifyingPin = false);
                }
              }
            }

            return AlertDialog(
              contentPadding: const EdgeInsets.all(28),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(roleIcon, color: accentColor, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                roleTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Enter workspace security PIN',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      autofocus: true,
                      onSubmitted: (_) => submitPin(),
                      style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Security PIN',
                        hintText: '••••',
                        errorText: errorText,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Default PINs: Entrance (1111) • Finance (2222) • Admin (9999)',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                          ),
                          onPressed: _isVerifyingPin ? null : submitPin,
                          icon: _isVerifyingPin
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Unlock Portal'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showApiSettingsDialog() {
    final ctrl = TextEditingController(text: AppConfig.apiBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Backend API Connection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Point the web app to your live Render FastAPI URL or local server.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'FastAPI Base URL',
                  hintText: 'https://your-service.onrender.com',
                  prefixIcon: Icon(Icons.cloud_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              AppConfig.setApiUrl(ctrl.text);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save Endpoint'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeRole == 'ENTRANCE') {
      return EntranceScreen(
        onSwitchRole: () => setState(() => _activeRole = null),
      );
    }
    if (_activeRole == 'ADMIN') {
      return AdminScreen(
        onSwitchRole: () => setState(() => _activeRole = null),
      );
    }
    if (_activeRole == 'FINANCE') {
      return FinanceScreen(
        onSwitchRole: () => setState(() => _activeRole = null),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Subtle decorative top gradient glow
          Positioned(
            top: -140,
            left: -100,
            right: -100,
            child: Container(
              height: 420,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: 0.28),
                    const Color(0xFF0EA5E9).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  radius: 0.85,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.hub_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INTERNSHIP SEMINAR SYSTEM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                'Career Readiness & Practicum Orientation Portal',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE2E8F0),
                          side: const BorderSide(color: Color(0xFF334155)),
                          backgroundColor: const Color(0xFF1E293B),
                        ),
                        onPressed: _showApiSettingsDialog,
                        icon: const Icon(
                          Icons.dns_outlined,
                          size: 16,
                          color: Color(0xFF38BDF8),
                        ),
                        label: Text(
                          AppConfig.apiBaseUrl,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E293B), height: 1),
                // Main Content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              child: const Text(
                                'REAL-TIME SUPABASE + FASTAPI WORKSPACES',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Select Your Seminar Station',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 600),
                              child: Text(
                                'Choose your assigned committee portal below. All check-ins, walk-in registrations, and fee collections synchronize across stations instantaneously.',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 44),
                            Wrap(
                              spacing: 24,
                              runSpacing: 24,
                              alignment: WrapAlignment.center,
                              children: [
                                _RolePortalCard(
                                  badgeText: 'USHERS & REGISTRATION DESK',
                                  title: 'Entrance Desk',
                                  description:
                                      'Verify online pre-registration status in real time, mark students Present at the doors, and register Walk-In attendees with automatic duplicate protection.',
                                  features: const [
                                    'Instant ID & Name online lookup',
                                    '1-Tap Present check-in & pass view',
                                    'Live duplicate-checked Walk-In form',
                                  ],
                                  icon: Icons.how_to_reg,
                                  accentColor: const Color(0xFF0EA5E9),
                                  onTap: () => _promptPinAndEnter(
                                    'ENTRANCE',
                                    'Entrance Desk',
                                    const Color(0xFF0EA5E9),
                                    Icons.how_to_reg,
                                  ),
                                ),
                                _RolePortalCard(
                                  badgeText: 'TREASURY & COLLECTIONS',
                                  title: 'Finance Portal',
                                  description:
                                      'Track Paid and Unpaid seminar attendees, record Cash or GCash collections, and monitor Total Seminar Earnings and uncollected receivables.',
                                  features: const [
                                    'Live Total Earnings & Cash/GCash split',
                                    'Filter by Paid vs. Unpaid students',
                                    '1-Click payment & receipt logging',
                                  ],
                                  icon: Icons.account_balance_wallet_outlined,
                                  accentColor: const Color(0xFF10B981),
                                  onTap: () => _promptPinAndEnter(
                                    'FINANCE',
                                    'Finance Portal',
                                    const Color(0xFF10B981),
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                ),
                                _RolePortalCard(
                                  badgeText: 'EXECUTIVE COMMITTEE',
                                  title: 'Admin & Execom',
                                  description:
                                      'Full executive command center displaying Total Pre-Registered, Walk-In counts, Present vs. Absent turnout, plus full student CRUD and CSV import.',
                                  features: const [
                                    'Pre-Registered vs. Walk-In turnout KPIs',
                                    'Edit Present/Absent & student profiles',
                                    'Create, delete & bulk import CSV rosters',
                                  ],
                                  icon: Icons.admin_panel_settings_outlined,
                                  accentColor: const Color(0xFF8B5CF6),
                                  onTap: () => _promptPinAndEnter(
                                    'ADMIN',
                                    'Admin & Execom',
                                    const Color(0xFF8B5CF6),
                                    Icons.admin_panel_settings_outlined,
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
          ),
        ],
      ),
    );
  }
}

class _RolePortalCard extends StatefulWidget {
  final String badgeText;
  final String title;
  final String description;
  final List<String> features;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _RolePortalCard({
    required this.badgeText,
    required this.title,
    required this.description,
    required this.features,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_RolePortalCard> createState() => _RolePortalCardState();
}

class _RolePortalCardState extends State<_RolePortalCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 330,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered
                ? widget.accentColor
                : const Color(0xFF334155),
            width: _isHovered ? 2 : 1,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.accentColor,
                          size: 28,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.badgeText,
                          style: TextStyle(
                            color: widget.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.description,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 16),
                  ...widget.features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: widget.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isHovered
                          ? widget.accentColor
                          : widget.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Launch Station',
                          style: TextStyle(
                            color: _isHovered
                                ? Colors.white
                                : widget.accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: _isHovered
                              ? Colors.white
                              : widget.accentColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}