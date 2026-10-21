import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/epilogue_theme.dart';

class UrlLauncherService {
  static const String discordUrl = 'https://discord.gg/dBSRDDrNUV';
  static const String githubRepoUrl = 'https://github.com/EtherealInsanity/Epilogue';
  static const String githubIssuesUrl = 'https://github.com/EtherealInsanity/Epilogue/issues';
  static const String developerProfileUrl = 'https://github.com/EtherealInsanity';
  static const String githubReleasesUrl = 'https://github.com/EtherealInsanity/Epilogue/releases';

  /// Launches a web URL in an external browser.
  static Future<bool> openUrl(String urlString, {BuildContext? context}) async {
    try {
      final uri = Uri.parse(urlString);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $urlString'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching link: $e'),
            backgroundColor: EpilogueTheme.dangerAccent,
          ),
        );
      }
      return false;
    }
  }

  static Future<bool> openDiscord([BuildContext? context]) => openUrl(discordUrl, context: context);
  static Future<bool> openGithubRepo([BuildContext? context]) => openUrl(githubRepoUrl, context: context);
  static Future<bool> openReportBug([BuildContext? context]) => openUrl(githubIssuesUrl, context: context);
  static Future<bool> openDeveloperProfile([BuildContext? context]) => openUrl(developerProfileUrl, context: context);
  static Future<bool> openReleases([BuildContext? context]) => openUrl(githubReleasesUrl, context: context);
}
