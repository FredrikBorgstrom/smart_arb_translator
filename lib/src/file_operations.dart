import 'dart:io';

import 'package:path/path.dart' as path;

/// Utility class for file system operations used in ARB translation workflows.
///
/// This class provides static methods for common file operations including
/// file validation, ARB file discovery, and directory copying. These operations
/// are essential for managing ARB files and organizing translation outputs.
class FileOperations {
  /// Creates a file reference and validates that the file exists.
  ///
  /// This method creates a [File] object for the specified path and verifies
  /// that the file exists on the file system. It's useful for validating
  /// input files before processing.
  ///
  /// Parameters:
  /// - [filePath]: Path to the file to reference
  ///
  /// Returns a [File] object for the specified path.
  ///
  /// Throws [FileSystemException] if the file does not exist.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final file = FileOperations.createFileRef('lib/l10n/app_en.arb');
  ///   print('File found: ${file.path}');
  /// } catch (e) {
  ///   print('File not found: $e');
  /// }
  /// ```
  static File createFileRef(String filePath) {
    final file = File(filePath);
    if (file.existsSync()) {
      return file;
    } else {
      throw FileSystemException('File not found', filePath);
    }
  }

  /// Recursively finds all ARB files in a directory.
  ///
  /// This method searches through the specified directory and all its
  /// subdirectories to locate files with the '.arb' extension. It's used
  /// for batch processing of ARB files in directory-based workflows.
  ///
  /// Parameters:
  /// - [dir]: Directory to search for ARB files
  ///
  /// Returns a [Future<List<File>>] containing all found ARB files.
  ///
  /// Example:
  /// ```dart
  /// final directory = Directory('lib/l10n_source');
  /// final arbFiles = await FileOperations.findArbFiles(directory);
  /// print('Found ${arbFiles.length} ARB files');
  /// for (final file in arbFiles) {
  ///   print('  - ${file.path}');
  /// }
  /// ```
  static Future<List<File>> findArbFiles(Directory dir) async {
    final List<File> arbFiles = [];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.arb')) {
        arbFiles.add(entity);
      }
    }

    return arbFiles;
  }

  /// Recursively copies a directory and all its contents to a new location.
  ///
  /// This method performs a complete directory copy operation, creating
  /// the destination directory if it doesn't exist and copying all files
  /// and subdirectories while preserving the directory structure.
  ///
  /// Parameters:
  /// - [source]: Source directory to copy from
  /// - [destination]: Destination directory to copy to
  ///
  /// Returns a [Future<void>] that completes when the copy operation is finished.
  ///
  /// Example:
  /// ```dart
  /// final source = Directory('lib/l10n_cache');
  /// final destination = Directory('lib/l10n');
  /// await FileOperations.copyDirectory(source, destination);
  /// print('Directory copied successfully');
  /// ```
  static Future<void> copyDirectory(Directory source, Directory destination) async {
    // Create the destination directory if it doesn't exist
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    // Copy all files and subdirectories
    await for (final entity in source.list(recursive: false)) {
      final destinationPath = path.join(destination.path, path.basename(entity.path));

      if (entity is File) {
        await File(entity.path).copy(destinationPath);
      } else if (entity is Directory) {
        await copyDirectory(entity, Directory(destinationPath));
      }
    }
  }
}
