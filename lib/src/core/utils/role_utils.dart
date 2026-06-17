/// Centralizes all role string constants and helper checks.
/// Add new roles here — never use raw strings elsewhere in the codebase.
class AppRole {
  AppRole._();

  static const String player = 'player';
  static const String coach = 'coach';
  static const String admin = 'admin';
  static const String owner = 'owner';
  static const String gymAdmin = 'gym_admin';

  /// App-level super admin — can create/manage all gyms.
  /// Set manually in Firestore; never assigned through signup flow.
  static const String superAdmin = 'super_admin';

  /// All roles that may access admin/management features.
  static const Set<String> privilegedRoles = {coach, admin, owner, gymAdmin};

  /// Returns true if the given role can access admin/management screens.
  static bool isPrivileged(String? role) =>
      role != null && privilegedRoles.contains(role.toLowerCase());

  /// Returns true if this is the app-level super admin.
  static bool isSuperAdmin(String? role) =>
      role != null && role.toLowerCase() == superAdmin;

  /// Returns true if the given role is a player (regular gym member).
  static bool isPlayer(String? role) => role != null && role.toLowerCase() == player;
}
