import 'dart:io';

import 'package:path/path.dart' as path;

class FileOperations {
  static File createFileRef(String filePath) {
    final file = File(filePath);
    if (file.existsSync()) {
      return file;
    } else {
      throw FileSystemException('File not found', filePath);
    }
  }

  static Future<List<File>> findArbFiles(Directory dir) async {
    final List<File> arbFiles = [];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.arb')) {
        arbFiles.add(entity);
      }
    }

    return arbFiles;
  }

  static Future<void> copyDirectory(
      Directory source, Directory destination) async {
    // Create the destination directory if it doesn't exist
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    // Copy all files and subdirectories
    await for (final entity in source.list(recursive: false)) {
      final destinationPath =
          path.join(destination.path, path.basename(entity.path));

      if (entity is File) {
        await File(entity.path).copy(destinationPath);
      } else if (entity is Directory) {
        await copyDirectory(entity, Directory(destinationPath));
      }
    }
  }
}
