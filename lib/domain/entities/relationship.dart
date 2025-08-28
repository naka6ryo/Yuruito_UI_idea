enum Relationship { none, passingMaybe, acquaintance, friend, close}


extension RelationshipX on Relationship {
String get label => switch (this) {
Relationship.close => '仲良し',
Relationship.friend => '友達',
Relationship.acquaintance => '顔見知り',
Relationship.passingMaybe => '知り合いかも',
_ => '',
};
}