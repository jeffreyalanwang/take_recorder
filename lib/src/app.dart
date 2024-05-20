import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'take_studio/take_studio_view.dart';

import 'sample_feature/sample_item_details_view.dart';
import 'sample_feature/sample_item_list_view.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;

  ThemeData _themeFromDynamic(ColorScheme? dynamic, bool dark) {
    ColorScheme colors;
    ThemeData theme = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    if (dynamic != null) {
      colors = dynamic.harmonized();
    } else {
      const seedColor = Color.fromARGB(255, 51, 51, 51);
      colors = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: dark ? Brightness.dark : Brightness.light,
      );
    }

    theme = theme.copyWith(
      colorScheme: colors,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? Colors.black : colors.inversePrimary,
      ),
    );

    return theme;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            var lightTheme = _themeFromDynamic(lightDynamic, false);
            var darkTheme = _themeFromDynamic(darkDynamic, true);

            return MaterialApp(
              // Providing a restorationScopeId allows the Navigator built by the
              // MaterialApp to restore the navigation stack when a user leaves and
              // returns to the app after it has been killed while running in the
              // background.
              restorationScopeId: 'app',
            
              // Provide the generated AppLocalizations to the MaterialApp. This
              // allows descendant Widgets to display the correct translations
              // depending on the user's locale.
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en', ''), // English, no country code
              ],
            
              // Use AppLocalizations to configure the correct application title
              // depending on the user's locale.
              //
              // The appTitle is defined in .arb files found in the localization
              // directory.
              onGenerateTitle: (BuildContext context) =>
                  AppLocalizations.of(context)!.appTitle,
            
              // Define a light and dark color theme. Then, read the user's
              // preferred ThemeMode (light, dark, or system default) from the
              // SettingsController to display the correct theme.
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: settingsController.themeMode,
            
              // Define a function to handle named routes in order to support
              // Flutter web url navigation and deep linking.
              onGenerateRoute: (RouteSettings routeSettings) {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (BuildContext context) {
                    switch (routeSettings.name) {
                      case SettingsView.routeName:
                        return SettingsView(controller: settingsController);
                      case SampleItemDetailsView.routeName:
                        return const SampleItemDetailsView();
                      case SampleItemListView.routeName:
                      default:
                        return const TakeStudioView(excerptID: 'placeholder',);
                    }
                  },
                );
              },
            );
          }
        );
      },
    );
  }
}
