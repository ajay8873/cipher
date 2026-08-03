import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class GitHubReleaseInfo {
  final String tagName;
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final String htmlUrl;

  GitHubReleaseInfo({
    required this.tagName,
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.htmlUrl,
  });
}

class UpdateCheckerService {
  /// Checks GitHub Releases API for a newer version than current app version
  static Future<GitHubReleaseInfo?> checkForUpdate() async {
    final owner = AppConfig.githubRepoOwner;
    final repo = AppConfig.githubRepoName;

    if (owner.contains("YOUR_GITHUB") || repo.isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github.v3+json',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tagName = (data['tag_name'] as String? ?? '').trim();
        final releaseNotes = (data['body'] as String? ?? 'New version improvements and bug fixes.').trim();
        final htmlUrl = (data['html_url'] as String? ?? '');

        // Find APK asset download URL if present, otherwise fallback to release page or website
        String apkDownloadUrl = htmlUrl;
        if (data['assets'] != null && (data['assets'] as List).isNotEmpty) {
          for (var asset in data['assets']) {
            if ((asset['name'] as String? ?? '').endsWith('.apk')) {
              apkDownloadUrl = asset['browser_download_url'] ?? htmlUrl;
              break;
            }
          }
        }

        final cleanLatestVer = tagName.replaceAll(RegExp(r'^[vV]'), '');
        final currentVer = AppConfig.currentVersion.replaceAll(RegExp(r'^[vV]'), '');

        if (_isNewerVersion(currentVer, cleanLatestVer)) {
          return GitHubReleaseInfo(
            tagName: tagName,
            version: cleanLatestVer,
            releaseNotes: releaseNotes,
            downloadUrl: apkDownloadUrl.isNotEmpty ? apkDownloadUrl : AppConfig.downloadWebsiteUrl,
            htmlUrl: htmlUrl,
          );
        }
      }
    } catch (e) {
      print('Update check failed: $e');
    }
    return null;
  }

  /// Compares semantic version strings (e.g., '1.0.1' > '1.0.0')
  static bool _isNewerVersion(String currentVer, String latestVer) {
    try {
      final currentParts = currentVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = latestVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < latestParts.length; i++) {
        final curr = i < currentParts.length ? currentParts[i] : 0;
        final late = latestParts[i];

        if (late > curr) return true;
        if (late < curr) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Prompts user with a dialog to update the app
  static Future<void> showUpdateDialog(BuildContext context, GitHubReleaseInfo releaseInfo) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded, color: Color(0xFF6C5CE7), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "New Version Available!",
                    style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Version v${releaseInfo.version}",
                    style: const TextStyle(color: Color(0xFF6C5CE7), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "A new version of Cipher is available with updates and improvements:",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2B2B3D) : const Color(0xFFF0F1F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                releaseInfo.releaseNotes.isNotEmpty ? releaseInfo.releaseNotes : "• General performance & security enhancements.",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12, height: 1.4),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Later", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final targetUrl = Uri.parse(releaseInfo.downloadUrl);
              if (await canLaunchUrl(targetUrl)) {
                await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
            label: const Text(
              "Update Now",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
