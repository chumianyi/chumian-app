import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/app_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/licenses/MIUIX_LICENSE');
    yield LicenseEntryWithLineBreaks(['flutter_miuix'], text);
  });
  runApp(const Bootstrap());
}
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}
class _BootstrapState extends State<Bootstrap> {
  AppStore? store;
  String? error;
  @override
  void initState() { super.initState(); initialize(); }
  Future<void> initialize() async {
    setState(() => error = null);
    try {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      final result = await AppStore.create();
      if (mounted) setState(() => store = result); else result.dispose();
    } catch (_) { if (mounted) setState(() => error = '设备存储初始化失败，请重试。'); }
  }
  @override
  void dispose() { store?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => store != null ? MediaQuery.fromView(view: View.of(context), child: ChumianApp(store: store!)) : MaterialApp(debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: error == null ? const CircularProgressIndicator() : Column(mainAxisSize: MainAxisSize.min, children: [
      Text(error!), const SizedBox(height: 16), FilledButton(onPressed: initialize, child: const Text('重试'))]))));
}
