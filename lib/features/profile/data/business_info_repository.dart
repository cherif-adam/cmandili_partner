import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The shop's logo: reading the current one and uploading a new one.
class BusinessInfoRepository {
  final _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// The shop's `vendors` row, `image_url` only. [entityId] IS vendors.id;
  /// restaurants/supermarkets are only views over it, so selecting a view by
  /// partner type looked a florist's shop up in `supermarkets` and came back
  /// empty.
  Future<Map<String, dynamic>?> vendorLogoRow(String entityId) {
    return _supabase
        .from('vendors')
        .select('image_url')
        .eq('id', entityId)
        .maybeSingle();
  }

  /// Uploads [logo] to the `items` bucket and returns the public URL.
  /// Reuses `items` (already public) instead of creating a new bucket.
  Future<String> uploadLogo(String entityId, File logo) async {
    final ext = logo.path.split('.').last.toLowerCase();
    final path = '$entityId-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _supabase.storage.from('items').upload(
          path,
          logo,
          fileOptions: const FileOptions(upsert: true),
        );
    return _supabase.storage.from('items').getPublicUrl(path);
  }
}
