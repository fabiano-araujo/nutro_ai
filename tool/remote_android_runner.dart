import 'dart:io' as io;

const _defaultDevice = '100.72.202.76:5555';
const _packageName = 'br.com.snapdark.apps.nutreai';
const _activityName = 'br.com.snapdark.apps.nutreai/.MainActivity';
const _debugApkPath = 'build/app/outputs/flutter-apk/app-debug.apk';

const _sourceRoots = <String>[
  'lib',
  'assets',
  'android/app/src/main',
  'android/app/src/debug',
  'android/app/src/profile',
];

const _sourceFiles = <String>[
  'pubspec.yaml',
  'pubspec.lock',
  'android/app/build.gradle.kts',
  'android/build.gradle.kts',
  'android/settings.gradle.kts',
  'android/gradle.properties',
];

Future<void> main(List<String> args) async {
  try {
    final options = _Options.parse(args);

    if (options.showHelp) {
      _printUsage();
      return;
    }

    switch (options.command) {
      case 'quick':
      case 'open':
        await _quickRun(options);
        return;
      case 'hot':
      case 'run':
        await _hotRun(options);
        return;
      case 'connect':
        await _connect(options);
        return;
      default:
        throw _ToolException('Comando desconhecido: ${options.command}');
    }
  } on _ToolException catch (error) {
    io.stderr.writeln('[remote-android] ${error.message}');
    io.exitCode = error.exitCode;
  }
}

Future<void> _quickRun(_Options options) async {
  final adb = options.adbPath ?? _defaultAdbPath();
  final flutter = options.flutterPath ?? _defaultFlutterPath();
  final apk = io.File(_debugApkPath);

  await _connect(options.copyWith(adbPath: adb));

  final installed = await _isPackageInstalled(adb, options.device);
  var apkExists = apk.existsSync();
  var sourcesChanged = false;

  if (apkExists) {
    final latestSource = _latestSourceChange();
    sourcesChanged = latestSource != null &&
        latestSource.modified.isAfter(apk.lastModifiedSync());

    if (latestSource != null) {
      _log(
        'Fonte mais recente: ${latestSource.path} '
        '(${latestSource.modified.toLocal()})',
      );
      _log('APK local: $_debugApkPath (${apk.lastModifiedSync().toLocal()})');
    }
  }

  final shouldBuild = options.forceBuild || !apkExists || sourcesChanged;

  if (shouldBuild) {
    if (options.noBuild) {
      throw _ToolException(
        'APK ausente ou desatualizado, mas --no-build foi informado.',
      );
    }

    final reason = !apkExists
        ? 'APK local nao existe'
        : options.forceBuild
            ? '--force-build informado'
            : 'arquivos fonte mudaram depois do APK';
    _log('Build debug necessario: $reason.');
    await _runChecked(flutter, ['build', 'apk', '--debug']);
    apkExists = apk.existsSync();

    if (!apkExists) {
      throw _ToolException('Build terminou, mas o APK nao foi encontrado.');
    }
  } else {
    _log('Build ignorado: APK local existe e as fontes nao mudaram.');
  }

  final shouldInstall = options.forceInstall || !installed || shouldBuild;

  if (shouldInstall) {
    final reason = !installed
        ? 'app nao esta instalado'
        : options.forceInstall
            ? '--force-install informado'
            : 'APK foi recompilado';
    _log('Instalacao necessaria: $reason.');
    await _runChecked(adb, ['-s', options.device, 'install', '-r', apk.path]);
  } else {
    _log('Instalacao ignorada: app instalado e APK nao mudou nesta execucao.');
  }

  await _startInstalledApp(adb, options.device);
}

Future<void> _hotRun(_Options options) async {
  final adb = options.adbPath ?? _defaultAdbPath();
  final flutter = options.flutterPath ?? _defaultFlutterPath();

  await _connect(options.copyWith(adbPath: adb));

  final flutterArgs = <String>[
    'run',
    '-d',
    options.device,
    ...options.passThroughArgs,
  ];

  _log(
    'Iniciando flutter run persistente. Use r para hot reload, '
    'R para hot restart e q para sair.',
  );
  _printCommand(flutter, flutterArgs);

  final process = await io.Process.start(
    flutter,
    flutterArgs,
    mode: io.ProcessStartMode.inheritStdio,
    runInShell: _needsShell(flutter),
  );
  io.exitCode = await process.exitCode;
}

Future<void> _connect(_Options options) async {
  final adb = options.adbPath ?? _defaultAdbPath();
  _log('Conectando no device ${options.device}...');
  await _runChecked(adb, ['connect', options.device]);
}

Future<bool> _isPackageInstalled(String adb, String device) async {
  final result = await _run(
    adb,
    ['-s', device, 'shell', 'pm', 'path', _packageName],
    allowFailure: true,
  );

  final installed = result.exitCode == 0 && result.stdout.contains('package:');
  _log(installed ? 'App ja instalado no device.' : 'App nao instalado.');
  return installed;
}

Future<void> _startInstalledApp(String adb, String device) async {
  _log('Abrindo $_packageName no device $device...');
  await _runChecked(
    adb,
    ['-s', device, 'shell', 'am', 'force-stop', _packageName],
  );
  await _runChecked(
    adb,
    ['-s', device, 'shell', 'am', 'start', '-n', _activityName],
  );
}

_SourceChange? _latestSourceChange() {
  _SourceChange? latest;

  for (final root in _sourceRoots) {
    final directory = io.Directory(root);
    if (!directory.existsSync()) {
      continue;
    }

    for (final entity
        in directory.listSync(recursive: true, followLinks: false)) {
      if (entity is! io.File) {
        continue;
      }

      final modified = _tryLastModified(entity);
      if (modified == null) {
        continue;
      }

      if (latest == null || modified.isAfter(latest.modified)) {
        latest = _SourceChange(entity.path, modified);
      }
    }
  }

  for (final filePath in _sourceFiles) {
    final file = io.File(filePath);
    if (!file.existsSync()) {
      continue;
    }

    final modified = _tryLastModified(file);
    if (modified == null) {
      continue;
    }

    if (latest == null || modified.isAfter(latest.modified)) {
      latest = _SourceChange(file.path, modified);
    }
  }

  return latest;
}

DateTime? _tryLastModified(io.FileSystemEntity entity) {
  try {
    return entity.statSync().modified;
  } on io.FileSystemException {
    return null;
  }
}

Future<_CommandResult> _runChecked(String executable, List<String> args) async {
  final result = await _run(executable, args);
  if (result.exitCode != 0) {
    throw _ToolException(
      'Comando falhou com exit code ${result.exitCode}: '
      '${_formatCommand(executable, args)}',
      exitCode: result.exitCode,
    );
  }
  return result;
}

Future<_CommandResult> _run(
  String executable,
  List<String> args, {
  bool allowFailure = false,
}) async {
  _printCommand(executable, args);
  final result = await io.Process.run(
    executable,
    args,
    runInShell: _needsShell(executable),
  );

  final stdoutText = result.stdout.toString();
  final stderrText = result.stderr.toString();

  if (stdoutText.trim().isNotEmpty) {
    io.stdout.write(stdoutText);
  }
  if (stderrText.trim().isNotEmpty) {
    io.stderr.write(stderrText);
  }

  if (!allowFailure && result.exitCode != 0) {
    throw _ToolException(
      'Comando falhou com exit code ${result.exitCode}: '
      '${_formatCommand(executable, args)}',
      exitCode: result.exitCode,
    );
  }

  return _CommandResult(result.exitCode, stdoutText, stderrText);
}

String _defaultAdbPath() {
  final candidates = <String>[
    if (io.Platform.environment['ANDROID_HOME'] != null)
      _join(io.Platform.environment['ANDROID_HOME']!, 'platform-tools',
          'adb.exe'),
    if (io.Platform.environment['ANDROID_SDK_ROOT'] != null)
      _join(
        io.Platform.environment['ANDROID_SDK_ROOT']!,
        'platform-tools',
        'adb.exe',
      ),
    if (io.Platform.environment['LOCALAPPDATA'] != null)
      _join(
        io.Platform.environment['LOCALAPPDATA']!,
        'Android',
        'Sdk',
        'platform-tools',
        'adb.exe',
      ),
  ];

  for (final candidate in candidates) {
    if (io.File(candidate).existsSync()) {
      return candidate;
    }
  }

  return io.Platform.isWindows ? 'adb.exe' : 'adb';
}

String _defaultFlutterPath() {
  final flutterRoot = io.Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final fromRoot = _join(
      flutterRoot,
      'bin',
      io.Platform.isWindows ? 'flutter.bat' : 'flutter',
    );
    if (io.File(fromRoot).existsSync()) {
      return fromRoot;
    }
  }

  final windowsDefault = r'C:\flutter\bin\flutter.bat';
  if (io.Platform.isWindows && io.File(windowsDefault).existsSync()) {
    return windowsDefault;
  }

  return io.Platform.isWindows ? 'flutter.bat' : 'flutter';
}

bool _needsShell(String executable) {
  if (!io.Platform.isWindows) {
    return false;
  }

  final lower = executable.toLowerCase();
  return lower.endsWith('.bat') || lower.endsWith('.cmd');
}

String _join(
  String part1,
  String part2, [
  String? part3,
  String? part4,
  String? part5,
]) {
  final parts = [
    part1,
    part2,
    if (part3 != null) part3,
    if (part4 != null) part4,
    if (part5 != null) part5,
  ];
  return parts.join(io.Platform.pathSeparator);
}

void _printUsage() {
  io.stdout.writeln('''
Uso:
  dart run tool/remote_android_runner.dart quick [opcoes]
  dart run tool/remote_android_runner.dart hot [opcoes] [-- argumentos_do_flutter_run]
  dart run tool/remote_android_runner.dart connect [opcoes]

Comandos:
  quick    Conecta no device, recompila se necessario, instala se necessario e abre o app.
  hot      Conecta no device e inicia flutter run persistente para hot reload.
  connect  Apenas executa adb connect.

Opcoes:
  --device <id>       Device ADB. Padrao: $_defaultDevice
  --adb <path>        Caminho do adb. Padrao: Android SDK local ou PATH.
  --flutter <path>    Caminho do flutter. Padrao: FLUTTER_ROOT, C:\\flutter ou PATH.
  --force-build       Recompila o APK debug mesmo sem mudancas detectadas.
  --force-install     Reinstala o APK mesmo se o app ja estiver instalado.
  --no-build          Falha se o APK local nao existir ou estiver desatualizado.
  -h, --help          Mostra esta ajuda.

Exemplos:
  dart run tool/remote_android_runner.dart quick
  dart run tool/remote_android_runner.dart hot
  dart run tool/remote_android_runner.dart hot -- --dart-define=FOO=bar
''');
}

void _printCommand(String executable, List<String> args) {
  io.stdout.writeln(r'$ ' + _formatCommand(executable, args));
}

String _formatCommand(String executable, List<String> args) {
  return [executable, ...args].map(_quoteArg).join(' ');
}

String _quoteArg(String arg) {
  if (arg.isEmpty) {
    return '""';
  }
  if (!arg.contains(RegExp(r'\s'))) {
    return arg;
  }
  return '"${arg.replaceAll('"', r'\"')}"';
}

void _log(String message) {
  io.stdout.writeln('[remote-android] $message');
}

class _Options {
  const _Options({
    required this.command,
    required this.device,
    required this.passThroughArgs,
    this.adbPath,
    this.flutterPath,
    this.forceBuild = false,
    this.forceInstall = false,
    this.noBuild = false,
    this.showHelp = false,
  });

  final String command;
  final String device;
  final String? adbPath;
  final String? flutterPath;
  final bool forceBuild;
  final bool forceInstall;
  final bool noBuild;
  final bool showHelp;
  final List<String> passThroughArgs;

  _Options copyWith({
    String? adbPath,
    String? flutterPath,
  }) {
    return _Options(
      command: command,
      device: device,
      adbPath: adbPath ?? this.adbPath,
      flutterPath: flutterPath ?? this.flutterPath,
      forceBuild: forceBuild,
      forceInstall: forceInstall,
      noBuild: noBuild,
      showHelp: showHelp,
      passThroughArgs: passThroughArgs,
    );
  }

  static _Options parse(List<String> args) {
    var command = 'quick';
    var device = _defaultDevice;
    String? adbPath;
    String? flutterPath;
    var forceBuild = false;
    var forceInstall = false;
    var noBuild = false;
    var showHelp = false;
    final passThroughArgs = <String>[];

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];

      if (arg == '--') {
        passThroughArgs.addAll(args.skip(i + 1));
        break;
      }

      if (arg == '-h' || arg == '--help') {
        showHelp = true;
      } else if (arg == '--force-build') {
        forceBuild = true;
      } else if (arg == '--force-install') {
        forceInstall = true;
      } else if (arg == '--no-build') {
        noBuild = true;
      } else if (arg.startsWith('--device=')) {
        device = arg.substring('--device='.length);
      } else if (arg == '--device') {
        device = _readOptionValue(args, ++i, '--device');
      } else if (arg.startsWith('--adb=')) {
        adbPath = arg.substring('--adb='.length);
      } else if (arg == '--adb') {
        adbPath = _readOptionValue(args, ++i, '--adb');
      } else if (arg.startsWith('--flutter=')) {
        flutterPath = arg.substring('--flutter='.length);
      } else if (arg == '--flutter') {
        flutterPath = _readOptionValue(args, ++i, '--flutter');
      } else if (!arg.startsWith('-')) {
        command = arg;
      } else {
        throw _ToolException('Opcao desconhecida: $arg');
      }
    }

    return _Options(
      command: command,
      device: device,
      adbPath: adbPath,
      flutterPath: flutterPath,
      forceBuild: forceBuild,
      forceInstall: forceInstall,
      noBuild: noBuild,
      showHelp: showHelp,
      passThroughArgs: passThroughArgs,
    );
  }

  static String _readOptionValue(List<String> args, int index, String option) {
    if (index >= args.length || args[index].startsWith('-')) {
      throw _ToolException('Valor ausente para $option');
    }
    return args[index];
  }
}

class _SourceChange {
  const _SourceChange(this.path, this.modified);

  final String path;
  final DateTime modified;
}

class _CommandResult {
  const _CommandResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;
}

class _ToolException implements Exception {
  const _ToolException(this.message, {this.exitCode = 1});

  final String message;
  final int exitCode;
}
