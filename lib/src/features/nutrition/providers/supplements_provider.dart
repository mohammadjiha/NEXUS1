import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/supplements_repository.dart';
import '../domain/models/supplement_model.dart';

final supplementsRoutineProvider = StreamProvider<List<SupplementItem>>((ref) {
  final repo = ref.watch(supplementsRepositoryProvider);
  return repo.watchRoutine();
});

final supplementDailyLogProvider = StreamProvider.family<SupplementDailyLog, String>((ref, date) {
  final repo = ref.watch(supplementsRepositoryProvider);
  return repo.watchDailyLog(date);
});
