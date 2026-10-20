import 'package:supabase_flutter/supabase_flutter.dart';

/// The orders behind the "Rapports" screen.
class ReportsRepository {
  final _supabase = Supabase.instance.client;

  /// The shop's orders created since [start]: total, delivery fee, status and
  /// date only. [filterColumn] is `restaurant_id` or `supermarket_id`.
  Future<List<dynamic>> ordersSince({
    required String filterColumn,
    required String entityId,
    required DateTime start,
  }) async {
    final rows = await _supabase
        .from('orders')
        .select('total, delivery_fee, status, created_at')
        .eq(filterColumn, entityId)
        .gte('created_at', start.toIso8601String());
    return rows as List;
  }
}
