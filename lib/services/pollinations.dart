import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'net.dart';

/// Portalus — the built-in AI assistant, powered by open Pollinations models.
class PollinationsService {
  static const textBase = 'https://text.pollinations.ai';
  static const imageBase = 'https://image.pollinations.ai';

  static List<PollinationsModel>? _modelsCache;
  static DateTime _modelsTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Fallback list used when the models endpoint is unreachable.
  static const fallbackTextModels = [
    PollinationsModel(
        name: 'openai-fast',
        description: 'Fast general-purpose model',
        aliases: ['openai']),
    PollinationsModel(
        name: 'mistral', description: 'Mistral open model'),
    PollinationsModel(
        name: 'qwen-coder', description: 'Coding-focused model'),
    PollinationsModel(name: 'deepseek', description: 'DeepSeek reasoning'),
    PollinationsModel(name: 'llama', description: 'Llama open model'),
  ];

  static const fallbackImageModels = [
    PollinationsModel(
        name: 'flux',
        description: 'FLUX — high quality',
        outputModalities: ['image']),
    PollinationsModel(
        name: 'turbo',
        description: 'Turbo — fast generation',
        outputModalities: ['image']),
  ];

  /// Fetch the available text models (cached for 10 minutes).
  static Future<List<PollinationsModel>> models({bool force = false}) async {
    if (!force &&
        _modelsCache != null &&
        DateTime.now().difference(_modelsTime) <
            const Duration(minutes: 10)) {
      return _modelsCache!;
    }
    try {
      final r = await http
          .get(Uri.parse('$textBase/models'),
              headers: {'User-Agent': Net.ua, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        final list = j is List ? j : (j['data'] as List? ?? []);
        final parsed = list
            .map((e) {
              try {
                return PollinationsModel.fromJson(
                    (e as Map).cast<String, dynamic>());
              } catch (_) {
                return null;
              }
            })
            .whereType<PollinationsModel>()
            .where((m) =>
                m.name.isNotEmpty && !m.isImage && m.tierAvailable)
            .toList();
        if (parsed.isNotEmpty) {
          _modelsCache = parsed;
          _modelsTime = DateTime.now();
          return parsed;
        }
      }
    } catch (_) {}
    return _modelsCache ?? fallbackTextModels;
  }

  /// Image-capable models.
  static Future<List<PollinationsModel>> imageModels() async {
    try {
      final all = await models();
      final imgs = all.where((m) => m.isImage).toList();
      if (imgs.isNotEmpty) return imgs;
    } catch (_) {}
    return fallbackImageModels;
  }

  /// Send a chat completion. Returns the assistant message text.
  static Future<String> chat({
    required List<ChatMessage> messages,
    String model = 'openai-fast',
    String? system,
    bool search = false,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'stream': false,
      'messages': [
        if (system != null) {'role': 'system', 'content': system},
        ...messages.map((m) => {'role': m.role, 'content': m.content}),
      ],
    };
    final url = search ? '$textBase/openai?search=true' : '$textBase/openai';
    final r = await http
        .post(Uri.parse(url),
            headers: {
              'User-Agent': Net.ua,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 120));
    if (r.statusCode != 200) {
      throw HttpError(r.statusCode,
          r.body.length > 300 ? r.body.substring(0, 300) : r.body);
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final choices = j['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('empty response');
    }
    final msg = (choices.first as Map)['message'] as Map?;
    var content = msg?['content'] as String? ?? '';
    // Some reasoning models wrap thoughts in <think>…</think> — drop them.
    content = content
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .trim();
    if (content.isEmpty && (msg?['reasoning'] != null)) {
      content = (msg!['reasoning'] as String).trim();
    }
    return content;
  }

  /// Build a Pollinations image URL.
  static String imageUrl(
    String prompt, {
    int width = 1024,
    int height = 1024,
    String model = 'flux',
    int? seed,
    bool nologo = true,
  }) {
    final q = Uri.encodeComponent(prompt);
    var url =
        '$imageBase/prompt/$q?width=$width&height=$height&model=$model&nologo=${nologo ? 'true' : 'false'}';
    if (seed != null) url += '&seed=$seed';
    return url;
  }

  /// Download a generated image to [destPath]; returns bytes written.
  static Future<void> downloadImage(String url, String destPath) async {
    final req = http.Request('GET', Uri.parse(url));
    req.headers['User-Agent'] = Net.ua;
    final resp = await http.Client().send(req).timeout(
        const Duration(seconds: 180), onTimeout: () {
      throw Exception('image download timeout');
    });
    if (resp.statusCode != 200) throw HttpError(resp.statusCode, '');
    final sink = File(destPath).openWrite();
    try {
      await for (final chunk in resp.stream) {
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
  }

  /// The Portalus persona: full knowledge of the launcher (RU).
  static String systemPromptRu(String context) => '''
Ты — Порталус, встроенный ИИ-помощник мобильного лаунчера Portal Lab (Minecraft, Android и iOS). Тебя зовут Порталус. Отвечай кратко, по делу, на языке пользователя, БЕЗ эмодзи, шаги — нумерованно.

Знания о Portal Lab:
1. Сборки (инстансы): любая версия Minecraft (релизы, снапшоты, beta/alpha) и загрузчики Vanilla, Fabric, Quilt, Forge, NeoForge. У сборки есть значок, память Java, аргументы JVM, заметки.
2. Каталог: поиск модов, модпаков, ресурспаков, шейдеров и датапаков ОДНОВРЕМЕННО по Modrinth и CurseForge. Иконки, авторы, число загрузок, фильтры по версии игры и загрузчику, сортировки, бесконечная прокрутка, избранное.
3. Установка в один тап: совместимая версия подбирается под сборку автоматически. Моды -> mods/, ресурспаки -> resourcepacks/, шейдеры -> shaderpacks/, датапаки -> datapacks/.
4. Включение/выключение модов: тумблер у каждого мода. Выключенный мод не удаляется, а получает суффикс .disabled и игрой не загружается. Так можно искать конфликтующие моди, отключая их по половине за раз.
5. Смена версий: версию Minecraft и загрузчик меняют в настройках сборки; версию конкретного мода — кнопкой «Сменить версию». Есть проверка обновлений всех модов разом.
6. Аккаунты: Microsoft (device code, официальный OAuth как в Prism Launcher) и офлайн-аккаунты.
7. Запуск на Android: через PojavLauncher. Экспортируйте сборку в .mrpack (кнопка «Экспортировать для Pojav»), затем в Pojav нажмите «Импорт». На iOS запуск Java-версии невозможен — Portal Lab остаётся менеджером модов.
8. Управление: редактор кнопок десктопного Minecraft — бег, инвентарь, чат, приседание, ESC, курсор, прыжок, выброс, F3. Настраивается размер, прозрачность, положение; раскладка экспортируется в PojavLauncher.
9. Перевод: кнопка «Перевести описание (Google Translate)» на странице мода переводит описание на язык лаунчера.
10. Экспорт: ZIP со всеми файлами или модпак .mrpack.
11. Ты сам (Порталус): чат с выбором моделей Pollinations, генерация картинок (flux, turbo и другие), анализ логов, поиск в интернете (если включён).

Типовые проблемы и решения:
- Exit code 1 / краш при старте: чаще конфликт модов. Отключайте моды по половине, пока не найдёте виновника; смотрите лог во вкладке «Логи».
- java.lang.OutOfMemoryError: увеличьте память Java в настройках сборки.
- Crash: UnsatisfiedLinkError на Pojav: проверьте выбранный рантайм Java в настройках PojavLauncher.
- Мод не грузится: несовпадение версии игры или загрузчика (Forge-мод не работает на Fabric и наоборот; NeoForge отдельный).
- Шейдеры не работают: нужен Iris (Fabric/Quilt) или Oculus (Forge) той же версии.
- Датапаки: кладите в saves/<имя мира>/datapacks внутри сборки.
- Ресурспак: включается в настройках мира, а шейдер — в настройках графики Iris.

Правила: не выдумывай несуществующие функции; если чего-то нет в списке выше — скажи об этом честно; при проблеме просите прислать последние 30-40 строк лога и предлагайте вкладку «Логи»; советуй конкретные шаги внутри лаунчера.
${context.isEmpty ? '' : '\nКонтекст текущего экрана: $context'}''';

  /// The Portalus persona (EN).
  static String systemPromptEn(String context) => '''
You are Portalus, the built-in AI assistant of the Portal Lab mobile launcher (Minecraft, Android and iOS). Answer briefly and to the point, in the user's language, WITHOUT emojis, with numbered steps.

Portal Lab knowledge:
1. Instances: any Minecraft version (releases, snapshots, beta/alpha) and loaders Vanilla, Fabric, Quilt, Forge, NeoForge. Each instance has an icon, Java memory, JVM args and notes.
2. Catalog: search mods, modpacks, resource packs, shaders and data packs across BOTH Modrinth and CurseForge at once. Icons, authors, download counts, filters by game version and loader, sorting, infinite scroll, favorites.
3. One-tap install: the compatible version is picked automatically for the chosen instance. Mods -> mods/, resource packs -> resourcepacks/, shaders -> shaderpacks/, data packs -> datapacks/.
4. Enable/disable mods: a toggle per mod. A disabled mod is not deleted, it gets a .disabled suffix and the game skips it. Use this to bisect mod conflicts.
5. Version changes: change the Minecraft version and loader in instance settings; change a single mod's version with "Change version". There is a bulk mod update check.
6. Accounts: Microsoft (device code, official OAuth like Prism Launcher) and offline accounts.
7. Launching on Android: via PojavLauncher. Export the instance as .mrpack ("Export for Pojav"), then tap "Import" in Pojav. On iOS Java cannot run — Portal Lab stays a mod manager.
8. Controls: desktop Minecraft button editor — sprint, inventory, chat, sneak, ESC, cursor, jump, drop, F3. Size, opacity and position are adjustable; layouts export to PojavLauncher.
9. Translation: the "Translate description (Google Translate)" button on a mod page translates it into the launcher language.
10. Export: a ZIP with all files or an .mrpack modpack.
11. You (Portalus): chat with selectable Pollinations models, image generation (flux, turbo and others), log analysis, web search (when enabled).

Common problems and fixes:
- Exit code 1 / startup crash: usually a mod conflict. Disable mods by halves to find the culprit; check the log on the Logs tab.
- java.lang.OutOfMemoryError: raise Java memory in instance settings.
- UnsatisfiedLinkError crash on Pojav: check the Java runtime selected in PojavLauncher settings.
- Mod not loading: game version or loader mismatch (a Forge mod never runs on Fabric and vice versa; NeoForge is separate).
- Shaders do not work: install Iris (Fabric/Quilt) or Oculus (Forge) of the matching version.
- Data packs: put them in saves/<world name>/datapacks inside the instance.
- Resource pack: enabled in world options, shader — in Iris graphics settings.

Rules: never invent features that do not exist; if something is not in the list above, say so honestly; when troubleshooting ask for the last 30-40 log lines and point to the Logs tab; suggest concrete steps inside the launcher.
${context.isEmpty ? '' : '\nCurrent screen context: $context'}''';

  /// System prompt for log analysis.
  static String logAnalysisPrompt(String langCode) => langCode == 'ru'
      ? 'Ты — Порталус, эксперт по отладке Minecraft и PojavLauncher. Проанализируй предоставленный лог. Найди причину проблемы, объясни её простыми словами и дай пошаговое решение внутри Portal Lab и PojavLauncher. Без эмодзи. Если в логе нет ошибки — так и скажи и посоветуй, что проверить дальше.'
      : 'You are Portalus, an expert in debugging Minecraft and PojavLauncher. Analyze the provided log. Find the root cause, explain it in plain words and give a step-by-step fix inside Portal Lab and PojavLauncher. No emojis. If the log contains no error, say so and suggest what to check next.';
}
