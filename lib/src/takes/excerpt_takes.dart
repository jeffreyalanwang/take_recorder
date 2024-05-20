import 'dart:typed_data';

import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:tmp_path/tmp_path.dart';


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
  bool favorite = false;

  static final thumbnailPlugin = FcNativeVideoThumbnail();
  static Future<Uint8List> makeThumbnail (File file) async {
    final src = file.path;
    final dest = tmpPath() + file.path.split(RegExp(r'(\/|\\)')).last;
    await thumbnailPlugin.getVideoThumbnail(
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