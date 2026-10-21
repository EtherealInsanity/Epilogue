import 'dart:convert';
import 'dart:io';

enum UpdateStatus {
  upToDate,
  updateAvailable,
  error,
}

class UpdateCheckResult {
  final UpdateStatus status;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String? downloadUrl;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    this.downloadUrl,
    this.errorMessage,
  });
}

class UpdateCheckerService {
  static const String currentVersion = '2.0.3+203';
  static const String currentSemantic = '2.0.3';
  static const String repoOwner = 'EtherealInsanity';
  static const String repoName = 'Epilogue';

  static Future<UpdateCheckResult> checkForUpdates() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);

    try {
      final request = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest'),
      );
      request.headers.set('User-Agent', 'Epilogue-App/$currentVersion');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        final tagName = (json['tag_name'] as String? ?? 'v1.0.0').replaceAll('v', '').trim();
        final bodyText = json['body'] as String? ?? 'No release notes provided.';
        final htmlUrl = json['html_url'] as String? ?? 'https://github.com/$repoOwner/$repoName/releases';

        final isNewer = _compareVersions(tagName, currentSemantic) > 0;

        return UpdateCheckResult(
          status: isNewer ? UpdateStatus.updateAvailable : UpdateStatus.upToDate,
          currentVersion: currentVersion,
          latestVersion: tagName,
          releaseNotes: bodyText,
          downloadUrl: htmlUrl,
        );
      } else if (response.statusCode == 404) {
        // Repository or release is not yet public; app is on latest developer build
        return const UpdateCheckResult(
          status: UpdateStatus.upToDate,
          currentVersion: currentVersion,
          latestVersion: currentSemantic,
          releaseNotes: 'You are running the latest official build of Epilogue.',
        );
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          currentVersion: currentVersion,
          latestVersion: currentSemantic,
          releaseNotes: '',
          errorMessage: 'HTTP ${response.statusCode}: Unable to reach release server.',
        );
      }
    } catch (e) {
      // Offline fallback: graceful handling
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: currentVersion,
        latestVersion: currentSemantic,
        releaseNotes: '',
        errorMessage: 'Network error: Please check your internet connection ($e)',
      );
    } finally {
      client.close();
    }
  }

  static int _compareVersions(String v1, String v2) {
    final p1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final p2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final val1 = i < p1.length ? p1[i] : 0;
      final val2 = i < p2.length ? p2[i] : 0;
      if (val1 > val2) return 1;
      if (val1 < val2) return -1;
    }
    return 0;
  }
}
