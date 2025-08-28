import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../data/services/firebase_settings_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _settingsService = FirebaseSettingsService();
  
  bool _isLoading = true;
  
  // 位置情報設定
  bool _locationEnabled = true;
  String _locationScope = 'friends';
  
  // プライバシー設定
  bool _profileVisible = true;
  bool _allowFriendRequests = true;
  
  // ブロックしたユーザー
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.getUserSettings();
      final blockedUsers = await _settingsService.getBlockedUsers();
      
      setState(() {
        
        // 位置情報設定
        _locationEnabled = settings['locationSharing']?['enabled'] ?? true;
        _locationScope = settings['locationSharing']?['scope'] ?? 'friends';
        
        // プライバシー設定
        _profileVisible = settings['privacy']?['profileVisible'] ?? true;
        _allowFriendRequests = settings['privacy']?['allowFriendRequests'] ?? true;
        
        // ブロックユーザー
        _blockedUsers = blockedUsers;
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定読み込みエラー: $e')),
        );
      }
    }
  }

  Future<void> _updateLocationSettings() async {
    try {
      await _settingsService.updateLocationSharingSettings(
        isEnabled: _locationEnabled,
        shareScope: _locationScope,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置情報設定を更新しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新エラー: $e')),
        );
      }
    }
  }

  Future<void> _updatePrivacySettings() async {
    try {
      await _settingsService.updatePrivacySettings(
        profileVisible: _profileVisible,
        allowFriendRequests: _allowFriendRequests,
        blockedUsers: _blockedUsers.map((u) => u['id'] as String).toList(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プライバシー設定を更新しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新エラー: $e')),
        );
      }
    }
  }

  Future<void> _unblockUser(String userId) async {
    try {
      await _settingsService.unblockUser(userId);
      
      // UIから削除
      setState(() {
        _blockedUsers.removeWhere((user) => user['id'] == userId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ブロックを解除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ブロック解除エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use same phone-like framed layout on web as AppShell
    if (kIsWeb) {
      const aspect = 9 / 19.5;
      const maxPhoneWidth = 384.0;

      return LayoutBuilder(builder: (context, constraints) {
        final maxH = constraints.maxHeight * 0.95;
        var width = min(maxPhoneWidth, constraints.maxWidth);
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }

        return Container(
          color: const Color(0xFFF3F4F6),
          child: Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              clipBehavior: Clip.hardEdge,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0.5,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text(
                    'プライバシー設定',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ),
                body: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildBody()),
              ),
            ),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'プライバシー設定',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 位置情報設定
        _buildSectionHeader('位置情報の共有'),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('位置情報を共有する'),
                subtitle: const Text('他のユーザーにあなたの位置を表示します'),
                value: _locationEnabled,
                onChanged: (value) {
                  setState(() => _locationEnabled = value);
                  _updateLocationSettings();
                },
              ),
              if (_locationEnabled) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '共有範囲',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...LocationSharingScope.values.map((scope) {
                        return RadioListTile<String>(
                          title: Text(scope.label),
                          subtitle: Text(scope.description),
                          value: scope.value,
                          groupValue: _locationScope,
                          onChanged: (value) {
                            setState(() => _locationScope = value!);
                            _updateLocationSettings();
                          },
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // プロフィール表示設定
        _buildSectionHeader('プロフィール表示'),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('プロフィールを公開する'),
                subtitle: const Text('他のユーザーがあなたのプロフィールを見ることができます'),
                value: _profileVisible,
                onChanged: (value) {
                  setState(() => _profileVisible = value);
                  _updatePrivacySettings();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('友達リクエストを受け取る'),
                subtitle: const Text('他のユーザーからの友達申請を受け取ります'),
                value: _allowFriendRequests,
                onChanged: (value) {
                  setState(() => _allowFriendRequests = value);
                  _updatePrivacySettings();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ブロックしたユーザー
        _buildSectionHeader('ブロックしたユーザー'),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: _blockedUsers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'ブロックしたユーザーはいません',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Column(
                  children: _blockedUsers.map((user) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        backgroundImage: user['avatarUrl'] != null ? NetworkImage(user['avatarUrl']) : null,
                        child: user['avatarUrl'] == null ? const Icon(Icons.person, color: Colors.grey) : null,
                      ),
                      title: Text(user['name'] ?? 'Unknown'),
                      trailing: TextButton(
                        onPressed: () => _unblockUser(user['id']),
                        child: const Text('ブロック解除'),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }
}

enum LocationSharingScope {
  all('all', 'すべてのユーザー', '位置情報をすべてのユーザーに公開します'),
  friends('friends', '友達のみ', '友達として登録されたユーザーにのみ公開します'),
  close('close', '親しい友達のみ', '親しい友達として設定されたユーザーにのみ公開します'),
  none('none', '非公開', '位置情報を誰にも公開しません');

  const LocationSharingScope(this.value, this.label, this.description);
  
  final String value;
  final String label;
  final String description;
}
