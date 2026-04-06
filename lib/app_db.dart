import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'db_helper.dart';
import 'required_definitions.dart';

export 'db_helper.dart';

final dbHelper = DbHelper(
  databaseDirectory: DbHelper.databaseDirectoryPathForBuildMode(
    isReleaseMode: kReleaseMode,
  ),
  requiredDefinitionsLoader: () =>
      rootBundle.loadString(requiredDefinitionsAssetPath),
);
