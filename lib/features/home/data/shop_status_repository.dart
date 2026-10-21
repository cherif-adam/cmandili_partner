import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The shop's open / closed switch, its opening hours and the platform's
/// commission rate, as the dashboard reads and writes them. Errors are left
/// to the caller.
class ShopStatusRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<bool?> fetchIsOpen(String entityId) async {
    final row = await _supabase
        .from('vendors').select('is_open').eq('id', entityId).single();
    return row['is_open'] as bool?;
  }

  Future<void> setIsOpen(String entityId, bool isOpen) async {
    await _supabase
        .from('vendors').update({'is_open': isOpen}).eq('id', entityId);
  }

  /// auto_close_enabled, opening_time and closing_time of the shop.
  Future<Map<String, dynamic>> fetchSchedule(String entityId) async {
    return _supabase
        .from('vendors')
        .select('auto_close_enabled, opening_time, closing_time')
        .eq('id', entityId)
        .single();
  }

  /// [openingTime] and [closingTime] as HH:MM:SS, or null when not set.
  Future<void> saveSchedule(
    String entityId, {
    required bool autoCloseEnabled,
    required String? openingTime,
    required String? closingTime,
  }) async {
    await _supabase.from('vendors').update({
      'auto_close_enabled': autoCloseEnabled,
      'opening_time': openingTime,
      'closing_time': closingTime,
    }).eq('id', entityId);
  }

  /// The raw setting_value of default_restaurant_commission_rate, or null
  /// when the row is missing.
  Future<Object?> fetchDefaultCommissionRate() async {
    final row = await _supabase
        .from('global_settings')
        .select('setting_value')
        .eq('setting_key', 'default_restaurant_commission_rate')
        .maybeSingle();
    return row?['setting_value'];
  }
}

final shopStatusRepositoryProvider =
    Provider<ShopStatusRepository>((ref) => ShopStatusRepository());
