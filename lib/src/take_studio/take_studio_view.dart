import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:take_recorder/src/take_studio/hidden_takes_view.dart';

import 'package:take_recorder/src/takes/excerpt_takes.dart';
import 'package:take_recorder/src/take_studio/play_take_widget.dart';
import 'package:take_recorder/src/take_studio/record_widget.dart';

/// Record new takes, view old ones, mark for deletion, and mark favorite
// TODO would be more efficient to rewrite as a stateless widget with a seperate state object
class TakeStudioView extends StatefulWidget {
  /// Constructor for TakeStudioView
  /// Requires an excerptID unique to entire app
  TakeStudioView({super.key, required this.excerptID}) {
    final _jsonCompleter1 = Completer<void>();
    final _jsonCompleter2 = Completer<void>();
    filesInitializedFuture =
        Future.wait([_jsonCompleter1.future, _jsonCompleter2.future]);
    // Prepare save location for this excerpt.
    getApplicationDocumentsDirectory()
      ..then((Directory appDir) {
        // Create a folder to save videos inside.
        final videoSaveDirPath = p.join(appDir.path, 'takes', excerptID);
        Directory(videoSaveDirPath)
            .create(recursive: true) // create the folder if not present
          ..then((Directory videoSaveDir) {
            // make directory available to widget
            this.videoSaveDir = videoSaveDir;
            // Create a file inside this folder to persist take metadata.
            File(p.join(videoSaveDir.path, 'takes.json')).create()
              ..then((File takeJsonFile) {
                this.takeJsonFile = takeJsonFile;
                _jsonCompleter1.complete();
              })
              ..catchError((error, stackTrace) {
                throw Exception('Error creating save file: $error');
              });
            // Create a file for hidden take metadata.
            File(p.join(videoSaveDir.path, 'hiddenTakes.json')).create()
              ..then((File takeJsonFile) {
                this.deletedTakeJsonFile = deletedTakeJsonFile;
                _jsonCompleter2.complete();
              })
              ..catchError((error, stackTrace) {
                throw Exception(
                    'Error creating hidden video save file: $error');
              });
          })
          ..catchError((error, stackTrace) {
            throw Exception('Error creating save directory: $error');
          });
      })
      ..catchError((error, stackTrace) {
        _jsonCompleter1.completeError(error);
        _jsonCompleter2.completeError(error);
        throw Exception('Error getting directory: $error');
      });
  }

  final String excerptID;
  late final Directory videoSaveDir;
  late final File takeJsonFile;
  late final File deletedTakeJsonFile;

  /// Whether videoSaveDir and takeJsonFile are ready to use.
  /// Only checked for loadTakes, which might run before files are initialized.
  late final Future<void> filesInitializedFuture;

  @override
  State<TakeStudioView> createState() => _TakeStudioViewState();
}

class _TakeStudioViewState extends State<TakeStudioView> {
  /// A list of Futures tracking when takes are saved to disk with createTake
  final List<Future<Take>> takeFutures = [];

  /// May be shorter than takeFutures if not all takes have been saved
  final List<Take> takes = [];

  /// List of any takes that have been deleted
  final List<Take> deletedTakes = [];

  /// -1 if recording, otherwise the index of the currently selected take
  int currVideo = -1;

  String newVideoPath() {
    final filename = DateTime.now().toIso8601String().replaceAll(':', '');
    return p.join(widget.videoSaveDir.path, filename);
  }

  // generate JSON string of entire list of takes
  String _takeListToJson(List<Take> list) {
    final takesAsMaps = takes
        .map((obj) => obj.toJson())
        .toList(); // a list of maps for each take
    final jsonString = json.encode(takesAsMaps);
    return jsonString;
  }

  /// Serialize takes and save to takeJsonFile
  void saveTakeInfo() async {
    await widget.filesInitializedFuture;
    try {
      // don't serialize until all takes are saved
      await Future.wait(takeFutures);
      // generate JSON string of entire list
      final jsonString = _takeListToJson(takes);
      // save JSON string to filepath
      widget.takeJsonFile.writeAsStringSync(jsonString);
    } catch (e) {
      if (mounted) {
        // Warn the user of an issue saving take info.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving video info: ${e.toString()} Videos are saved, but might only appear in trash.',
            ),
          ),
        );
      }
      rethrow;
    }
  }

  /// Serialize deleted takes and save to deletedTakeJsonFile
  void saveDeletedTakeInfo() async {
    await widget.filesInitializedFuture;
    try {
      // generate JSON string of entire list
      final jsonString = json.encode(deletedTakes);
      // save JSON string to filepath
      widget.deletedTakeJsonFile.writeAsStringSync(jsonString);
    } catch (e) {
      if (mounted) {
        // Warn the user of an issue saving take info.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving deleted video info: ${e.toString()} Videos are saved, but might be missing metadata.',
            ),
          ),
        );
      }
      rethrow;
    }
  }

  /// Returns all takes, even if already loaded, from jsonFile.
  Future<List<Take>> _loadTakesFrom(File jsonFile) async {
    // read from file
    final jsonString = jsonFile.readAsStringSync();
    // read JSON
    if (jsonString.isNotEmpty) {
      final takes = (json.decode(
        // jsonString should be a List of Map<String, dynamic>
        jsonString,
        // reviver runs recursively for each JSON object
        reviver: (key, value) {
          if (key.runtimeType == int && // value is in a list
              value.runtimeType == Map<String, dynamic>) {
            // value is an object
            // convert to a take
            return Take.fromJson(value as Map<String, dynamic>);
          } else {
            // keep list and primitives inside object as they are
            assert(value.runtimeType != Map<String, dynamic>);
            return value;
          }
        },
      ) as List)
          .cast<Take>();
      return takes;
    } else {
      return List<Take>.empty();
    }
  }

  /// Load any serialized takes from a file and then rebuild view (thumbnails may be loading)
  /// Returns whether any takes were present from file
  /// Defaults to this excerpt's json file, defined in [ TakeStudioView ]
  Future<bool> loadTakes() async {
    // wait for takeJsonFile to be available
    await widget.filesInitializedFuture;
    final jsonFile = widget.takeJsonFile;

    late final List<Take> newTakes; // move scope out of try block
    try {
      newTakes = await _loadTakesFrom(jsonFile);
    } catch (e) {
      if (mounted) {
        // Warn the user of an issue saving take info.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading video info: ${e.toString()}',
            ),
          ),
        );
      }
      throw Exception('Error loading video info: ${e.toString()}');
    }

    // delete takes which are already in takes list
    newTakes.removeWhere((Take element) => takes.contains(element));

    // add any loaded takes to current view
    for (final take in newTakes) {
      // create a take which is already completed (video is already saved)
      final takeFuture = Future<Take>.value(take);
      takeFutures.add(takeFuture);
      takes.add(take);
    }
    if (newTakes.isNotEmpty) {
      // rebuild view with new takes
      setState(() {});
    }

    return newTakes.isNotEmpty;
  }

  /// Load any serialized takes from a file and then rebuild view (thumbnails may be loading)
  /// Returns whether any takes were present from file
  /// Defaults to this excerpt's json file, defined in [ TakeStudioView ]
  // TODO rename "deleted" to "hidden" in all variables
  Future<bool> loadHiddenTakes() async {
    // wait for takeJsonFile to be available
    await widget.filesInitializedFuture;
    final jsonFile = widget.deletedTakeJsonFile;

    late final List<Take> newTakes; // move scope out of try block
    try {
      newTakes = await _loadTakesFrom(jsonFile);
    } catch (e) {
      if (mounted) {
        // Warn the user of an issue saving take info.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading hidden video info: ${e.toString()}',
            ),
          ),
        );
      }
      throw Exception('Error loading hidden video info: ${e.toString()}');
    }

    // delete takes which are already in takes list
    newTakes.removeWhere((Take element) => deletedTakes.contains(element));

    // add any loaded takes to list
    deletedTakes.addAll(newTakes);
    if (newTakes.isNotEmpty) {
      // rebuild view with new takes
      setState(() {});
    }

    return newTakes.isNotEmpty;
  }

  // TODO change this to a setter, remove tear-off by moving take list into the takestudioview class
  // custom getter/setter in case implementation is changed, as well as tear-off
  void setViewing(int index) {
    assert(index >= -1 && index < takes.length);

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
  /// Adds to takeFutures, saves info to disk, updates state, and makes the take video available once saved.
  void addTake(XFile video) {
    final int index =
        takes.length; // index at which this video is saved in takeFutures
    // add to both takeFutures and takes
    takeFutures.add(createTake(
      video,
    )
      ..then((take) {
        takes.insert(index, take);
      })
      ..catchError((error, stackTrace) {
        throw Exception('Error saving video: $error');
      }));
    saveTakeInfo();
    setState(() {});
  }

  /// Moves take to deleted folder. Preserves
  void delTake(int index) {
    // move take to deletedTakes
    var take = takes.elementAt(index);
    // remove from the list
    setState(() {
      takes.removeAt(index);
      takeFutures.removeAt(index);
      if (index >= takes.length) {
        currVideo = -1;
      }
    });
    deletedTakes.add(take);
    saveTakeInfo();
    saveDeletedTakeInfo();
  }

  void editTake(int index, {bool? favorite}) {
    var take = takes[index];
    if (favorite != null) {
      take.favorite = favorite;
    }
    saveTakeInfo();
  }

  @override
  void initState() {
    super.initState();
    loadTakes();
    loadHiddenTakes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Studio'),
        centerTitle: true,
        actions: <Widget>[
          // Go to recycling bin
          IconButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HiddenTakesView(),
                  ));
            },
            icon: const Icon(Icons.restore_from_trash_outlined),
            tooltip: "View deleted takes",
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TODO support landscape orientation
          Expanded(
              child: switch (getViewing()) {
            // TODO preserve recordwidget state
            (-1) => RecordWidget(
                addTake: addTake,
              ),
            (>= 0) => PlayTakeWidget(
                key: ValueKey(takes[getViewing()].file.path),
                take: takes[getViewing()],
                removeTake: () => delTake(getViewing()),
                editTake: ({bool? favorite}) =>
                    editTake(getViewing(), favorite: favorite),
              ),
            (_) => const Text('Video ID error'),
          }),
          TakeSelector(
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
class TakeSelector extends StatefulWidget {
  const TakeSelector(
      {super.key,
      required this.height,
      required this.itemWidth,
      required this.takeFutures,
      required this.takes,
      required this.setView,
      required this.getView});

  final double height;
  final double itemWidth;

  // prop drilling
  final List takeFutures;
  final List takes;
  final void Function(int currVideo) setView;
  final int Function() getView;

  @override
  State<TakeSelector> createState() => _TakeSelectorState();
}

class _TakeSelectorState extends State<TakeSelector> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: SizedBox(
        height: widget.height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (context, i) => const SizedBox(
            width: 14,
          ),
          itemCount: widget.takeFutures.length + 1,
          itemBuilder: (context, i) {
            if (i == widget.takeFutures.length) {
              // record new button
              return TakeSelectorButton(
                onPressed: () {
                  widget.setView(-1);
                },
                length: widget.itemWidth,
                active: widget.getView() == -1,
                child: const Icon(Icons.camera_alt_outlined),
              );
            } else {
              // previous video button
              return FutureBuilder(
                  // display take, or take is loading
                  future: widget.takeFutures[i],
                  builder: (context, AsyncSnapshot<Take> takeSnapshot) =>
                      takeSnapshot.hasData
                          ? FutureBuilder(
                              // video saved; display video thumbnail once loaded
                              future: takeSnapshot.data!.thumbnailFuture,
                              builder: (context,
                                  AsyncSnapshot<Uint8List> thumbnailSnapshot) {
                                Widget thumbnail;
                                if (thumbnailSnapshot.hasData) {
                                  thumbnail = LayoutBuilder(
                                      // size to make sure it fills up the whole button
                                      builder: (context, constraints) {
                                    return OverflowBox( // TODO add an Ink() widget so inkwell splashes draw above thumbnail
                                      minWidth: constraints.maxWidth,
                                      minHeight: constraints.maxHeight,
                                      maxWidth: double.infinity,
                                      maxHeight: double.infinity,
                                      alignment: Alignment.center,
                                      child:
                                          Image.memory(thumbnailSnapshot.data!),
                                    );
                                  });
                                } else if (thumbnailSnapshot.hasError) {
                                  thumbnail =
                                      const Icon(Icons.broken_image_outlined);
                                } else {
                                  // thumbnail not yet created
                                  thumbnail = const Icon(Icons.video_file);
                                }
                                return TakeSelectorButton(
                                    onPressed: () {
                                      widget.setView(i);
                                    },
                                    length: widget.itemWidth,
                                    active: widget.getView() == i,
                                    child: SizedBox(
                                      height: widget.height,
                                      width: widget.itemWidth,
                                      child: thumbnail,
                                    ));
                              })
                          : (takeSnapshot
                                  .hasError) // no video available: error or loading?
                              ? TakeSelectorButton(
                                  // display error icon
                                  onPressed: null,
                                  length: widget.itemWidth,
                                  active: false,
                                  child: const Icon(Icons.error),
                                )
                              : TakeSelectorButton(
                                  // display loader until video is saved
                                  onPressed: null,
                                  length: widget.itemWidth,
                                  active: false,
                                  child: const CircularProgressIndicator(),
                                ));
            }
          },
        ),
      ),
    );
  }
}

/// A equivalent to RadioButton; a button with the ability to appear 'active' or 'unselected'.
/// Square-shaped.
class TakeSelectorButton extends StatefulWidget {
  /// Creates a ButtonWithActive.
  const TakeSelectorButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.active,
    required this.length,
    this.activeBorderWidth = 5.0,
  });

  /// Runs when button is pressed.
  final void Function()? onPressed;
  /// Child inside of button.
  final Widget? child;
  /// Whether this button is the selected one.
  final bool active;
  /// The length of one side of this square button.
  final double length;
  /// Border width when selected.
  final double activeBorderWidth;

  @override
  State<TakeSelectorButton> createState() => _TakeSelectorButtonState();
}

class _TakeSelectorButtonState extends State<TakeSelectorButton> {
  @override
  Widget build(BuildContext context) {

    return ElevatedButton(
      clipBehavior: Clip.antiAlias,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(.1 * widget.length),
        ),
        padding: EdgeInsets.zero,
        side: switch (widget.active) {
          true => BorderSide(
              width: widget.activeBorderWidth,
              color: Theme.of(context).colorScheme.outline,
            ),
          false => BorderSide.none,
        },
        fixedSize: Size.fromWidth(widget.length),
      ),
      onPressed: widget.onPressed,
      child: Center(
        child: widget.child,
      ),
    );
  }
}
