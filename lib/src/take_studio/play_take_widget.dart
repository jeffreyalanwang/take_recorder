import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:take_recorder/src/takes/excerpt_takes.dart';

/// A widget to view a take's video, delete the take, and edit properties (e.g. favorite).
class PlayTakeWidget extends StatefulWidget {
  /// Construct a PlayTakeWidget.
  const PlayTakeWidget(
      {super.key, required this.take, required this.removeTake, required this.editTake});

  /// The Take object to play.
  final Take take;
  /// Called to mark take as favorite, or undo.
  final void Function({bool? favorite}) editTake;
  /// Called to remove the take.
  final void Function() removeTake;

  @override
  State<PlayTakeWidget> createState() => _PlayTakeWidgetState();
}

class _PlayTakeWidgetState extends State<PlayTakeWidget> {
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(widget.take.file);
    _videoController.initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded( // VideoPlayer should fill all space not taken by controls
          child: FittedBox( // VideoPlayer should be shrunk to fit, keeping aspect ratio
            fit: BoxFit.contain,
            child: SizedBox( // VideoPlayer cannot display without being given a finite size
              height: _videoController.value.size.height,
              width: _videoController.value.size.width,
              child: VideoPlayer(_videoController),
            ),
          ),
        ),
        SizedBox(
          height: 100,
          width: 400,
          child: _ControlsOverlay(
            controller: _videoController,
            take: widget.take,
            editTake: widget.editTake,
            removeTake: widget.removeTake,
          )
        ),
      ],
    );
  }
}

class _ControlsOverlay extends StatefulWidget {
  const _ControlsOverlay({required this.controller, required this.take, required this.editTake, required this.removeTake});

  static const List<double> _examplePlaybackRates = <double>[
    0.25,
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    5.0,
    10.0,
  ];

  final VideoPlayerController controller;
  final Take take;
  final void Function({bool? favorite}) editTake;
  final void Function() removeTake;

  @override
  State<_ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<_ControlsOverlay> {
  void _listener() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(_ControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_listener);
    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(_listener);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Pause/play
        // TODO is this supposed to be animated? if so fix
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: widget.controller.value.isPlaying
              ? const ColoredBox(
                  key: ValueKey<int>(0),
                  color: Colors.black26,
                  child: Center(
                    child: Icon(
                      Icons.pause,
                      color: Colors.white,
                      size: 100.0,
                      semanticLabel: 'Pause',
                    ),
                  ),
                )
              : const ColoredBox(
                  key: ValueKey<int>(1),
                  color: Colors.black26,
                  child: Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 100.0,
                      semanticLabel: 'Play',
                    ),
                  ),
                ),
        ),
        // Detect pause/play
        GestureDetector(
          onTap: () {
            widget.controller.value.isPlaying
                ? widget.controller.pause()
                : widget.controller.play();
          },
        ),
        // Favorite button
        Align(
          alignment: Alignment.centerLeft,
          child: LayoutBuilder(
            builder: (context, BoxConstraints constraints)
              => Padding(
                padding: EdgeInsets.only(left: constraints.maxWidth / 3 - 20),
                child: IconButton(
                  iconSize: 40,
                  isSelected: widget.take.favorite,
                  onPressed: () => widget.editTake(favorite: !widget.take.favorite),
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  selectedIcon: const Icon(Icons.favorite_outline, color: Colors.red),
                ),
              ),
          ),
        ),
        // Delete button
        Align(
          alignment: Alignment.centerLeft,
          child: LayoutBuilder(
            builder: (context, BoxConstraints constraints)
              => Padding(
                padding: EdgeInsets.only(right: constraints.maxWidth / 3 - 20),
                child: IconButton(
                  iconSize: 40,
                  onPressed: () => widget.removeTake(),
                  icon: const Icon(Icons.delete),
                ),
              ),
          ),
        ),
        // Playback speed
        Align(
          alignment: Alignment.topRight,
          child: PopupMenuButton<double>(
            initialValue: widget.controller.value.playbackSpeed,
            tooltip: 'Playback speed',
            onSelected: (double speed) {
              widget.controller.setPlaybackSpeed(speed);
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuItem<double>>[
                for (final double speed
                    in _ControlsOverlay._examplePlaybackRates)
                  PopupMenuItem<double>(
                    value: speed,
                    child: Text('${speed}x'),
                  )
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                // Using less vertical padding as the text is also longer
                // horizontally, so it feels like it would need more spacing
                // horizontally (matching the aspect ratio of the video).
                vertical: 12,
                horizontal: 16,
              ),
              child: Text('${widget.controller.value.playbackSpeed}x'),
            ),
          ),
        ),
        // Progress bar
        VideoProgressIndicator(widget.controller, allowScrubbing: true),
      ],
    );
  }
}
