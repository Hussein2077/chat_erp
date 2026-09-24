import 'package:flutter/foundation.dart';

class MockUser {
  final int id;
  final String username;
  final String displayName;

  const MockUser(this.id, this.username, this.displayName);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class UserSession {
  static const List<MockUser> staticUsers = [
    MockUser(1, 'ahmed', 'Ahmed Mohamed'),
    MockUser(2, 'mohamed', 'Mohamed Ali'),
    MockUser(3, 'ali', 'Ali Hassan'),
    MockUser(4, 'sara', 'Sara Ahmed'),
    MockUser(5, 'omar', 'Omar Yasser'),
  ];

  static final ValueNotifier<MockUser> currentUserNotifier =
      ValueNotifier<MockUser>(staticUsers[0]);

  static MockUser get currentUser => currentUserNotifier.value;

  static void switchUser(MockUser user) {
    currentUserNotifier.value = user;
  }
}
