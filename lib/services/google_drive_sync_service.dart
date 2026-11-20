import 'dart:convert';
import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import '../models/book_info.dart';
import 'data_sync_service.dart';
import 'epub_parser_service.dart';
import 'storage_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final int booksSynced;
  final int booksSkipped;
  final String? backupTimestamp;

  const SyncResult({
    required this.success,
    required this.message,
    this.booksSynced = 0,
    this.booksSkipped = 0,
    this.backupTimestamp,
  });

  factory SyncResult.success({
    required String message,
    int booksSynced = 0,
    int booksSkipped = 0,
    String? backupTimestamp,
  }) {
    return SyncResult(
      success: true,
      message: message,
      booksSynced: booksSynced,
      booksSkipped: booksSkipped,
      backupTimestamp: backupTimestamp,
    );
  }

  factory SyncResult.failure(String message) {
    return SyncResult(
      success: false,
      message: message,
    );
  }
}

class CloudSnapshotInfo {
  final DateTime? lastModified;
  final int cloudBookCount;
  final BackupSummary? summary;

  const CloudSnapshotInfo({
    this.lastModified,
    this.cloudBookCount = 0,
    this.summary,
  });
}

class GoogleDriveSyncService {
  static const String rootFolderName = 'Epilogue Cloud Backup';
  static const String libraryFolderName = 'Library';
  static const String backupFileName = 'epilogue_backup.json';

  final GoogleSignIn _googleSignIn;
  final StorageService storageService;
  final DataSyncService dataSyncService;
  final drive.DriveApi? _injectedDriveApi;

  GoogleDriveSyncService({
    required this.storageService,
    required this.dataSyncService,
    GoogleSignIn? googleSignIn,
    drive.DriveApi? injectedDriveApi,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                drive.DriveApi.driveFileScope,
              ],
            ),
        _injectedDriveApi = injectedDriveApi;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  bool get isSignedIn => currentUser != null || _injectedDriveApi != null;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<drive.DriveApi?> getDriveApi() async {
    if (_injectedDriveApi != null) return _injectedDriveApi;

    var account = _googleSignIn.currentUser;
    account ??= await signInSilently();
    account ??= await signIn();
    if (account == null) return null;

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;

    return drive.DriveApi(client);
  }

  /// Locates or creates a folder with the specified name under parentId
  Future<String?> getOrCreateFolder(
    drive.DriveApi api,
    String folderName, {
    String? parentId,
  }) async {
    try {
      var query = "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false";
      if (parentId != null) {
        query += " and '$parentId' in parents";
      }

      final fileList = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }

      // Create new folder
      final folderMetadata = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      if (parentId != null) {
        folderMetadata.parents = [parentId];
      }

      final created = await api.files.create(
        folderMetadata,
        $fields: 'id',
      );
      return created.id;
    } catch (_) {
      return null;
    }
  }

  /// Fetches an existing file by name in a parent folder
  Future<drive.File?> findFile(
    drive.DriveApi api,
    String fileName, {
    String? parentId,
  }) async {
    try {
      var query = "name = '$fileName' and trashed = false";
      if (parentId != null) {
        query += " and '$parentId' in parents";
      }

      final result = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, size, modifiedTime, md5Checksum)',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Pushes complete Epilogue snapshot and local EPUB files to Google Drive
  Future<SyncResult> pushBackupAndLibrary({
    Function(String status, double progress)? onProgress,
  }) async {
    try {
      onProgress?.call('Connecting to Google Drive...', 0.05);
      final api = await getDriveApi();
      if (api == null) {
        return SyncResult.failure('Failed to authenticate with Google Drive.');
      }

      // 1. Locate/Create root folder
      onProgress?.call('Checking cloud directories...', 0.10);
      final rootFolderId = await getOrCreateFolder(api, rootFolderName);
      if (rootFolderId == null) {
        return SyncResult.failure('Could not access or create backup folder on Google Drive.');
      }

      final libraryFolderId = await getOrCreateFolder(
        api,
        libraryFolderName,
        parentId: rootFolderId,
      );
      if (libraryFolderId == null) {
        return SyncResult.failure('Could not access or create Library folder on Google Drive.');
      }

      // 2. Upload JSON metadata backup
      onProgress?.call('Exporting reading state & telemetry...', 0.20);
      final jsonSnapshot = dataSyncService.generateBackupJson();
      final jsonBytes = utf8.encode(jsonSnapshot);

      final existingBackupFile = await findFile(api, backupFileName, parentId: rootFolderId);
      final backupMetadata = drive.File()..name = backupFileName;
      final media = drive.Media(
        Stream.value(jsonBytes),
        jsonBytes.length,
        contentType: 'application/json',
      );

      if (existingBackupFile?.id != null) {
        await api.files.update(
          backupMetadata,
          existingBackupFile!.id!,
          uploadMedia: media,
        );
      } else {
        backupMetadata.parents = [rootFolderId];
        await api.files.create(
          backupMetadata,
          uploadMedia: media,
        );
      }

      // 3. Scan & sync EPUB novel binaries
      onProgress?.call('Scanning local library novels...', 0.30);
      final localBooks = storageService.loadBooks();

      // Retrieve existing files in cloud library to avoid re-uploading
      final cloudLibList = await api.files.list(
        q: "'$libraryFolderId' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name, size)',
      );
      final cloudFilesMap = {
        for (final f in (cloudLibList.files ?? []))
          if (f.name != null) f.name!: f
      };

      int uploadedCount = 0;
      int skippedCount = 0;
      final totalBooks = localBooks.length;

      for (int i = 0; i < totalBooks; i++) {
        final book = localBooks[i];
        final progressFraction = 0.35 + (0.60 * (i + 1) / (totalBooks > 0 ? totalBooks : 1));
        final file = File(book.filePath);

        if (!file.existsSync()) {
          skippedCount++;
          continue;
        }

        final cloudName = '${book.id}.epub';
        final fileSize = file.lengthSync();
        final existingCloudFile = cloudFilesMap[cloudName];

        // Idempotency: skip upload if size matches
        if (existingCloudFile != null &&
            existingCloudFile.size != null &&
            int.tryParse(existingCloudFile.size!) == fileSize) {
          skippedCount++;
          onProgress?.call('Novel already up to date: ${book.title}', progressFraction);
          continue;
        }

        onProgress?.call('Uploading ${book.title} (${i + 1}/$totalBooks)...', progressFraction);

        final epubMetadata = drive.File()
          ..name = cloudName
          ..description = book.title;

        final epubMedia = drive.Media(
          file.openRead(),
          fileSize,
          contentType: 'application/epub+zip',
        );

        if (existingCloudFile?.id != null) {
          await api.files.update(
            epubMetadata,
            existingCloudFile.id!,
            uploadMedia: epubMedia,
          );
        } else {
          epubMetadata.parents = [libraryFolderId];
          await api.files.create(
            epubMetadata,
            uploadMedia: epubMedia,
          );
        }
        uploadedCount++;
      }

      onProgress?.call('Cloud synchronization complete!', 1.0);
      return SyncResult.success(
        message: 'Successfully backed up state and $uploadedCount novels to Google Drive ($skippedCount skipped).',
        booksSynced: uploadedCount,
        booksSkipped: skippedCount,
        backupTimestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return SyncResult.failure('Push error: $e');
    }
  }

  /// Pulls backup from Google Drive, restores missing EPUBs and smart-merges reading state
  Future<SyncResult> pullBackupAndLibrary({
    Function(String status, double progress)? onProgress,
    BackupImportOptions options = const BackupImportOptions(),
  }) async {
    try {
      onProgress?.call('Connecting to Google Drive...', 0.05);
      final api = await getDriveApi();
      if (api == null) {
        return SyncResult.failure('Failed to authenticate with Google Drive.');
      }

      onProgress?.call('Locating cloud backup snapshot...', 0.15);
      final rootFolderId = await getOrCreateFolder(api, rootFolderName);
      if (rootFolderId == null) {
        return SyncResult.failure('Backup folder not found on Google Drive.');
      }

      final backupFile = await findFile(api, backupFileName, parentId: rootFolderId);
      if (backupFile?.id == null) {
        return SyncResult.failure('No epilogue_backup.json found on Google Drive.');
      }

      // Download JSON snapshot
      onProgress?.call('Downloading reading state & progress...', 0.25);
      final response = await api.files.get(
        backupFile!.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final contentBytes = <int>[];
      await for (final chunk in response.stream) {
        contentBytes.addAll(chunk);
      }
      final jsonContent = utf8.decode(contentBytes);

      // Verify valid snapshot
      final summary = BackupSummary.fromJson(jsonContent);
      if (summary == null || summary.isEmpty) {
        return SyncResult.failure('Cloud backup snapshot is empty or corrupt.');
      }

      // Prepare local storage directory for restored EPUBs
      Directory? targetDir;
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        targetDir = Directory('${docsDir.path}/epilogue_library');
        if (!targetDir.existsSync()) {
          targetDir.createSync(recursive: true);
        }
      } catch (_) {}

      // Scan cloud library folder for EPUBs
      onProgress?.call('Scanning cloud library...', 0.35);
      final libraryFolderId = await getOrCreateFolder(api, libraryFolderName, parentId: rootFolderId);
      final cloudLibList = libraryFolderId != null
          ? await api.files.list(
              q: "'$libraryFolderId' in parents and trashed = false",
              spaces: 'drive',
              $fields: 'files(id, name, size)',
            )
          : null;

      final cloudFiles = {
        for (final f in (cloudLibList?.files ?? []))
          if (f.name != null && f.id != null) f.name!: f
      };

      int restoredBooks = 0;
      int skippedBooks = 0;

      // Extract book list from backup JSON to inspect local file existence
      final decoded = jsonDecode(jsonContent);
      if (options.importBooks && decoded is Map && decoded.containsKey('books') && decoded['books'] is List) {
        final rawBooks = (decoded['books'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => BookInfo.fromMap(m))
            .toList();

        final totalBooks = rawBooks.length;
        for (int i = 0; i < totalBooks; i++) {
          final book = rawBooks[i];
          final progressFraction = 0.40 + (0.50 * (i + 1) / (totalBooks > 0 ? totalBooks : 1));
          final cloudFileName = '${book.id}.epub';
          final localFile = File(book.filePath);

          if (localFile.existsSync()) {
            skippedBooks++;
            continue;
          }

          // If local file does not exist, download from cloud
          final cloudFile = cloudFiles[cloudFileName];
          if (cloudFile?.id != null && targetDir != null) {
            onProgress?.call('Restoring novel: ${book.title}...', progressFraction);
            final destPath = '${targetDir.path}/$cloudFileName';
            final destFile = File(destPath);

            final downloadMedia = await api.files.get(
              cloudFile!.id!,
              downloadOptions: drive.DownloadOptions.fullMedia,
            ) as drive.Media;

            final sink = destFile.openWrite();
            await downloadMedia.stream.pipe(sink);

            // Re-point book file path to newly downloaded local file
            rawBooks[i] = book.copyWith(filePath: destPath);

            // Extract cached images & covers
            try {
              await EpubParserService.extractAllBookImages(destPath);
            } catch (_) {}

            restoredBooks++;
          }
        }

        // Re-inject updated book paths back into decoded JSON before import
        decoded['books'] = rawBooks.map((b) => b.toMap()).toList();
      }

      // Execute smart merge
      onProgress?.call('Merging telemetry, bookmarks, and settings...', 0.95);
      final importSuccess = await dataSyncService.importBackupFromJson(
        jsonEncode(decoded),
        smartMerge: true,
        options: options,
      );

      if (!importSuccess) {
        return SyncResult.failure('Failed to merge cloud data into local database.');
      }

      onProgress?.call('Restore complete!', 1.0);
      return SyncResult.success(
        message: 'Successfully pulled cloud backup and restored $restoredBooks novels ($skippedBooks already present).',
        booksSynced: restoredBooks,
        booksSkipped: skippedBooks,
      );
    } catch (e) {
      return SyncResult.failure('Pull error: $e');
    }
  }

  /// Reads cloud snapshot metadata without full data pull
  Future<CloudSnapshotInfo?> getCloudSnapshotInfo() async {
    try {
      final api = await getDriveApi();
      if (api == null) return null;

      final rootFolderId = await getOrCreateFolder(api, rootFolderName);
      if (rootFolderId == null) return null;

      final backupFile = await findFile(api, backupFileName, parentId: rootFolderId);
      final libraryFolderId = await getOrCreateFolder(api, libraryFolderName, parentId: rootFolderId);

      int bookCount = 0;
      if (libraryFolderId != null) {
        final libList = await api.files.list(
          q: "'$libraryFolderId' in parents and trashed = false",
          spaces: 'drive',
          $fields: 'files(id)',
        );
        bookCount = libList.files?.length ?? 0;
      }

      DateTime? lastModified = backupFile?.modifiedTime;
      return CloudSnapshotInfo(
        lastModified: lastModified,
        cloudBookCount: bookCount,
      );
    } catch (_) {
      return null;
    }
  }
}
