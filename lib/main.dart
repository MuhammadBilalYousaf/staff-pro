import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/routing/app_router.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/theme/app_theme.dart';
import 'package:staffpro/data/local_database.dart';
import 'package:staffpro/services/location_service.dart';
import 'package:staffpro/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }
  final location = LocationService();
  final db = LocalDatabase.instance;
  final controller = StaffProController(db, location);
  await controller.bootstrap();
  // Request GPS after UI is up so cold start is not blocked by the permission dialog.
  // ignore: unawaited_futures
  location.ensurePermission();
  runApp(StaffProApp(controller: controller));
}

class StaffProApp extends StatefulWidget {
  const StaffProApp({super.key, required this.controller});
  final StaffProController controller;

  @override
  State<StaffProApp> createState() => _StaffProAppState();
}

class _StaffProAppState extends State<StaffProApp> {
  late final router = createRouter(widget.controller);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: MaterialApp.router(
        title: 'StaffPro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) {
          return GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

class AppStatusBar extends StatelessWidget {
  const AppStatusBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: child,
    );
  }
}
