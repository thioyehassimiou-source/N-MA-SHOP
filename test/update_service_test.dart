import 'package:flutter_test/flutter_test.dart';
import 'package:nmashop/core/services/update_service.dart';

void main() {
  test('UpdateService queries GitHub API and returns live release info', () async {
    print('Testing UpdateService.checkForUpdates()...');
    final info = await UpdateService.checkForUpdates();

    print('=== UPDATE SERVICE RESULT ===');
    print('Current Version: ${info.currentVersion}');
    print('Build Number: ${info.buildNumber}');
    print('Latest Version on GitHub: ${info.latestVersion}');
    print('Has Update Available: ${info.hasUpdate}');
    print('Download URL: ${info.downloadUrl}');
    print('Release Notes Preview:\n${info.releaseNotes.split('\n').take(5).join('\n')}');

    expect(info.currentVersion, equals('1.1.9'));
    expect(info.downloadUrl, contains('github.com'));
  });
}
