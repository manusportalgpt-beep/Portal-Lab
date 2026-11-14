// Data models for Portal Lab.

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
  bool get isSnapshot => type == 'snapshot';
  bool get isOld => type == 'old_beta' || type == 'old_alpha';
}

/// A mod / resource registered inside an instance.
class ModEntry {
  String source; // modrinth | curseforge | local
  String projectId;
  String versionId;
  String name;
  String fileName;
  List<String> gameVersions;
  List<String> loaders;
  String? iconUrl;
  String? author;
  String? versionNumber;
  String? description;
  String? downloadUrl;
  int? fileSize;
  bool enabled;
  String folder; // mods | resourcepacks | shaderpacks | datapacks | config

  ModEntry({
    required this.source,
    required this.projectId,
    required this.versionId,
    required this.name,
    required this.fileName,
    this.gameVersions = const [],
    this.loaders = const [],
    this.iconUrl,
    this.author,
    this.versionNumber,
    this.description,
    this.downloadUrl,
    this.fileSize,
    this.enabled = true,
    this.folder = 'mods',
  });

  bool get isDisabledFile =>
      fileName.endsWith('.disabled') || fileName.endsWith('.jar.disabled');

  /// Real jar name without the ".disabled" suffix.
  String get activeFileName => fileName.endsWith('.disabled')
      ? fileName.substring(0, fileName.length - '.disabled'.length)
      : fileName;

  Map<String, dynamic> toJson() => {
        'source': source,
        'projectId': projectId,
        'versionId': versionId,
        'name': name,
        'fileName': fileName,
        'gameVersions': gameVersions,
        'loaders': loaders,
        'iconUrl': iconUrl,
        'author': author,
        'versionNumber': versionNumber,
        'description': description,
        'downloadUrl': downloadUrl,
        'fileSize': fileSize,
        'enabled': enabled,
        'folder': folder,
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
        author: j['author'] as String?,
        versionNumber: j['versionNumber'] as String?,
        description: j['description'] as String?,
        downloadUrl: j['downloadUrl'] as String?,
        fileSize: j['fileSize'] as int?,
        enabled: j['enabled'] as bool? ?? true,
        folder: j['folder'] as String? ?? 'mods',
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
  String icon; // preset icon id
  String notes;
  int memoryMb; // 0 = auto
  String javaArgs;

  GameInstance({
    required this.id,
    required this.name,
    required this.gameVersion,
    required this.loader,
    required this.loaderVersion,
    required this.created,
    this.lastPlayed = '',
    List<ModEntry>? mods,
    this.icon = 'grass',
    this.notes = '',
    this.memoryMb = 0,
    this.javaArgs = '',
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
        'icon': icon,
        'notes': notes,
        'memoryMb': memoryMb,
        'javaArgs': javaArgs,
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
        icon: j['icon'] as String? ?? 'grass',
        notes: j['notes'] as String? ?? '',
        memoryMb: j['memoryMb'] as int? ?? 0,
        javaArgs: j['javaArgs'] as String? ?? '',
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

  int get enabledModsCount => mods.where((m) => m.enabled).length;
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
  String? skinModel; // classic | slim — active Microsoft skin model
  String? localSkinPath; // device-only skin override file (offline)
  String? localSkinModel; // classic | slim — local override model

  McAccount({
    required this.uuid,
    required this.username,
    required this.type,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiresAt,
    this.skinUrl,
    this.xuid,
    this.skinModel,
    this.localSkinPath,
    this.localSkinModel,
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
        'skinModel': skinModel,
        'localSkinPath': localSkinPath,
        'localSkinModel': localSkinModel,
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
        skinModel: j['skinModel'] as String?,
        localSkinPath: j['localSkinPath'] as String?,
        localSkinModel: j['localSkinModel'] as String?,
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
  final String? iconUrl;

  DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.destPath,
    this.tag,
    this.iconUrl,
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
  final String projectType; // mod | modpack | resourcepack | shader | datapack
  final List<String> gameVersions;
  final List<String> loaders;
  final String? galleryUrl; // first gallery image

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
    this.galleryUrl,
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

/// A locally favorited catalog project.
class FavoriteProject {
  final String source;
  final String id;
  final String title;
  final String description;
  final String? iconUrl;
  final String author;
  final String projectType;
  final int downloads;
  final List<String> gameVersions;
  final List<String> loaders;

  const FavoriteProject({
    required this.source,
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.author,
    required this.projectType,
    required this.downloads,
    required this.gameVersions,
    required this.loaders,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'id': id,
        'title': title,
        'description': description,
        'iconUrl': iconUrl,
        'author': author,
        'projectType': projectType,
        'downloads': downloads,
        'gameVersions': gameVersions,
        'loaders': loaders,
      };

  factory FavoriteProject.fromJson(Map<String, dynamic> j) =>
      FavoriteProject(
        source: j['source'] as String? ?? 'modrinth',
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        iconUrl: j['iconUrl'] as String?,
        author: j['author'] as String? ?? '',
        projectType: j['projectType'] as String? ?? 'mod',
        downloads: j['downloads'] as int? ?? 0,
        gameVersions: (j['gameVersions'] as List?)?.cast<String>() ?? const [],
        loaders: (j['loaders'] as List?)?.cast<String>() ?? const [],
      );

  CatalogProject toCatalog() => CatalogProject(
        source: source,
        id: id,
        title: title,
        description: description,
        iconUrl: iconUrl,
        downloads: downloads,
        follows: 0,
        author: author,
        projectType: projectType,
        gameVersions: gameVersions,
        loaders: loaders,
      );
}

/// One message in the Portalus chat.
class ChatMessage {
  final String role; // user | assistant | system
  final String content;
  final DateTime ts;

  ChatMessage({required this.role, required this.content, DateTime? ts})
      : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() =>
      {'role': role, 'content': content, 'ts': ts.toIso8601String()};

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: j['role'] as String? ?? 'user',
        content: j['content'] as String? ?? '',
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );
}

/// A generated image entry (Portalus image studio).
class AiImageItem {
  final String prompt;
  final String url; // pollinations url (also used for reload)
  String? localPath;
  final String model;
  final int width;
  final int height;
  final DateTime ts;

  AiImageItem({
    required this.prompt,
    required this.url,
    required this.model,
    required this.width,
    required this.height,
    this.localPath,
    DateTime? ts,
  }) : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'url': url,
        'localPath': localPath,
        'model': model,
        'width': width,
        'height': height,
        'ts': ts.toIso8601String(),
      };

  factory AiImageItem.fromJson(Map<String, dynamic> j) => AiImageItem(
        prompt: j['prompt'] as String? ?? '',
        url: j['url'] as String? ?? '',
        localPath: j['localPath'] as String?,
        model: j['model'] as String? ?? 'flux',
        width: j['width'] as int? ?? 1024,
        height: j['height'] as int? ?? 1024,
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
      );
}

/// A Pollinations text model descriptor.
class PollinationsModel {
  final String name;
  final String description;
  final bool reasoning;
  final bool vision;
  final String tier;
  final List<String> aliases;
  final List<String> outputModalities;

  const PollinationsModel({
    required this.name,
    required this.description,
    this.reasoning = false,
    this.vision = false,
    this.tier = 'anonymous',
    this.aliases = const [],
    this.outputModalities = const ['text'],
  });

  bool get isImage => outputModalities.contains('image');

  /// True when the model can be used without an API key.
  bool get tierAvailable =>
      tier.isEmpty || tier == 'anonymous' || tier == 'seed';

  factory PollinationsModel.fromJson(Map<String, dynamic> j) =>
      PollinationsModel(
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        reasoning: j['reasoning'] as bool? ?? false,
        vision: j['vision'] as bool? ?? false,
        tier: j['tier'] as String? ?? 'anonymous',
        aliases: (j['aliases'] as List?)?.cast<String>() ?? const [],
        outputModalities:
            (j['output_modalities'] as List?)?.cast<String>() ?? const ['text'],
      );
}

/// On-screen control button of the desktop-control overlay.
class ControlButton {
  String name;
  int keycode; // GLFW keycode or Pojav special (<0)
  double x; // 0..100 percent of screen
  double y; // 0..100 percent
  double size; // logical dp
  double opacity; // 0..1
  bool isToggle;

  ControlButton({
    required this.name,
    required this.keycode,
    required this.x,
    required this.y,
    this.size = 56,
    this.opacity = 0.65,
    this.isToggle = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'keycode': keycode,
        'x': x,
        'y': y,
        'size': size,
        'opacity': opacity,
        'isToggle': isToggle,
      };

  factory ControlButton.fromJson(Map<String, dynamic> j) => ControlButton(
        name: j['name'] as String? ?? '',
        keycode: j['keycode'] as int? ?? 0,
        x: (j['x'] as num?)?.toDouble() ?? 0,
        y: (j['y'] as num?)?.toDouble() ?? 0,
        size: (j['size'] as num?)?.toDouble() ?? 56,
        opacity: (j['opacity'] as num?)?.toDouble() ?? 0.65,
        isToggle: j['isToggle'] as bool? ?? false,
      );
}

/// Global settings for the control overlay.
class ControlsProfile {
  double opacity;
  bool haptics;
  String name;

  ControlsProfile({
    this.opacity = 0.65,
    this.haptics = true,
    this.name = 'Portal Lab',
  });

  Map<String, dynamic> toJson() =>
      {'opacity': opacity, 'haptics': haptics, 'name': name};

  factory ControlsProfile.fromJson(Map<String, dynamic> j) => ControlsProfile(
        opacity: (j['opacity'] as num?)?.toDouble() ?? 0.65,
        haptics: j['haptics'] as bool? ?? true,
        name: j['name'] as String? ?? 'Portal Lab',
      );
}
