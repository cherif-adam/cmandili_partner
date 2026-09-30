import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:google_sign_in/google_sign_in.dart';
import 'models/partner_model.dart';

// Simple User class to replace Firebase User
class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String role;

  User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.role = 'client',
  });

  factory User.fromSupabase(supabase.User user) {
    return User(
      uid: user.id,
      email: user.email,
      displayName: user.userMetadata?['full_name'] as String? ?? user.userMetadata?['name'] as String?,
      photoURL: user.userMetadata?['avatar_url'] as String? ?? user.userMetadata?['picture'] as String?,
      role: user.appMetadata['role'] as String? ?? 'client',
    );
  }
}

class AuthRepository {
  final _supabase = supabase.Supabase.instance.client;
  final _googleSignIn = GoogleSignIn(
    serverClientId: '1047309149711-09in2f2qoce5upqcno61ekuevp2e5hjk.apps.googleusercontent.com',
  );

  // Get current user
  User? get currentUser {
    final user = _supabase.auth.currentUser;
    return user != null ? User.fromSupabase(user) : null;
  }

  // Auth state changes stream
  Stream<User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      return user != null ? User.fromSupabase(user) : null;
    });
  }

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) throw 'Sign in failed';

    return User.fromSupabase(user);
  }

  // Sign up with email, password, name, partner type, and phone
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String name,
    String partnerType,
    String phone,
  ) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, 'partner_type': partnerType},
    );

    final user = response.user;
    if (user == null) throw 'Sign up failed';

    // Insert into partners table and create the corresponding shop record
    try {
      // 1. Create the shop row first, in the generic `vendors` table. The
      //    old code branched between two hardcoded tables, which meant a
      //    florist or pet shop had nowhere to sign up.
      final entityRow = await _supabase
          .from('vendors')
          .insert({
            'name': name,
            'category': vendorCategoryForPartnerType(partnerType),
            'is_open': true,
            'owner_id': user.id,
          })
          .select('id')
          .single();
      final entityId = entityRow['id'] as String;

      // 2. Upsert into partners table with real entity_id and phone
      await _supabase.from('partners').upsert({
        'user_id': user.id,
        'partner_type': partnerType,
        'business_name': name,
        'entity_id': entityId,
        if (phone.isNotEmpty) 'phone': phone,
      }, onConflict: 'user_id');
    } catch (e) {
      // Partners table insert failed — non-blocking, profile can be created later
      debugPrint('Warning: Could not insert into partners table: $e');
    }

    return User.fromSupabase(user);
  }

  // Complete onboarding for Google Sign-in users.
  // Idempotent: if the user already has a partners row (e.g. from a previous
  // attempt that errored mid-way), update it instead of inserting a duplicate.
  Future<void> completeOnboarding(String name, String partnerType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw 'Not logged in';

    final existing = await _supabase
        .from('partners')
        .select('entity_id, partner_type')
        .eq('user_id', user.id)
        .maybeSingle();

    String entityId;
    // UNE boutique par compte, toujours. Le test portait aussi sur le type de
    // partenaire : choisir un autre type creait une SECONDE boutique et
    // laissait la premiere orpheline, avec ses articles, ses commandes et son
    // solde rattaches a une fiche que plus personne n'ouvrait. Des qu'une
    // ligne partners existe avec une boutique, on la renomme -- et on change
    // sa categorie si le type a change.
    if (existing != null && existing['entity_id'] != null) {
      entityId = existing['entity_id'] as String;
      await _supabase
          .from('vendors')
          .update({
            'name': name,
            'category': vendorCategoryForPartnerType(partnerType),
          })
          .eq('id', entityId);
    } else {
      // Create a fresh shop row in the generic vendors table.
      final entityRow = await _supabase
          .from('vendors')
          .insert({
            'name': name,
            'category': vendorCategoryForPartnerType(partnerType),
            'is_open': true,
            'owner_id': user.id,
          })
          .select('id')
          .single();
      entityId = entityRow['id'] as String;
    }

    await _supabase.from('partners').upsert({
      'user_id': user.id,
      'partner_type': partnerType,
      'business_name': name,
      'entity_id': entityId,
    }, onConflict: 'user_id');
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) throw 'No Access Token found.';
      if (idToken == null) throw 'No ID Token found.';

      final response = await _supabase.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) throw 'Google sign in failed';

      return User.fromSupabase(user);
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  // Apple Sign-In is not surfaced in the partner UI — reserved for future use.
  Future<User?> signInWithApple() async {
    throw UnimplementedError('Apple Sign In is not available in the partner app.');
  }

  // Fetch partner profile from partners table
  Future<PartnerProfile?> fetchPartnerProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('partners')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return PartnerProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching partner profile: $e');
      return null;
    }
  }

  /// Enregistre la fiche du partenaire, dans les DEUX tables.
  ///
  /// `partners` est la table du COMPTE partenaire ; `vendors` est la fiche que
  /// le client consulte. Le nom de la boutique vivait dans les deux, et seule
  /// la premiere etait ecrite : un commercant renommait sa boutique, l'app
  /// partenaire affichait le nouveau nom, et le client continuait de voir
  /// l'ancien indefiniment. Releve du 30/09 : 2 boutiques sur 18 portaient
  /// deux noms differents, 5 deux descriptions differentes.
  ///
  /// La photo, elle, arrivait bien -- parce que quelqu'un avait deja recopie
  /// cette seule colonne a la main, dans DEUX ecrans differents. C'est cette
  /// recopie au cas par cas qu'on remplace : un seul chemin d'ecriture, qui
  /// tient les deux tables ensemble.
  ///
  /// `vendors` reste la source de verite cote client. L'ecriture est faite
  /// ici en plus d'un trigger en base (migration 20260930120000), pour que la
  /// correction vaille meme sans lui et que les autres ecrivains --
  /// le tableau de bord admin, un script -- soient couverts par le trigger.
  Future<bool> updatePartnerProfile(PartnerProfile profile) async {
    try {
      await _supabase
          .from('partners')
          .update({
            'business_name': profile.businessName,
            'address': profile.address,
            'phone': profile.phone ?? '',
            'bio': profile.bio ?? '',
            'avatar_url': profile.avatarUrl ?? '',
          })
          .eq('user_id', profile.userId);

      if (profile.entityId.isNotEmpty) {
        // Toujours `vendors` : entityId EST vendors.id, et restaurants /
        // supermarkets ne sont que des vues dessus. Viser une vue selon le
        // type de partenaire envoyait la fiche d'un fleuriste dans
        // `supermarkets`, ou elle ne correspondait a aucune ligne.
        final shopUpdate = <String, dynamic>{
          'name': profile.businessName,
          'description': profile.bio ?? '',
        };
        // Une image vide n'efface pas celle qui est en place : un partenaire
        // qui change juste son nom ne doit pas perdre son logo.
        final avatar = profile.avatarUrl;
        if (avatar != null && avatar.isNotEmpty) {
          shopUpdate['image_url'] = avatar;
        }
        await _supabase
            .from('vendors')
            .update(shopUpdate)
            .eq('id', profile.entityId);
      }
      return true;
    } catch (e) {
      debugPrint('Error updating partner profile: $e');
      return false;
    }
  }

  // Upload Avatar
  Future<String?> uploadAvatar(String path, dynamic fileBytesOrFile) async {
    try {
      await _supabase.storage.from('profiles').upload(
            path,
            fileBytesOrFile,
            fileOptions: const supabase.FileOptions(cacheControl: '3600', upsert: true),
          );
      return _supabase.storage.from('profiles').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }

  // ── Password reset (OTP flow) ──────────────────────────────────────────────

  /// Step 1 — Sends a 6-digit recovery code to [email].
  Future<void> sendPasswordResetOtp(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Step 2 — Verifies the 6-digit [token] and establishes a recovery session.
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: supabase.OtpType.recovery,
    );
  }

  /// Step 3 — Updates the password.  Must follow a successful [verifyPasswordResetOtp].
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      supabase.UserAttributes(password: newPassword),
    );
  }
}
