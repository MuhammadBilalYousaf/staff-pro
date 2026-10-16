import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/routing/app_router.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/theme/app_theme.dart';
import 'package:staffpro/data/firestore_database.dart';
import 'package:staffpro/firebase_options.dart';
import 'package:staffpro/qa/full_qa_suite.dart';
import 'package:staffpro/qa/qa_exit_stub.dart' if (dart.library.io) 'package:staffpro/qa/qa_exit_io.dart';
import 'package:staffpro/qa/qa_location_service.dart';
import 'package:staffpro/qa/super_admin_live_test.dart';
import 'package:staffpro/services/location_service.dart';
import 'package:staffpro/state/app_state.dart';

/// Run with: flutter run -d windows --dart-define=QA=true
const bool kQaMode = bool.fromEnvironment('QA', defaultValue: false);

/// Visual Super Admin nav walkthrough: --dart-define=QA_UI=true
const bool kQaUiMode = bool.fromEnvironment('QA_UI', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }
  final location = kQaMode || kQaUiMode ? QaLocationService() : LocationService();
  final db = FirestoreDatabase.instance;
  final controller = StaffProController(db, location);
  await controller.bootstrap();
  if (!kQaMode && !kQaUiMode) {
    // ignore: unawaited_futures
    location.ensurePermission();
  }
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
  bool _qaStarted = false;

  @override
  void initState() {
    super.initState();
    if (kQaMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runHeadlessQa());
    }
  }

  Future<void> _runHeadlessQa() async {
    if (_qaStarted) return;
    _qaStarted = true;
    // Let the first frame paint so GoRouter is ready.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final report = await FullQaSuite(widget.controller, router).run();
    // Ignore: print is intentional for CI/console QA output.
    // ignore: avoid_print
    print(report.summary());
    qaExit(report.success ? 0 : 1);
  }

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
          final content = GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child ?? const SizedBox.shrink(),
          );
          if (!kQaUiMode) return content;
          return Stack(
            children: [
              content,
              SuperAdminLiveTestOverlay(
                router: router,
                controller: widget.controller,
              ),
            ],
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
