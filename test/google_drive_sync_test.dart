import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epilogue/models/book_info.dart';
import 'package:epilogue/services/data_sync_service.dart';
import 'package:epilogue/services/google_drive_sync_service.dart';
import 'package:epilogue/services/storage_service.dart';
import 'package:epilogue/widgets/dialog_google_drive_sync.dart';

/// In-memory mock for Google Drive Files API
class FakeFilesResource implements drive.FilesResource {
  final Map<String, drive.File> files = {};
  final Map<String, Uint8List> fileData = {};
  int _idCounter = 1;

  @override
  Future<drive.File> create(
    drive.File request, {
    bool? enforceSingleParent,
    bool? ignoreDefaultVisibility,
    String? includeLabels,
    String? includePermissionsForView,
    bool? keepRevisionForever,
    String? ocrLanguage,
    bool? supportsAllDrives,
    bool? supportsTeamDrives,
    bool? useContentAsIndexableText,
    String? $fields,
    drive.UploadOptions uploadOptions = drive.UploadOptions.defaultOptions,
    drive.Media? uploadMedia,
  }) async {
    final id = 'fake_id_${_idCounter++}';
    final file = drive.File()
      ..id = id
      ..name = request.name
      ..mimeType = request.mimeType
      ..parents = request.parents
      ..modifiedTime = DateTime.now();

    if (uploadMedia != null) {
      final bytes = <int>[];
      await for (final chunk in uploadMedia.stream) {
        bytes.addAll(chunk);
      }
      fileData[id] = Uint8List.fromList(bytes);
      file.size = bytes.length.toString();
    }

    files[id] = file;
    return file;
  }

  @override
  Future<drive.File> update(
    drive.File request,
    String fileId, {
    String? addParents,
    bool? enforceSingleParent,
    String? includeLabels,
    String? includePermissionsForView,
    bool? keepRevisionForever,
    String? ocrLanguage,
    String? removeParents,
    bool? supportsAllDrives,
    bool? supportsTeamDrives,
    bool? useContentAsIndexableText,
    String? $fields,
    drive.UploadOptions uploadOptions = drive.UploadOptions.defaultOptions,
    drive.Media? uploadMedia,
  }) async {
    final file = files[fileId] ?? (drive.File()..id = fileId);
    if (request.name != null) file.name = request.name;
    file.modifiedTime = DateTime.now();

    if (uploadMedia != null) {
      final bytes = <int>[];
      await for (final chunk in uploadMedia.stream) {
        bytes.addAll(chunk);
      }
      fileData[fileId] = Uint8List.fromList(bytes);
      file.size = bytes.length.toString();
    }

    files[fileId] = file;
    return file;
  }

  @override
  Future<drive.FileList> list({
    String? corpora,
    String? corpus,
    String? driveId,
    bool? includeItemsFromAllDrives,
    String? includeLabels,
    String? includePermissionsForView,
    bool? includeTeamDriveItems,
    String? orderBy,
    int? pageSize,
    String? pageToken,
    String? q,
    String? spaces,
    bool? supportsAllDrives,
    bool? supportsTeamDrives,
    String? teamDriveId,
    String? $fields,
  }) async {
    var matched = files.values.toList();

    if (q != null) {
      if (q.contains("name = '")) {
        final match = RegExp(r"name = '([^']+)'").firstMatch(q);
        if (match != null) {
          final targetName = match.group(1);
          matched = matched.where((f) => f.name == targetName).toList();
        }
      }
      if (q.contains("mimeType = 'application/vnd.google-apps.folder'")) {
        matched = matched
            .where((f) => f.mimeType == 'application/vnd.google-apps.folder')
            .toList();
      }
      if (q.contains("in parents")) {
        final match = RegExp(r"'([^']+)' in parents").firstMatch(q);
        if (match != null) {
          final parentId = match.group(1);
          matched = matched
              .where((f) => f.parents != null && f.parents!.contains(parentId))
              .toList();
        }
      }
    }

    return drive.FileList()..files = matched;
  }

  @override
  Future<Object> get(
    String fileId, {
    bool? acknowledgeAbuse,
    String? includeLabels,
    String? includePermissionsForView,
    bool? supportsAllDrives,
    bool? supportsTeamDrives,
    String? $fields,
    drive.DownloadOptions downloadOptions = drive.DownloadOptions.metadata,
  }) async {
    if (downloadOptions == drive.DownloadOptions.fullMedia) {
      final data = fileData[fileId] ?? Uint8List(0);
      return drive.Media(Stream.value(data), data.length);
    }
    return files[fileId] ?? (drive.File()..id = fileId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDriveApi implements drive.DriveApi {
  @override
  final FakeFilesResource files = FakeFilesResource();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late DataSyncService dataSyncService;
  late FakeDriveApi fakeDriveApi;
  late GoogleDriveSyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = await StorageService.initialize();
    dataSyncService = DataSyncService(storageService);
    fakeDriveApi = FakeDriveApi();
    syncService = GoogleDriveSyncService(
      storageService: storageService,
      dataSyncService: dataSyncService,
      injectedDriveApi: fakeDriveApi,
    );
  });

  group('GoogleDriveSyncService Folder & Discovery Tests', () {
    test('getOrCreateFolder creates folder when not existing and reuses when existing', () async {
      final folderId1 = await syncService.getOrCreateFolder(
        fakeDriveApi,
        GoogleDriveSyncService.rootFolderName,
      );
      expect(folderId1, isNotNull);

      // Call again: should return the same folder ID
      final folderId2 = await syncService.getOrCreateFolder(
        fakeDriveApi,
        GoogleDriveSyncService.rootFolderName,
      );
      expect(folderId2, equals(folderId1));
    });

    test('findFile returns null when missing and File when present', () async {
      final missing = await syncService.findFile(fakeDriveApi, 'non_existent.json');
      expect(missing, isNull);

      final rootId = await syncService.getOrCreateFolder(fakeDriveApi, 'Root');
      await fakeDriveApi.files.create(
        drive.File()
          ..name = 'test.json'
          ..parents = [rootId!],
        uploadMedia: drive.Media(Stream.value(utf8.encode('{}')), 2),
      );

      final found = await syncService.findFile(fakeDriveApi, 'test.json', parentId: rootId);
      expect(found, isNotNull);
      expect(found!.name, equals('test.json'));
    });
  });

  group('GoogleDriveSyncService Push & Pull Synchronization Tests', () {
    test('pushBackupAndLibrary creates root folder, metadata JSON, and syncs novels', () async {
      // Create a temporary EPUB file for test
      final tempDir = await Directory.systemTemp.createTemp('epilogue_test_');
      final testEpub = File('${tempDir.path}/test_novel.epub');
      await testEpub.writeAsString('EPUB_CONTENT_DATA');

      final book = BookInfo(
        id: 'book_orv',
        title: 'Omniscient Reader',
        author: 'Sing Shong',
        filePath: testEpub.path,
        totalChapters: 551,
        lastReadChapterIndex: 12,
        lastReadProgressPercent: 50.0,
      );
      await storageService.saveBooks([book]);

      final pushResult = await syncService.pushBackupAndLibrary();
      expect(pushResult.success, isTrue);
      expect(pushResult.booksSynced, equals(1));
      expect(pushResult.booksSkipped, equals(0));

      // Verify cloud state
      final rootId = await syncService.getOrCreateFolder(fakeDriveApi, GoogleDriveSyncService.rootFolderName);
      expect(rootId, isNotNull);

      final backupFile = await syncService.findFile(
        fakeDriveApi,
        GoogleDriveSyncService.backupFileName,
        parentId: rootId,
      );
      expect(backupFile, isNotNull);

      // Verify second push is idempotent (skips already uploaded book with matching size)
      final secondPush = await syncService.pushBackupAndLibrary();
      expect(secondPush.success, isTrue);
      expect(secondPush.booksSynced, equals(0));
      expect(secondPush.booksSkipped, equals(1));

      tempDir.deleteSync(recursive: true);
    });

    test('pullBackupAndLibrary downloads snapshot and merges reading telemetry', () async {
      // Seed cloud with backup
      final rootId = await syncService.getOrCreateFolder(fakeDriveApi, GoogleDriveSyncService.rootFolderName);
      final testBackup = {
        'epilogue_version': '2.0.4',
        'exported_at': DateTime.now().millisecondsSinceEpoch,
        'books': [
          {
            'id': 'cloud_book_1',
            'title': 'The World After the Fall',
            'author': 'Sing Shong',
            'filePath': '/non/existent/path/fall.epub',
            'totalChapters': 100,
            'lastReadChapterIndex': 5,
            'lastReadProgressPercent': 25.0,
          }
        ],
        'bookmarks': [
          {
            'id': 'bm_cloud_1',
            'bookId': 'cloud_book_1',
            'chapterIndex': 5,
            'paragraphIndex': 1,
            'textSnippet': 'A tower appeared in the sky.',
            'createdAt': 1700000000000,
          }
        ],
      };

      final backupBytes = utf8.encode(jsonEncode(testBackup));
      await fakeDriveApi.files.create(
        drive.File()
          ..name = GoogleDriveSyncService.backupFileName
          ..parents = [rootId!],
        uploadMedia: drive.Media(Stream.value(backupBytes), backupBytes.length),
      );

      final pullResult = await syncService.pullBackupAndLibrary();
      expect(pullResult.success, isTrue);

      // Verify storage service merged bookmarks
      final bookmarks = storageService.loadAllBookmarks();
      expect(bookmarks.any((b) => b.id == 'bm_cloud_1'), isTrue);

      // Verify book state exists
      final books = storageService.loadBooks();
      expect(books.any((b) => b.id == 'cloud_book_1'), isTrue);
    });
  });

  group('DialogGoogleDriveSync UI Tests', () {
    testWidgets('renders dialog with credentials helper showing release and debug SHA-1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DialogGoogleDriveSync(
              storageService: storageService,
              dataSyncService: dataSyncService,
              syncService: syncService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title and main elements
      expect(find.text('Google Drive Cloud Sync'), findsOneWidget);
      expect(find.text('SIGN OUT'), findsOneWidget); // Connected via injected API
      expect(find.text('PUSH (BACKUP)'), findsOneWidget);
      expect(find.text('PULL (RESTORE)'), findsOneWidget);

      // Tap credentials helper icon
      final helpBtn = find.byTooltip('Credentials & Setup Info');
      expect(helpBtn, findsOneWidget);
      await tester.tap(helpBtn);
      await tester.pumpAndSettle();

      // Verify credentials helper displays both permanent release and debug SHA-1
      expect(find.text('Google Cloud Credentials'), findsOneWidget);
      expect(find.text('com.epilogue.read'), findsOneWidget);
      expect(find.text('DD:F0:E4:AB:F0:37:7A:D8:DD:61:9B:D9:B2:D4:38:B3:11:6E:AB:5E'), findsOneWidget);
      expect(find.text('0E:CD:AF:AA:C9:AC:F4:80:EA:33:71:58:4B:9A:27:11:BA:6B:45:EE'), findsOneWidget);
    });
  });
}
