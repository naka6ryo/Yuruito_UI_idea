enum Relationship { none, acquaintance, friend, close, passingMaybe }


extension RelationshipX on Relationship {
String get label => switch (this) {
Relationship.close => '仲良し',
Relationship.friend => 'ともだち',
Relationship.acquaintance => '顔見知り',
Relationship.passingMaybe => 'すれ違ったかも',
_ => '',
};
}