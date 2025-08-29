enum Relationship { none, passingMaybe, acquaintance, friend, close }

extension RelationshipX on Relationship {
  String get label => switch (this) {
    Relationship.close => '仲良し',
    Relationship.friend => '友達',
    Relationship.acquaintance => '顔見知り',
    Relationship.passingMaybe => '知り合いかも',
    Relationship.none => '',
  };

  // 親密度レベルを数値で取得
  int get level => switch (this) {
    Relationship.none => 0,
    Relationship.passingMaybe => 1,
    Relationship.acquaintance => 2,
    Relationship.friend => 3,
    Relationship.close => 4,
  };

  // 数値からRelationshipを取得
  static Relationship fromLevel(int level) => switch (level) {
    0 => Relationship.none,
    1 => Relationship.passingMaybe,
    2 => Relationship.acquaintance,
    3 => Relationship.friend,
    4 => Relationship.close,
    _ => Relationship.none,
  };

  // 表示すべきかどうか
  bool get shouldDisplay => this != Relationship.none;
}