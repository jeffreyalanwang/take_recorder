
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:take_recorder/src/takes/excerpt_takes.dart';
import 'package:take_recorder/src/take_studio/play_take_widget.dart';
import 'package:take_recorder/src/take_studio/record_widget.dart';

// Record new takes, view old ones, mark for deletion, and mark favorite
// TODO would be more efficient to rewrite as a stateless widget with a seperate state object
class TakeStudioView extends StatefulWidget {
  TakeStudioView({super.key, required this.excerptID}) {
    // create a folder to save videos inside
    getApplicationDocumentsDirectory()
    ..then((Directory appDir) {
      final path = p.join(appDir.path, excerptID);
      videoSaveDir = Directory(path)..create(); // this also creates the folder
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

  final List<Future<Take>> takeFutures = [];
  final List<Take> takes = [];
  int currVideo = -1;

  String newVideoPath() {
    final filename = DateTime.now().toIso8601String().replaceAll(':', '');
    return p.join(widget.videoSaveDir.path, filename);
  }

  // TODO change this to a setter, remove tear-off by moving take list into the takestudioview class
  // custom getter/setter in case implementation is changed, as well as tear-off
  void setViewing(int index) {
    assert (index >= -1 && index < takes.length);

    setState(() {
      currVideo = index;
    });
  }
  int getViewing() {
    return currVideo;
  }

  // make a Take object
  Future<Take> createTake(XFile video) async {
    // save the XFile
    final path = newVideoPath();
    await video.saveTo(path);
    final newTake = Take(file: File(path));
    return newTake;
  }

  // for tear-off
  void addTake(XFile video) {
    final int index = takes.length; // index at which this video is saved in takeFutures
    // add to both takeFutures and takes
    takeFutures.add(createTake(video)
      ..then((take) {
        takes.insert(index, take);
      })
      ..catchError((error, stackTrace) {
        throw Exception('Error saving video: $error');
      })
    );
    setState(() {});
  }
  void delTake(int index) {
    // delete the take's corresponding file
    var take = takes.elementAt(index);
    // TODO take.delete(); // we need to delete the file. idk if we want an undo function... idk what to do here
    // remove from the list
    setState(() {
      takes.removeAt(index);
      takeFutures.removeAt(index);
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
                (>= 0) => PlayTakeWidget(
                  take: takes[getViewing()],
                  removeTake: () => delTake(getViewing()),
                ),
                (_) => const Text('Video ID error'),
              }
          ),
          TakesList(
            height: 100,
            itemWidth: 100,
            takeFutures: takeFutures,
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
// this really should have been implemented as a RadioList. oh well.
// TODO this should be declared inside of TakeStudioView to reduce prop drilling. or be passed the state object, once TakeStudioView is a StatelessWidget.
class TakesList extends StatefulWidget {
  const TakesList({super.key, required this.height, required this.itemWidth, required this.takeFutures, required this.takes, required this.setView, required this.getView});

  final double height;
  final double itemWidth;

  // prop drilling
  final List takeFutures;
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
          itemCount: widget.takeFutures.length + 1,
          itemBuilder: (context, i) {
            if (i == widget.takeFutures.length) { // record new button
              return ButtonWithActive(
                onPressed: () {widget.setView(-1);},
                length: widget.itemWidth,
                active: widget.getView() == -1,
                child: const Icon(Icons.camera_alt_outlined),
              );
            } else { // previous video button
              return FutureBuilder( // display take, or take is loading
                future: widget.takeFutures[i],
                builder: (context, AsyncSnapshot<Take> takeSnapshot) => takeSnapshot.hasData
                  ? FutureBuilder( // video saved; display video thumbnail once loaded
                      future: takeSnapshot.data!.thumbnailFuture,
                      builder: (context, AsyncSnapshot<Uint8List> thumbnailSnapshot) {
                        Widget thumbnail;
                        if (thumbnailSnapshot.hasData) { 
                          thumbnail = LayoutBuilder( // make sure it fills up the whole button
                            builder: (context, constraints) {
                              return OverflowBox(
                                minWidth: constraints.maxWidth,
                                minHeight: constraints.maxHeight,
                                maxWidth: double.infinity,
                                maxHeight: double.infinity,
                                alignment: Alignment.center,
                                child: Image.memory(thumbnailSnapshot.data!),
                              );
                            }
                          );
                        } else if (thumbnailSnapshot.hasError) {
                          thumbnail = const Icon(Icons.broken_image_outlined);
                        } else { // thumbnail not yet created
                          thumbnail = const Icon(Icons.video_file);
                        }
                        return ButtonWithActive(
                          onPressed: () {widget.setView(i);},
                          length: widget.itemWidth,
                          active: widget.getView() == i,
                          child: SizedBox(
                            height: widget.height,
                            width: widget.itemWidth,
                            child: thumbnail,
                          )
                        );
                      }
                    )
                  : (takeSnapshot.hasError) // no video available: error or loading?
                    ? ButtonWithActive( // display error icon
                        onPressed: null,
                        length: widget.itemWidth,
                        active: false,
                        child: const Icon(Icons.error),
                      )
                    : ButtonWithActive( // display loader until video is saved
                      onPressed: null,
                      length: widget.itemWidth,
                      active: false,
                      child: const CircularProgressIndicator(),
                      )
              );
            }
          },
        ),
      ),
    );
  }
}

/// A equivalent to RadioButton; a button with the ability to be currently selected.
class ButtonWithActive extends ElevatedButton {
  /// Creates a ButtonWithActive.
  const ButtonWithActive({
    super.key,
    required super.onPressed,
    required super.child,
    required this.active,
    required this.length,
  });

  /// Whether this button is the selected one.
  final bool active;
  /// The length of one side of this square button.
  final double length;

  @override
  State<ButtonWithActive> createState() => _ButtonWithActiveState();
}

class _ButtonWithActiveState extends State<ButtonWithActive> {
  @override
  Widget build(BuildContext context) {

    final childWithWrappers = Center(
      child: widget.child,
    );

    return ElevatedButton(
      clipBehavior: Clip.antiAlias,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(.1 * widget.length),
        ),
        padding: EdgeInsets.zero,
        side: switch (widget.active) {
          true => BorderSide(
            width: 3,
            color: Theme.of(context).colorScheme.outline,
          ),
          false => BorderSide.none,
        },
        fixedSize: Size.fromWidth(widget.length),
      ),
      onPressed: widget.onPressed,
      child: childWithWrappers,
    );
  }
}