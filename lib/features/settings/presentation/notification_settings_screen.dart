import 'package:flutter/material.dart';
import '../../../data/services/firebase_settings_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _settingsService = FirebaseSettingsService();
  
  bool _isLoading = true;
  
  // 通知設定
  bool _pushEnabled = true;
  bool _locationUpdates = true;
  bool _chatMessages = true;
  bool _friendRequests = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.getUserSettings();
      
      setState(() {
        _pushEnabled = settings['notifications']?['pushEnabled'] ?? true;
        _locationUpdates = settings['notifications']?['locationUpdates'] ?? true;
        _chatMessages = settings['notifications']?['chatMessages'] ?? true;
        _friendRequests = settings['notifications']?['friendRequests'] ?? true;
        
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

  Future<void> _updateNotificationSettings() async {
    try {
      await _settingsService.updateNotificationSettings(
        pushEnabled: _pushEnabled,
        locationUpdates: _locationUpdates,
        chatMessages: _chatMessages,
        friendRequests: _friendRequests,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知設定を更新しました')),
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

  @override
  Widget build(BuildContext context) {
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
          '通知設定',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // プッシュ通知全般
                  _buildSectionHeader('プッシュ通知'),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        SwitchListTile(
                          leading: Icon(
                            Icons.notifications,
                            color: _pushEnabled ? Colors.blue : Colors.grey,
                          ),
                          title: const Text('プッシュ通知を受け取る'),
                          subtitle: const Text('アプリからの通知を受け取ります'),
                          value: _pushEnabled,
                          onChanged: (value) {
                            setState(() => _pushEnabled = value);
                            _updateNotificationSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 個別通知設定
                  _buildSectionHeader('個別通知設定'),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.location_on,
                            color: (_pushEnabled && _locationUpdates) ? Colors.green : Colors.grey,
                          ),
                          title: const Text('位置情報の更新'),
                          subtitle: const Text('友達の位置情報が更新された時に通知'),
                          trailing: Switch(
                            value: _pushEnabled && _locationUpdates,
                            onChanged: _pushEnabled ? (value) {
                              setState(() => _locationUpdates = value);
                              _updateNotificationSettings();
                            } : null,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.chat,
                            color: (_pushEnabled && _chatMessages) ? Colors.blue : Colors.grey,
                          ),
                          title: const Text('チャットメッセージ'),
                          subtitle: const Text('新しいメッセージを受信した時に通知'),
                          trailing: Switch(
                            value: _pushEnabled && _chatMessages,
                            onChanged: _pushEnabled ? (value) {
                              setState(() => _chatMessages = value);
                              _updateNotificationSettings();
                            } : null,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.person_add,
                            color: (_pushEnabled && _friendRequests) ? Colors.orange : Colors.grey,
                          ),
                          title: const Text('友達リクエスト'),
                          subtitle: const Text('新しい友達申請を受信した時に通知'),
                          trailing: Switch(
                            value: _pushEnabled && _friendRequests,
                            onChanged: _pushEnabled ? (value) {
                              setState(() => _friendRequests = value);
                              _updateNotificationSettings();
                            } : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 通知時間設定
                  _buildSectionHeader('通知時間'),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.schedule, color: Colors.purple),
                          title: const Text('おやすみモード'),
                          subtitle: const Text('指定した時間は通知を停止します'),
                          trailing: const Text('準備中', style: TextStyle(color: Colors.grey)),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('おやすみモード機能は準備中です')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 詳細設定
                  _buildSectionHeader('詳細設定'),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.vibration, color: Colors.red),
                          title: const Text('バイブレーション'),
                          subtitle: const Text('通知時にバイブレーションで知らせます'),
                          trailing: Switch(
                            value: _pushEnabled,
                            onChanged: null, // システム設定に依存
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('バイブレーション設定は端末の設定から変更してください')),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.volume_up, color: Colors.indigo),
                          title: const Text('通知音'),
                          subtitle: const Text('通知音を変更します'),
                          trailing: const Text('デフォルト', style: TextStyle(color: Colors.grey)),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('通知音設定は端末の設定から変更してください')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 現在の通知設定サマリー
                  _buildSectionHeader('現在の設定'),
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSettingSummary('プッシュ通知', _pushEnabled),
                          const SizedBox(height: 8),
                          _buildSettingSummary('位置情報更新', _pushEnabled && _locationUpdates),
                          const SizedBox(height: 8),
                          _buildSettingSummary('チャットメッセージ', _pushEnabled && _chatMessages),
                          const SizedBox(height: 8),
                          _buildSettingSummary('友達リクエスト', _pushEnabled && _friendRequests),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildSettingSummary(String label, bool isEnabled) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isEnabled ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isEnabled ? 'ON' : 'OFF',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isEnabled ? Colors.green : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
