import 'dart:typed_data';
import 'dart:io';

// generate thumbnails
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:tmp_path/tmp_path.dart';

// generate to/from JSON boilerplate with:
// dart run build_runner build
class Take {
  Take({required this.file}) {
    try {
      thumbnailFuture = makeThumbnail(file);
      thumbnailFuture.then((result) {thumbnail = result;});
    } catch (e) {
      // catch any file manipulation issues. may remove if FcNativeVideoThumbnail no longer used
      print(e);
    }
  }

  final File file;
  late final Future<Uint8List> thumbnailFuture;
  late final Uint8List thumbnail;
  /// Whether this take is a favorite.
  bool favorite = false;

  Map<String, dynamic> toJson() => {
    'filepath': file.path,
    'favorite': favorite,
  };

  factory Take.fromJson(Map<String, dynamic> json) {
    final filepath = json['filepath'] as String;
    final favorite = json['favorite'] as bool;

    final out = Take(file: File(filepath));
    out.favorite = favorite;

    return out;
  }

  @override
  bool operator==(Object other) =>
      other is Take && file.absolute == other.file.absolute;
  @override
  int get hashCode => file.absolute.hashCode;

  static final _thumbnailPlugin = FcNativeVideoThumbnail();
  /// Create a thumbnail for a given video file.
  static Future<Uint8List> makeThumbnail (File file) async {
    final src = file.path;
    final dest = tmpPath() + file.path.split(RegExp(r'(\/|\\)')).last;
    await _thumbnailPlugin.getVideoThumbnail(
            srcFile: src,
            destFile: dest,
            width: 300,
            height: 300,
            keepAspectRatio: true,
          );
    var thumbFile = File(dest);
    var thumbBytes = await thumbFile.readAsBytes();
    thumbFile.delete();
    return thumbBytes;
  }

}

/// this was supposed to be the list of excerpt takes. decided there was no need
// class ExcerptTakes with ChangeNotifier {
//   final List<Take> _takes = List.empty();

//   operator [](int i) => _takes[i]; // get
//   operator []=(int i, Take value) => _takes[i] = value; // set

//   int get length => _takes.length;

//   void delete(int index) {
//     _takes.removeAt(index);
//   }

//   static ExcerptTakes empty() {
//     return ExcerptTakes();
//   }
// }