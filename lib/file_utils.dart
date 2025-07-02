import 'dart:io';
import 'dart:math' as math;

class FileUtils {
  static Future<List<String>> getImageFilesInFolder(
    String folderPath,
    List<String> supportedImageExtensions,
  ) async {
    final dir = Directory(folderPath);

    if (!await dir.exists()) {
      throw Exception('Directory does not exist: $folderPath');
    }

    final List<String> imagePaths = [];
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      if (entity is File) {
        final ext = entity.path.toLowerCase();
        for (var supportedExt in supportedImageExtensions) {
          if (ext.endsWith(supportedExt)) {
            imagePaths.add(entity.path);
          }
        }
      }
    }

    _sortImagePaths(imagePaths);
    
    return imagePaths;
  }

  static void _sortImagePaths(List<String> imagePaths) {
    final Map<String, List<dynamic>> splitCache = {};
    final Map<String, String> baseNameCache = {};
    final RegExp regExp = RegExp(r'(\d+|\D+)');

    List<dynamic> splitAlphaNum(String s) {
      if (splitCache.containsKey(s)) return splitCache[s]!;
      final parts = regExp
          .allMatches(s.toLowerCase())
          .map((m) {
            final str = m.group(0)!;
            final numVal = int.tryParse(str);
            return numVal ?? str;
          })
          .toList();
      splitCache[s] = parts;
      return parts;
    }

    String getBaseName(String path) {
      if (baseNameCache.containsKey(path)) return baseNameCache[path]!;
      final name = path.split(Platform.pathSeparator).last;
      baseNameCache[path] = name;
      return name;
    }

    int naturalCompare(String a, String b) {
      final aParts = splitAlphaNum(a);
      final bParts = splitAlphaNum(b);
      final len = math.min(aParts.length, bParts.length);
      for (var i = 0; i < len; i++) {
        final x = aParts[i];
        final y = bParts[i];
        if (x is int && y is int) {
          if (x != y) return x.compareTo(y);
        } else {
          final cmp = x.toString().compareTo(y.toString());
          if (cmp != 0) return cmp;
        }
      }
      return aParts.length.compareTo(bParts.length);
    }

    imagePaths.sort((a, b) {
      final nameA = getBaseName(a);
      final nameB = getBaseName(b);
      return naturalCompare(nameA, nameB);
    });
  }

  static bool isEqual(String path1, String path2) {
    return normalizePath(path1) == normalizePath(path2);
  }

  static String normalizePath(String path) {
    return path.replaceAll('\\', '/');
  }

  static String getFileName(String fullPath) {
    return fullPath.split(Platform.pathSeparator).last;
  }

}