
import 'dart:io';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:take_recorder/src/takes/excerpt_takes.dart';
import 'package:take_recorder/src/take_studio/play_take_widget.dart';
import 'package:take_recorder/src/take_studio/record_widget.dart';

// Record new takes, view old ones, mark for deletion, and mark favorite
class TakeStudioView extends StatefulWidget {
  TakeStudioView({super.key, required this.excerptID}) {
    // create a folder to save videos inside
    getApplicationDocumentsDirectory()
    ..then((Directory appDir) {
      final path = p.join(appDir.path, excerptID);
      videoSaveDir = Directory(path); // this also creates the folder
    })
    ..catchError((error, stackTrace) {
      throw Exception('Error creating save directory: $error');
    });
  }

  final String excerptID;
  late final Directory videoSaveDir;

  @override
  State<TakeStudioView> createState() => _TakeStudioViewState();
}

class _TakeStudioViewState extends State<TakeStudioView> {

  final List<Take?> takes = [];
  int currVideo = -1;

  String newVideoPath() {
    final filename = DateTime.now().toIso8601String().replaceAll(':', '');
    return p.join(widget.videoSaveDir.path, filename);
  }

  // custom getter/setter in case implementation is changed, as well as tear-off
  void setViewing(int currVideo) {
    assert (currVideo >= -1 && currVideo < takes.length);

    setState(() {
      this.currVideo = currVideo;
    });
  }
  int getViewing() {
    return currVideo;
  }

  // for tear-off
  void addTake(XFile video) {
    // add a placeholder tile to the takes list
    setState(() {
      takes.add(null);
    });
    // save the XFile
    final path = newVideoPath();
    video.saveTo(path)
    ..then((void _) {
      // make a new Take
      final newTake = Take(file: File(path));
      // add to the list replacing placeholder
      setState(() {
        takes.last = newTake;
      });
    })
    ..catchError((error, stackTrace) {
      throw Exception('Error saving video: $error');
    });
  }
  void delTake(int index) {
    // delete the take's corresponding file
    var take = takes.elementAt(index);
    // TODO take.delete(); // we need to delete the file. idk if we want an undo function... idk what to do here
    // remove from the list
    setState(() {
      takes.removeAt(index);
      if (index >= takes.length) {
        currVideo = -1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Studio'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TODO support landscape orientation
          Expanded(
            child: switch (getViewing()) { // TODO preserve recordwidget state
                (-1) => RecordWidget(
                  addTake: addTake,
                ),
                (>= 0) => PlayTakeWidget(),
                (_) => const Text('Video ID error'),
              }
          ),
          TakesList(
            height: 100,
            itemWidth: 100,
            takes: takes,
            setView: setViewing,
            getView: getViewing,
          ),
        ],
      ),
      bottomNavigationBar: const BottomAppBar(
        child: Text('More Information Here'),
      ),
    );
  }
}

// current implementation: one row, any height, fills width
class TakesList extends StatefulWidget {
  const TakesList({super.key, required this.height, required this.itemWidth, required this.takes, required this.setView, required this.getView});

  final double height;
  final double itemWidth;

  // prop drilling
  final List takes;
  final void Function(int currVideo) setView;
  final int Function() getView;

  @override
  State<TakesList> createState() => _TakesListState();
}

class _TakesListState extends State<TakesList> {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: SizedBox(
        height: widget.height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (context, i) => const SizedBox(width: 14,),
          itemCount: widget.takes.length + 1,
          itemBuilder: (context, i) {
            if (i == widget.takes.length) { // add button
              return ButtonWithActive(
                onPressed: () {widget.setView(-1);},
                itemWidth: widget.itemWidth,
                active: widget.getView() == -1,
                child: const Icon(Icons.camera_alt_outlined),
              );
            } else { // previous video button
              return switch (widget.takes[i]) {
                null => ButtonWithActive(
                  onPressed: null,
                  itemWidth: widget.itemWidth,
                  active: false,
                  child: SizedBox(
                    height: widget.height,
                    width: widget.itemWidth,
                    child: const CircularProgressIndicator(),
                  )
                ),
                _ => FutureBuilder( // display video thumbnail, or placeholder
                  future: widget.takes[i].thumbnailFuture,
                  builder: (context, AsyncSnapshot<Uint8List> snapshot) {
                    Widget thumbnail;
                    if (snapshot.hasData) {
                      thumbnail = Image.memory(snapshot.data!);
                    } else if (snapshot.hasError) {
                      thumbnail = const Icon(Icons.image_not_supported_outlined);
                    } else {
                      thumbnail = const Icon(Icons.play_arrow_outlined);
                    }
                    return ButtonWithActive(
                      onPressed: () {widget.setView(i);},
                      itemWidth: widget.itemWidth,
                      active: widget.getView() == i,
                      child: SizedBox(
                        height: widget.height,
                        width: widget.itemWidth,
                        child: thumbnail,
                      )
                    );
                  }
                ),
              };
            }
          },
        ),
      ),
    );
  }
}

class ButtonWithActive extends ElevatedButton {
  const ButtonWithActive({
    super.key,
    required super.onPressed,
    required super.child,
    required this.active,
    required this.itemWidth,
  });

  final bool active;
  final double itemWidth;

  @override
  State<ButtonWithActive> createState() => _ButtonWithActiveState();
}

class _ButtonWithActiveState extends State<ButtonWithActive> {

  static final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12.0),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.active) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: shape,
          side: BorderSide(color: Theme.of(context).colorScheme.surface),
          fixedSize: Size.fromWidth(widget.itemWidth),
        ),
        onPressed: widget.onPressed,
        child: widget.child,
      );
    } else {
      return OutlinedButton (
        style: OutlinedButton.styleFrom(
          shape: shape,
          fixedSize: Size.fromWidth(widget.itemWidth),
        ),
        onPressed: widget.onPressed,
        child: widget.child,
      );
    }
  }
}