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
  final String? releasePageUrl;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    this.downloadUrl,
    this.releasePageUrl,
    this.errorMessage,
  });
}

class UpdateCheckerService {
  static const String currentVersion = '2.0.4+204';
  static const String currentSemantic = '2.0.4';
  static const String repoOwner = 'EtherealInsanity';
  static const String repoName = 'Epilogue';

  static Future<UpdateCheckResult> checkForUpdates() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    const defaultReleaseUrl = 'https://github.com/$repoOwner/$repoName/releases';

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
        final htmlUrl = json['html_url'] as String? ?? defaultReleaseUrl;

        // Find primary download URL based on target platform
        String? directAssetUrl;
        if (json['assets'] is List) {
          final assets = json['assets'] as List;
          for (final a in assets) {
            if (a is Map<String, dynamic>) {
              final name = (a['name'] as String? ?? '').toLowerCase();
              final dl = a['browser_download_url'] as String?;
              if (dl == null) continue;

              if (Platform.isWindows && (name.endsWith('.zip') || name.endsWith('.exe')) && name.contains('windows')) {
                directAssetUrl = dl;
                break;
              } else if (Platform.isLinux && (name.endsWith('.tar.gz') || name.endsWith('.zip')) && name.contains('linux')) {
                directAssetUrl = dl;
                break;
              } else if (Platform.isAndroid && name.endsWith('.apk')) {
                directAssetUrl ??= dl;
                if (name.contains('arm64') || name.contains('universal')) {
                  directAssetUrl = dl;
                  break;
                }
              }
            }
          }
        }

        final isNewer = _compareVersions(tagName, currentSemantic) > 0;

        return UpdateCheckResult(
          status: isNewer ? UpdateStatus.updateAvailable : UpdateStatus.upToDate,
          currentVersion: currentVersion,
          latestVersion: tagName,
          releaseNotes: bodyText,
          downloadUrl: directAssetUrl ?? htmlUrl,
          releasePageUrl: htmlUrl,
        );
      } else if (response.statusCode == 404) {
        return const UpdateCheckResult(
          status: UpdateStatus.upToDate,
          currentVersion: currentVersion,
          latestVersion: currentSemantic,
          releaseNotes: 'You are running the latest official build of Epilogue.',
          downloadUrl: defaultReleaseUrl,
          releasePageUrl: defaultReleaseUrl,
        );
      } else if (response.statusCode == 403) {
        return const UpdateCheckResult(
          status: UpdateStatus.error,
          currentVersion: currentVersion,
          latestVersion: currentSemantic,
          releaseNotes: '',
          downloadUrl: defaultReleaseUrl,
          releasePageUrl: defaultReleaseUrl,
          errorMessage: 'GitHub API rate limit exceeded. You can check releases directly on GitHub.',
        );
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          currentVersion: currentVersion,
          latestVersion: currentSemantic,
          releaseNotes: '',
          downloadUrl: defaultReleaseUrl,
          releasePageUrl: defaultReleaseUrl,
          errorMessage: 'HTTP ${response.statusCode}: Unable to reach release server.',
        );
      }
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: currentVersion,
        latestVersion: currentSemantic,
        releaseNotes: '',
        downloadUrl: defaultReleaseUrl,
        releasePageUrl: defaultReleaseUrl,
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
