import 'dart:io';
import 'package:flutter/material.dart';
import '../takes/excerpt_takes.dart';

// TODO i18n
const hiddenTakesHeadline = 'Hidden Takes';
const lostTakesHeadline = 'Lost Takes';

// TODO when this screen is shown, pause camera usage on previous screen.
/// View and restore hidden takes and "lost" takes (those unlisted within what's loaded from json files).
class HiddenTakesView extends StatelessWidget {
  /// Construct a HiddenTakesView.
  const HiddenTakesView({super.key, required this.markedDeletedTakes, required this.unknownVideos});

  /// List of any takes that have been deleted
  final List<Take> markedDeletedTakes;

  /// List of videos without a corresponding data entry from Json or app usage
  // get from TakeStudioView state so that we can refactor and ask a
  // ChangeNotifier object to process this, keeping state logic in one main state
  final List<File> unknownVideos;

  @override
  Widget build(BuildContext context) {
    final headlineTheme = Theme.of(context).textTheme.headlineLarge;
    const divider = Divider(
      indent: 20.0,
      endIndent: 20.0,
    );
    const sectionPadding = EdgeInsets.only(
      top: 20.0,
      bottom: 10.0,
      left: 20.0,
      right: 20.0,
    );
    const tileWidth = 50.0;
    const minTilePadding = 10.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted takes'),
      ),

      /// This Column holds the sections and dividers for the page.
      body: Column(children: <Widget>[
        // Leading padding
        const Padding(
          padding: EdgeInsets.only(
            top: 5.0,
          ),
        ),
        // Section: Hidden takes
        Padding(
          padding: sectionPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Section header
              Text(
                textAlign: TextAlign.start,
                style: headlineTheme,
                hiddenTakesHeadline,
              ),
              ListView.builder(
                itemBuilder: (context, i)
                  => ListTile(
                    leading: icon,
                    title: takeNumber,
                    subtitle: metadata,
                  ),
              ),
            ],
          ),
        ),
        // Section divider
        divider,
        // Section: Lost takes
        Padding(
          padding: sectionPadding,
          child: Column(
            children: <Widget>[
              Text(
                style: headlineTheme,
                lostTakesHeadline,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
