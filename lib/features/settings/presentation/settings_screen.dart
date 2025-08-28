import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/state/auth_controller.dart';
import 'profile_settings_screen.dart';
import 'account_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // light grey background like mock
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('設定', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Group(
                title: 'プロフィール設定', 
                items: ['プロフィール編集'],
                onTap: (label) {
                  if (label == 'プロフィール編集') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
                    );
                  }
                },
              ),
              // プライバシーモード・位置設定は削除
              _Group(
                title: 'アカウント設定', 
                items: ['アカウント管理'],
                onTap: (label) {
                  if (label == 'アカウント管理') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                    );
                  }
                },
              ),
              _Group(
                title: 'その他', 
                items: ['ログアウト'], 
                onTap: (label) async {
                  if (label == 'ログアウト') {
                    final nav = Navigator.of(context);
                    await ref.read(authControllerProvider.notifier).logout();
                    nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    const phoneWidthThreshold = 900.0;
    final isWeb = kIsWeb;
    final isNarrow = screenWidth < phoneWidthThreshold;

    // On web wide viewports, render inside the phone-like framed container used by AppShell.
    if (isWeb && !isNarrow) {
      const aspect = 9 / 19.5;
      const maxPhoneWidth = 384.0;
      return LayoutBuilder(builder: (context, constraints) {
        final maxH = constraints.maxHeight * 0.95;
        var width = math.min(maxPhoneWidth, constraints.maxWidth);
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }

        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            clipBehavior: Clip.hardEdge,
            child: scaffold,
          ),
        );
      });
    }

    // Narrow web viewports and non-web platforms use full-screen scaffold
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: scaffold.appBar,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 48),
            child: SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: scaffold.body!),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<String> items;
  final void Function(String label)? onTap;
  const _Group({required this.title, required this.items, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    items[i],
                    style: TextStyle(
                      fontSize: 16,
                      color: items[i] == 'ログアウト' ? Colors.red : null,
                    ),
                  ),
                  trailing: items[i] == 'ログアウト' ? null : const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                  onTap: onTap == null ? null : () => onTap!(items[i]),
                ),
                if (i < items.length - 1)
                  const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
