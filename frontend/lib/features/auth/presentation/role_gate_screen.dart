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
  String? _activeRole; // null = Role Selector, 'ENTRANCE', 'FINANCE', 'ADMIN'
  bool _isVerifyingPin = false;

  Future<void> _promptPinAndEnter(String role, String roleTitle) async {
    final pinController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submitPin() async {
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
              title: Text('Unlock $roleTitle'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the access PIN for $roleTitle (Default PINs: Entrance=1111, Finance=2222, Admin=9999).',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      autofocus: true,
                      onSubmitted: (_) => submitPin(),
                      decoration: InputDecoration(
                        labelText: 'Access PIN',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
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
                  onPressed: _isVerifyingPin ? null : submitPin,
                  child: _isVerifyingPin
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enter Workspace'),
                ),
              ],
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
        title: const Text('Configure Backend API URL'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Render or Local FastAPI URL',
            hintText: 'https://your-service.onrender.com',
            border: OutlineInputBorder(),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeRole == 'ENTRANCE') {
      return EntranceScreen(onSwitchRole: () => setState(() => _activeRole = null));
    }
    if (_activeRole == 'ADMIN') {
      return AdminScreen(onSwitchRole: () => setState(() => _activeRole = null));
    }
    if (_activeRole == 'FINANCE') {
      return FinanceScreen(onSwitchRole: () => setState(() => _activeRole = null));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Internship Seminar Management Portal'),
        actions: [
          TextButton.icon(
            onPressed: _showApiSettingsDialog,
            icon: const Icon(Icons.settings_ethernet, color: Colors.white70),
            label: Text(
              AppConfig.apiBaseUrl,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Select Your Seminar Workspace',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Feature-first portals tailored for Entrance Registration, Finance Collection, and Admin / Execom Oversight.',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _roleCard(
                      title: 'Entrance Desk (User)',
                      subtitle:
                          'Verify online pre-registration, mark attendees Present at the door, and register Walk-In students.',
                      icon: Icons.HowToReg,
                      accent: const Color(0xFF0284C7),
                      onTap: () => _promptPinAndEnter('ENTRANCE', 'Entrance Desk'),
                    ),
                    _roleCard(
                      title: 'Finance Committee',
                      subtitle:
                          'Track Paid vs. Unpaid students, record Cash or GCash payments, and monitor Total Seminar Earnings.',
                      icon: Icons.account_balance_wallet_outlined,
                      accent: const Color(0xFF15803D),
                      onTap: () => _promptPinAndEnter('FINANCE', 'Finance Portal'),
                    ),
                    _roleCard(
                      title: 'Admin & Execom',
                      subtitle:
                          'View Total Pre-Registered, Walk-Ins, Present vs. Absent breakdown, and Create / Edit / Remove attendees.',
                      icon: Icons.admin_panel_settings_outlined,
                      accent: const Color(0xFF7C3AED),
                      onTap: () => _promptPinAndEnter('ADMIN', 'Admin & Execom Portal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 300,
      child: Card(
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 32),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Open Workspace',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 16, color: accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}