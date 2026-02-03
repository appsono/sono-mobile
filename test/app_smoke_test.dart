import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sono/services/utils/theme_service.dart';
import 'package:sono/services/playlist/playlist_service.dart';

void main() {
  testWidgets('app boots without errors', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider(create: (_) => PlaylistService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer<ThemeService>(
              builder: (context, themeService, child) {
                return Center(child: Text('Theme: ${themeService.themeMode}'));
              },
            ),
          ),
        ),
      ),
    );

    //verify the widget tree is built successfully
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    //verify providers are accessible
    final themeService = Provider.of<ThemeService>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(themeService, isNotNull);

    final playlistService = Provider.of<PlaylistService>(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(playlistService, isNotNull);
  });
}
