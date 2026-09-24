class MockUser {
  final int id;
  final String username;
  final String displayName;

  const MockUser(this.id, this.username, this.displayName);
}

class UserSession {
  static const List<MockUser> staticUsers = [
    MockUser(1, 'ahmed', 'Ahmed Mohamed'),
    MockUser(2, 'mohamed', 'Mohamed Ali'),
    MockUser(3, 'ali', 'Ali Hassan'),
    MockUser(4, 'sara', 'Sara Ahmed'),
    MockUser(5, 'omar', 'Omar Yasser'),
  ];

  static MockUser currentUser = staticUsers.first;

  static void switchUser(MockUser user) {
    currentUser = user;
  }
}
