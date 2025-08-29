import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/relationship.dart';
import '../../../domain/entities/user.dart';
import '../../profile/presentation/other_user_profile_screen.dart';


class UserCard extends StatefulWidget {
final UserEntity user;
final int? actualIntimacyLevel; // 実際の親密度レベル
const UserCard({
  super.key, 
  required this.user, 
  this.actualIntimacyLevel,
});

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
trailing: _badge(widget.actualIntimacyLevel),
),
);
}


String _subtitle(UserEntity u) {
if (u.relationship == Relationship.close) return '最近カフェ巡りにはまってます☕';
if (u.relationship == Relationship.friend) return '週末はよく散歩してます。';
return u.bio;
}




Widget? _badge(int? actualLevel) {
	// 実際の親密度レベルがnullまたは0の場合はタグを表示しない
	if (actualLevel == null || actualLevel <= 0) return null;
	
	// レベルに応じたラベルと色を取得
	String label;
	Color color;
	
	switch (actualLevel) {
		case 4:
			label = '仲良し';
			color = const Color(0xFF9B5DE5); // 紫
			break;
		case 3:
			label = '友達';
			color = const Color(0xFFF15BB5); // ピンク
			break;
		case 2:
			label = '顔見知り';
			color = const Color(0xFFFEE440); // 黄
			break;
		case 1:
			label = '知り合いかも';
			color = const Color(0xFF00F5D4); // シアン/ティール
			break;
		default:
			return null;
	}
	
	final int argb = color.toARGB32();
	final int red = (argb >> 16) & 0xFF;
	final int green = (argb >> 8) & 0xFF;
	final int blue = argb & 0xFF;
	return Container(
		padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
		decoration: BoxDecoration(
			color: (actualLevel == 3 || actualLevel == 4) ? Color.fromRGBO(red, green, blue, 0.1) : Color.fromRGBO(red, green, blue, 0.7),
			borderRadius: BorderRadius.circular(12),
		),
		child: Text(label, style: TextStyle(color: (actualLevel == 1 || actualLevel == 2) ? Colors.white : color, fontWeight: FontWeight.w600, fontSize: 12)),
	);
}

  Color _getIntimacyLevelColor(int? level) {
    switch (level) {
      case 4:
        return const Color(0xFF9B5DE5); // レベル4: 仲良し
      case 3:
        return const Color(0xFFF15BB5); // レベル3: 友達
      case 2:
        return const Color(0xFFFEE440); // レベル2: 顔見知り
      case 1:
        return const Color(0xFF00F5D4); // レベル1: 知り合いかも
      default:
        return Colors.grey; // デフォルトまたはレベル0
    }
  }

  Widget _buildAvatar() {
    final avatarColor = _getIntimacyLevelColor(widget.actualIntimacyLevel);

    if (_userPhotoUrl != null) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: avatarColor,
        backgroundImage: AssetImage(_userPhotoUrl!),
        child: null,
      );
    }
    
    // デフォルトの文字アイコン
    return CircleAvatar(
      radius: 24,
      backgroundColor: avatarColor,
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