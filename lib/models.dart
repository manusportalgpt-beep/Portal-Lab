/// Data models for Portal Lab.

class MojangVersion {
  final String id;
  final String type; // release | snapshot | old_beta | old_alpha
  final String releaseTime;
  final String url;
  const MojangVersion({
    required this.id,
    required this.type,
    required this.releaseTime,
    required this.url,
  });
  bool get isRelease => type == 'release';
}

/// A mod / resource registered inside an instance.
class ModEntry {
  final String source; // modrinth | curseforge | local
  final String projectId;
  final String versionId;
  final String name;
  final String fileName;
  final List<String> gameVersions;
  final List<String> loaders;
  final String? iconUrl;

  const ModEntry({
    required this.source,
    required this.projectId,
    required this.versionId,
    required this.name,
    required this.fileName,
    this.gameVersions = const [],
    this.loaders = const [],
    this.iconUrl,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'projectId': projectId,
        'versionId': versionId,
        'name': name,
        'fileName': fileName,
        'gameVersions': gameVersions,
        'loaders': loaders,
        'iconUrl': iconUrl,
      };

  factory ModEntry.fromJson(Map<String, dynamic> j) => ModEntry(
        source: j['source'] as String? ?? 'local',
        projectId: j['projectId'] as String? ?? '',
        versionId: j['versionId'] as String? ?? '',
        name: j['name'] as String? ?? j['fileName'] as String? ?? '',
        fileName: j['fileName'] as String? ?? '',
        gameVersions: (j['gameVersions'] as List?)?.cast<String>() ?? const [],
        loaders: (j['loaders'] as List?)?.cast<String>() ?? const [],
        iconUrl: j['iconUrl'] as String?,
      );
}

/// One Minecraft installation (instance).
class GameInstance {
  String id;
  String name;
  String gameVersion;
  String loader; // vanilla | fabric | quilt | forge | neoforge
  String loaderVersion;
  String created;
  String lastPlayed;
  List<ModEntry> mods;

  GameInstance({
    required this.id,
    required this.name,
    required this.gameVersion,
    required this.loader,
    required this.loaderVersion,
    required this.created,
    this.lastPlayed = '',
    List<ModEntry>? mods,
  }) : mods = mods ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gameVersion': gameVersion,
        'loader': loader,
        'loaderVersion': loaderVersion,
        'created': created,
        'lastPlayed': lastPlayed,
        'mods': mods.map((m) => m.toJson()).toList(),
      };

  factory GameInstance.fromJson(Map<String, dynamic> j) => GameInstance(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Instance',
        gameVersion: j['gameVersion'] as String? ?? '',
        loader: j['loader'] as String? ?? 'vanilla',
        loaderVersion: j['loaderVersion'] as String? ?? '',
        created: j['created'] as String? ?? '',
        lastPlayed: j['lastPlayed'] as String? ?? '',
        mods: (j['mods'] as List?)
                ?.map((e) => ModEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String get loaderLabel {
    switch (loader) {
      case 'fabric':
        return 'Fabric';
      case 'quilt':
        return 'Quilt';
      case 'forge':
        return 'Forge';
      case 'neoforge':
        return 'NeoForge';
      default:
        return 'Vanilla';
    }
  }
}

/// A user account (Microsoft or offline).
class McAccount {
  String uuid;
  String username;
  String type; // msa | offline
  String? accessToken;
  String? refreshToken;
  int? tokenExpiresAt; // epoch ms
  String? skinUrl;
  String? xuid;

  McAccount({
    required this.uuid,
    required this.username,
    required this.type,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiresAt,
    this.skinUrl,
    this.xuid,
  });

  bool get isMsa => type == 'msa';

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'username': username,
        'type': type,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'tokenExpiresAt': tokenExpiresAt,
        'skinUrl': skinUrl,
        'xuid': xuid,
      };

  factory McAccount.fromJson(Map<String, dynamic> j) => McAccount(
        uuid: j['uuid'] as String,
        username: j['username'] as String,
        type: j['type'] as String? ?? 'offline',
        accessToken: j['accessToken'] as String?,
        refreshToken: j['refreshToken'] as String?,
        tokenExpiresAt: j['tokenExpiresAt'] as int?,
        skinUrl: j['skinUrl'] as String?,
        xuid: j['xuid'] as String?,
      );
}

/// A single file download tracked by the download manager.
class DownloadTask {
  final String id;
  final String title;
  final String url;
  final String destPath;
  int received = 0;
  int total = 0;
  String status = 'queued'; // queued | running | done | error | canceled
  String? error;
  final String? tag; // e.g. instance id

  DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.destPath,
    this.tag,
  });

  double get progress {
    if (status == 'done') return 1;
    if (total <= 0) return 0;
    return (received / total).clamp(0.0, 0.999);
  }
}

/// Unified search result from Modrinth or CurseForge.
class CatalogProject {
  final String source; // modrinth | curseforge
  final String id; // slug or numeric id (string)
  final String title;
  final String description;
  final String? iconUrl;
  final int downloads;
  final int follows;
  final String author;
  final String projectType; // mod | modpack | resourcepack | shader
  final List<String> gameVersions;
  final List<String> loaders;

  const CatalogProject({
    required this.source,
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.downloads,
    required this.follows,
    required this.author,
    required this.projectType,
    this.gameVersions = const [],
    this.loaders = const [],
  });
}

/// A downloadable version of a project.
class CatalogVersion {
  final String source;
  final String id;
  final String name;
  final String versionNumber;
  final String? changelog;
  final String datePublished;
  final String downloadUrl;
  final String fileName;
  final int size;
  final String versionType; // release | beta | alpha
  final List<String> gameVersions;
  final List<String> loaders;

  const CatalogVersion({
    required this.source,
    required this.id,
    required this.name,
    required this.versionNumber,
    required this.changelog,
    required this.datePublished,
    required this.downloadUrl,
    required this.fileName,
    required this.size,
    required this.versionType,
    required this.gameVersions,
    required this.loaders,
  });
}
