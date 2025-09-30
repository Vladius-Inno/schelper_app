import '../models/homework_upload.dart';
import 'authorized_api_client.dart';

class HomeworkService {
  final AuthorizedApiClient _client;

  HomeworkService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient();

  Future<List<HomeworkUploadResult>> submitHomework({
    required int childId,
    required String text,
    DateTime? date,
  }) async {
    final payload = <String, dynamic>{
      'child_id': childId,
      'text': text,
      if (date != null) 'date': _formatDate(date),
    };
    final data = await _client.postAny('/import/homework', payload);
    List<dynamic>? list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final inner = map['data'];
      if (inner is List) {
        list = inner;
      }
    }
    if (list == null) {
      return [];
    }
    return list
        .map(
          (item) =>
              HomeworkUploadResult.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
