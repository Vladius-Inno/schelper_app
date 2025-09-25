import 'authorized_api_client.dart';

class SubjectInfo {
  final int id;
  final String name;
  SubjectInfo({required this.id, required this.name});
}

class SubjectsService {
  final AuthorizedApiClient _client;
  SubjectsService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient();

  Future<List<SubjectInfo>> fetchSubjects() async {
    final data = await _client.getAny('/subjects');
    if (data is List) {
      return data
          .map(
            (e) => SubjectInfo(
              id: e['id'] as int,
              name: (e['name'] as String).trim(),
            ),
          )
          .toList();
    }
    final list = (data is Map<String, dynamic>)
        ? data['data'] as List<dynamic>?
        : null;
    if (list == null) return [];
    return list
        .map(
          (e) => SubjectInfo(
            id: e['id'] as int,
            name: (e['name'] as String).trim(),
          ),
        )
        .toList();
  }
}
