import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../models.dart';
import '../services/pollinations.dart';
import '../store.dart';
import 'widgets/brand_icons.dart';

/// Portalus — the built-in AI assistant: chat, image studio and log analysis.
class PortalusPage extends StatefulWidget {
  final String? initialPrompt;
  final String? contextInfo;
  const PortalusPage({super.key, this.initialPrompt, this.contextInfo});

  @override
  State<PortalusPage> createState() => _PortalusPageState();
}

class _PortalusPageState extends State<PortalusPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _input = TextEditingController();
  final _imagePrompt = TextEditingController();
  final _logCtrl = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMessage> _messages = [];
  List<PollinationsModel> _textModels = [];
  List<PollinationsModel> _imageModels = [];
  List<AiImageItem> _images = [];
  bool _thinking = false;
  bool _generating = false;
  String _imageModel = 'flux';
  (int, int) _imageSize = (1024, 1024);
  AiImageItem? _selectedImage;
  String? _logAnswer;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadChat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadModels();
      _loadImages();
      if (widget.initialPrompt != null &&
          widget.initialPrompt!.isNotEmpty) {
        _send(widget.initialPrompt!);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _input.dispose();
    _imagePrompt.dispose();
    _logCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadChat() async {
    final msgs = await Store.loadChat();
    if (!mounted) return;
    setState(() => _messages = msgs);
  }

  Future<void> _loadModels() async {
    final st = AppScope.of(context);
    final text = await PollinationsService.models();
    final imgs = await PollinationsService.imageModels();
    if (!mounted) return;
    setState(() {
      _textModels = text;
      _imageModels = imgs;
      if (!text.any((m) => m.name == st.aiModel)) {
        st.setAiModel(text.first.name);
      }
      if (!imgs.any((m) => m.name == _imageModel) && imgs.isNotEmpty) {
        _imageModel = imgs.first.name;
      }
    });
  }

  Future<void> _loadImages() async {
    final imgs = await Store.loadImages();
    if (!mounted) return;
    setState(() {
      _images = imgs;
      _selectedImage = imgs.isEmpty ? null : imgs.first;
    });
  }

  Future<void> _saveChat() => Store.saveChat(_messages);
  Future<void> _saveImages() => Store.saveImages(_images);

  void _send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _thinking) return;
    final st = AppScope.of(context);
    _input.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: prompt));
      _thinking = true;
    });
    _scrollToEnd();
    await _saveChat();
    try {
      final history = _messages.length > 14
          ? _messages.sublist(_messages.length - 14)
          : _messages;
      final answer = await PollinationsService.chat(
        messages: history,
        model: st.aiModel,
        search: st.aiWebSearch,
        system: st.lang == 'ru'
            ? PollinationsService.systemPromptRu(widget.contextInfo ?? '')
            : PollinationsService.systemPromptEn(widget.contextInfo ?? ''),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: answer));
        _thinking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
            role: 'assistant', content: '${st.s['aiError']}\n$e'));
        _thinking = false;
      });
    }
    await _saveChat();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearChat() async {
    final s = AppScope.of(context).s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s['clearChat']),
        content: Text(s['clearChatQ']),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s['cancel'])),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s['delete'])),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _messages = []);
    await _saveChat();
  }

  Future<void> _pickModel() async {
    final st = AppScope.of(context);
    final s = st.s;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(s['modelLabel'],
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (_textModels.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._textModels.map((m) {
                final selected = m.name == st.aiModel;
                return ListTile(
                  leading: PortalusAvatar(
                      size: 34, thinking: m.name == st.aiModel),
                  title: Text(m.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    m.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () {
                    st.setAiModel(m.name);
                    Navigator.pop(ctx);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _generateImage() async {
    final prompt = _imagePrompt.text.trim();
    if (prompt.isEmpty || _generating) return;
    final s = AppScope.of(context).s;
    setState(() => _generating = true);
    final url = PollinationsService.imageUrl(
      prompt,
      width: _imageSize.$1,
      height: _imageSize.$2,
      model: _imageModel,
      seed: DateTime.now().millisecondsSinceEpoch % 100000,
    );
    final item = AiImageItem(
      prompt: prompt,
      url: url,
      model: _imageModel,
      width: _imageSize.$1,
      height: _imageSize.$2,
    );
    setState(() {
      _images.insert(0, item);
      _selectedImage = item;
    });
    try {
      final name =
          'portalus_${DateTime.now().millisecondsSinceEpoch}_${_sanitize(prompt)}.jpg';
      final path = '${Store.imagesDir.path}/$name';
      await PollinationsService.downloadImage(url, path);
      item.localPath = path;
      await _saveImages();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _images.remove(item);
        if (_selectedImage == item) {
          _selectedImage = _images.isEmpty ? null : _images.first;
        }
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s['error']}: $e')));
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _saveImage(AiImageItem item) async {
    final s = AppScope.of(context).s;
    final name =
        'portalus_${DateTime.now().millisecondsSinceEpoch}_${_sanitize(item.prompt)}.jpg';
    final path = '${Store.imagesDir.path}/$name';
    try {
      await PollinationsService.downloadImage(item.url, path);
      item.localPath = path;
      await _saveImages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s['imgSavedTo']}: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s['error']}: $e')));
    }
  }

  Future<void> _deleteImage(AiImageItem item) async {
    setState(() {
      _images.remove(item);
      if (_selectedImage == item) {
        _selectedImage = _images.isEmpty ? null : _images.first;
      }
    });
    if (item.localPath != null) {
      final f = File(item.localPath!);
      if (await f.exists()) await f.delete();
    }
    await _saveImages();
  }

  Future<void> _analyzeLog() async {
    final log = _logCtrl.text.trim();
    if (log.isEmpty || _analyzing) return;
    final st = AppScope.of(context);
    final s = st.s;
    setState(() => _analyzing = true);
    try {
      final truncated =
          log.length > 6000 ? log.substring(log.length - 6000) : log;
      final answer = await PollinationsService.chat(
        messages: [
          ChatMessage(role: 'user', content: truncated),
        ],
        model: st.aiModel,
        system: PollinationsService.logAnalysisPrompt(st.lang),
      );
      if (!mounted) return;
      setState(() => _logAnswer = answer);
      _messages.add(ChatMessage(role: 'user', content: s['logsTab']));
      _messages.add(ChatMessage(role: 'assistant', content: answer));
      await _saveChat();
    } catch (e) {
      if (!mounted) return;
      setState(() => _logAnswer = '${s['aiError']}\n$e');
    }
    if (mounted) setState(() => _analyzing = false);
  }

  Future<void> _pasteClipboard() async {
    final s = AppScope.of(context).s;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s['clipboardEmpty'])));
      return;
    }
    _logCtrl.text = text;
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 14),
            const PortalusAvatar(size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['portalusName'],
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 17)),
                  Text(s['portalusTagline'],
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s['webSearchLabel'],
            onPressed: () => st.setAiWebSearch(!st.aiWebSearch),
            icon: Icon(
              st.aiWebSearch ? Icons.travel_explore : Icons.travel_explore_outlined,
              color: st.aiWebSearch
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          IconButton(
            tooltip: s['clearChat'],
            onPressed: _clearChat,
            icon: const Icon(Icons.clear_all),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: s['chatTab']),
            Tab(text: s['imagesTab']),
            Tab(text: s['logsTab']),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildChat(context, st, s),
          _buildImages(context, st, s),
          _buildLogs(context, st, s),
        ],
      ),
    );
  }

  // ---- Chat tab ----

  Widget _buildChat(BuildContext context, AppState st, S s) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Model selector row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickModel,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PortalusAvatar(size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${s['modelLabel']}: ${st.aiModel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (st.aiWebSearch)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s['webSearchOn'],
              style: TextStyle(
                  fontSize: 11, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        // Messages
        Expanded(
          child: _messages.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    const SizedBox(height: 30),
                    const Center(child: PortalusAvatar(size: 84, thinking: true)),
                    const SizedBox(height: 14),
                    Text(
                      s['portalusName'],
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s['portalusIntro'],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: _messages.length + (_thinking ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _messages.length) {
                      return _ThinkingBubble(label: s['thinking']);
                    }
                    final m = _messages[i];
                    return _MessageBubble(message: m);
                  },
                ),
        ),
        // Quick questions
        if (_messages.isEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _QuickChip(label: s['qqInstallMod'], onTap: () => _send(s['qqInstallMod'])),
                _QuickChip(label: s['qqInstallPack'], onTap: () => _send(s['qqInstallPack'])),
                _QuickChip(label: s['qqToggleMod'], onTap: () => _send(s['qqToggleMod'])),
                _QuickChip(label: s['qqChangeVersion'], onTap: () => _send(s['qqChangeVersion'])),
                _QuickChip(label: s['qqNotLaunching'], onTap: () => _send(s['qqNotLaunching'])),
                _QuickChip(label: s['qqBestMods'], onTap: () => _send(s['qqBestMods'])),
              ],
            ),
          ),
        // Input bar
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: s['inputHint'],
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _thinking
                      ? cs.surfaceContainerHighest
                      : cs.primary,
                  child: IconButton(
                    onPressed: _thinking ? null : () => _send(_input.text),
                    icon: Icon(Icons.send,
                        color: _thinking ? cs.outline : cs.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- Images tab ----

  Widget _buildImages(BuildContext context, AppState st, S s) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: _imagePrompt,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: s['imgPromptHint'],
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ImageSizeSegment(
                onChanged: (v) => setState(() => _imageSize = v),
                value: _imageSize,
                labels: (s['imgSquare'], s['imgWide'], s['imgTall']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _generating ? null : _generateImage,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                    _generating ? s['imgGenerating'] : s['imgGenerate']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Image model chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _imageModels
                .map((m) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(m.name),
                        selected: _imageModel == m.name,
                        onSelected: (_) =>
                            setState(() => _imageModel = m.name),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (_selectedImage != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _generating && _selectedImage == _images.first
                    ? Container(
                        height: 260,
                        color: cs.surfaceContainerHighest.withOpacity(0.4),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PortalusAvatar(size: 46, thinking: true),
                              const SizedBox(height: 12),
                              Text(s['imgGenerating']),
                            ],
                          ),
                        ),
                      )
                    : _selectedImage!.localPath != null
                        ? Image.file(
                            File(_selectedImage!.localPath!),
                            fit: BoxFit.contain,
                          )
                        : CachedNetworkImage(
                            imageUrl: _selectedImage!.url,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Container(
                              height: 260,
                              color: cs.surfaceContainerHighest
                                  .withOpacity(0.4),
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 200,
                              color: cs.surfaceContainerHighest
                                  .withOpacity(0.4),
                              child: const Icon(Icons.broken_image, size: 48),
                            ),
                          ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedImage!.prompt,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _saveImage(_selectedImage!),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(s['imgSave']),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _deleteImage(_selectedImage!),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(s['imgDelete']),
                  ),
                  const Spacer(),
                  Text('${_selectedImage!.width}x${_selectedImage!.height}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        const SizedBox(height: 16),
        Text(s['imgHistory'],
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_images.isEmpty)
          Text(s['imgHistoryEmpty'],
              style: Theme.of(context).textTheme.bodySmall)
        else
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final img = _images[i];
                final selected = _selectedImage == img;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImage = img),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? cs.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: img.localPath != null
                          ? Image.file(File(img.localPath!),
                              width: 90, height: 90, fit: BoxFit.cover)
                          : CachedNetworkImage(
                              imageUrl: img.url,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 90,
                                height: 90,
                                color: cs.surfaceContainerHighest
                                    .withOpacity(0.4),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 90,
                                height: 90,
                                color: cs.surfaceContainerHighest
                                    .withOpacity(0.4),
                                child: const Icon(Icons.image_outlined),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ---- Logs tab ----

  Widget _buildLogs(BuildContext context, AppState st, S s) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          s['logsTab'],
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          s['logPasteHint'],
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _logCtrl,
          minLines: 6,
          maxLines: 12,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pasteClipboard,
              icon: const Icon(Icons.content_paste),
              label: Text(s['pasteFromClipboard']),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _analyzing ? null : _analyzeLog,
                icon: _analyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const PortalusAvatar(size: 20),
                label: Text(_analyzing ? s['thinking'] : s['analyzeLog']),
              ),
            ),
          ],
        ),
        if (_logAnswer != null) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const PortalusAvatar(size: 28),
                      const SizedBox(width: 8),
                      Text(s['portalusName'],
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_logAnswer!),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser
              ? cs.primary.withOpacity(0.14)
              : cs.surfaceContainerHighest.withOpacity(0.6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: SelectableText(
          message.content,
          style: const TextStyle(fontSize: 14.5, height: 1.35),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  final String label;
  const _ThinkingBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PortalusAvatar(size: 22, thinking: true),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 4),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,
      ),
    );
  }
}

class _ImageSizeSegment extends StatelessWidget {
  final (int, int) value;
  final void Function((int, int)) onChanged;
  final (String, String, String) labels;
  const _ImageSizeSegment(
      {required this.value, required this.onChanged, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [
        ButtonSegment(value: 0, label: Text(labels.$1)),
        ButtonSegment(value: 1, label: Text(labels.$2)),
        ButtonSegment(value: 2, label: Text(labels.$3)),
      ],
      selected: {
        value == (1024, 1024)
            ? 0
            : value == (1280, 720)
                ? 1
                : 2
      },
      onSelectionChanged: (sel) => onChanged(switch (sel.first) {
        0 => (1024, 1024),
        1 => (1280, 720),
        _ => (768, 1344),
      }),
    );
  }
}

String _sanitize(String s) {
  final t = s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return t.length > 24 ? t.substring(0, 24) : t;
}
