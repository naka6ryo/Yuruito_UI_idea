import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/relationship.dart';
import '../../../domain/entities/user.dart';
import '../../profile/presentation/other_user_profile_screen.dart';


class UserCard extends StatefulWidget {
final UserEntity user;
const UserCard({super.key, required this.user});

@override
State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userPhotoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPhoto();
  }

  Future<void> _loadUserPhoto() async {
    try {
      // profiles/{uid}.photoUrl を最優先で取得
      final profileDoc = await _firestore.collection('profiles').doc(widget.user.id).get();
      if (profileDoc.exists) {
        final profileData = profileDoc.data();
        final photoUrl = profileData?['photoUrl'] as String?;
        
        // Firebase StorageのURLは無視し、アセットパスのみを使用
        if (photoUrl != null && !photoUrl.startsWith('http')) {
          setState(() {
            _userPhotoUrl = photoUrl;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // profilesにない場合は、users/{uid}.photoUrl を取得
        final userDoc = await _firestore.collection('users').doc(widget.user.id).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final photoUrl = (userData?['photoUrl'] ?? userData?['avatarUrl']) as String?;
          
          // Firebase StorageのURLは無視し、アセットパスのみを使用
          if (photoUrl != null && !photoUrl.startsWith('http')) {
            setState(() {
              _userPhotoUrl = photoUrl;
              _isLoading = false;
            });
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ ユーザー画像読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

@override
Widget build(BuildContext context) {
return Card(
child: ListTile(
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OtherUserProfileScreen(user: widget.user),
    ),
  );
},
leading: _buildAvatar(),
	title: Text(widget.user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
	subtitle: Text(
		_subtitle(widget.user),
		maxLines: 2,
		overflow: TextOverflow.ellipsis,
	),
trailing: _badge(widget.user.relationship),
),
);
}


String _subtitle(UserEntity u) {
if (u.relationship == Relationship.close) return '最近カフェ巡りにはまってます☕';
if (u.relationship == Relationship.friend) return '週末はよく散歩してます。';
return u.bio;
}


Color _getRelationshipColor(Relationship relationship) {
  switch (relationship) {
    case Relationship.close:
      return const Color(0xFFA78BFA); // 紫
    case Relationship.friend:
      return const Color(0xFF86EFAC); // 緑
    case Relationship.acquaintance:
      return const Color(0xFFFDBA74); // オレンジ
    case Relationship.passingMaybe:
      return const Color(0xFFF9A8D4); // ピンク
    case Relationship.none:
      return Colors.grey;
  }
}

Widget? _badge(Relationship r) {
	// レベル0（none）の場合はタグを表示しない
	if (!r.shouldDisplay) return null;
	
	final label = r.label;
	if (label.isEmpty) return null;
	Color color = _getRelationshipColor(r);
	final int argb = color.toARGB32();
	final int red = (argb >> 16) & 0xFF;
	final int green = (argb >> 8) & 0xFF;
	final int blue = argb & 0xFF;
	return Container(
		padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
		decoration: BoxDecoration(
			color: Color.fromRGBO(red, green, blue, 0.1),
			borderRadius: BorderRadius.circular(12),
		),
		child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
	);
}

  Widget _buildAvatar() {
    if (_userPhotoUrl != null) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: _getRelationshipColor(widget.user.relationship),
        backgroundImage: AssetImage(_userPhotoUrl!),
        child: null,
      );
    }
    
    // デフォルトの文字アイコン
    return CircleAvatar(
      radius: 24,
      backgroundColor: _getRelationshipColor(widget.user.relationship),
      child: Text(
        widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}