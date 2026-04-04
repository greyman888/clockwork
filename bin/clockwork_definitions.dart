import 'dart:io';

import 'package:clockwork/clockwork_definitions_cli.dart';
import 'package:clockwork/required_definitions.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  final scriptFilePath = Platform.script.toFilePath();
  final repoRoot = path.dirname(path.dirname(scriptFilePath));
  final cli = ClockworkDefinitionsCli(
    defaultManifestPath: path.join(repoRoot, requiredDefinitionsAssetPath),
  );
  final exitCode = await cli.run(args);

  if (exitCode != 0) {
    exit(exitCode);
  }
}
