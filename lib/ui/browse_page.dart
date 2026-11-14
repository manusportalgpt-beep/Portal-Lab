import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../models.dart';
import '../services/curseforge.dart';
import '../services/modrinth.dart';
import '../theme.dart';
import 'project_page.dart';
import 'widgets/brand_icons.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  String _source = 'all'; // all | modrinth | curseforge
  String _projectType = 'mod';
  String _query = '';
  String _gameVersion = '';
  String _loader = '';
  String _sort = 'relevance';
  bool _favorites = false;
  final _scroll = ScrollController();
  final List<CatalogProject> _results = [];
  bool _loading = false;
  bool _loadingMore = false;
  int _offset = 0;
  bool _hasMore = true;
  String? _error;

  static const _types = [
    ('mod', 'tabBrowse'),
    ('modpack', 'typeModpack'),
    ('resourcepack', 'typeResourcepack'),
    ('shader', 'typeShader'),
    ('datapack', 'typeDatapack'),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
              _scroll.position.maxScrollExtent - 400 &&
          !_loadingMore &&
          _hasMore &&
          !_favorites) {
        _loadMore();
      }
    });
    _search();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reset() {
    _results.clear();
    _offset = 0;
    _hasMore = true;
    _error = null;
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _reset();
    });
    await _fetch();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await _fetch();
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<List<CatalogProject>> _fetchOne(String source, int offset) async {
    if (source == 'modrinth') {
      return ModrinthService.search(
        query: _query,
        projectType: _projectType,
        gameVersions: _gameVersion.isEmpty ? const [] : [_gameVersion],
        loaders: _loader.isEmpty ? const [] : [_loader],
        sort: _sort,
        offset: offset,
        limit: 20,
      );
    }
    return CurseForgeService.search(
      query: _query,
      projectType: _projectType,
      gameVersion: _gameVersion,
      loader: _loader,
      sort: _sort == 'downloads'
          ? 'Popularity'
          : _sort == 'updated'
              ? 'Last Updated'
              : 'Featured',
      offset: offset,
    );
  }

  Future<void> _fetch() async {
    if (_favorites) return;
    try {
      List<CatalogProject> page;
      if (_source == 'all') {
        // Query both platforms at once and interleave.
        final results = await Future.wait([
          _fetchOne('modrinth', _offset).catchError((_) => <CatalogProject>[]),
          _fetchOne('curseforge', _offset).catchError((_) => <CatalogProject>[]),
        ]);
        page = <CatalogProject>[];
        final a = results[0], b = results[1];
        for (var i = 0; i < a.length || i < b.length; i++) {
          if (i < a.length) page.add(a[i]);
          if (i < b.length) page.add(b[i]);
        }
        if (a.isEmpty && b.isEmpty && _offset == 0) {
          throw Exception('no results from Modrinth and CurseForge');
        }
        if (a.length + b.length < 20) _hasMore = false;
      } else {
        page = await _fetchOne(_source, _offset);
        if (page.length < 20) _hasMore = false;
      }
      if (!mounted) return;
      setState(() {
        _results.addAll(page);
        _offset += 20;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(s['tabBrowse'],
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SearchBar(
              hintText: s['search'],
              leading: const Icon(Icons.search),
              onChanged: (v) {
                _query = v;
              },
              onSubmitted: (_) {
                _favorites = false;
                _search();
              },
            ),
          ),
          // Platform toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _SourceChip(
                  label: s['sourceAll'],
                  icon: null,
                  selected: _source == 'all' && !_favorites,
                  onTap: () {
                    setState(() {
                      _source = 'all';
                      _favorites = false;
                    });
                    _search();
                  },
                ),
                const SizedBox(width: 8),
                _SourceChip(
                  label: 'Modrinth',
                  icon: const SourceBadge(source: 'modrinth', size: 18),
                  selected: _source == 'modrinth' && !_favorites,
                  onTap: () {
                    setState(() {
                      _source = 'modrinth';
                      _favorites = false;
                    });
                    _search();
                  },
                ),
                const SizedBox(width: 8),
                _SourceChip(
                  label: 'CurseForge',
                  icon: const SourceBadge(source: 'curseforge', size: 18),
                  selected: _source == 'curseforge' && !_favorites,
                  onTap: () {
                    setState(() {
                      _source = 'curseforge';
                      _favorites = false;
                    });
                    _search();
                  },
                ),
              ],
            ),
          ),
          // Type chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                ..._types
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s[t.$2]),
                            selected: _projectType == t.$1 && !_favorites,
                            onSelected: (_) {
                              setState(() {
                                _projectType = t.$1;
                                _favorites = false;
                              });
                              _search();
                            },
                          ),
                        ))
                    .toList(),
                ChoiceChip(
                  avatar: const Icon(Icons.favorite_outline, size: 18),
                  label: Text(s['favoritesLabel']),
                  selected: _favorites,
                  onSelected: (_) {
                    setState(() => _favorites = true);
                  },
                ),
              ],
            ),
          ),
          // Filters
          if (!_favorites)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _FilterMenu(
                    icon: Icons.filter_alt_outlined,
                    label: _gameVersion.isEmpty
                        ? s['filterVersion']
                        : _gameVersion,
                    items: const [
                      ('', ''),
                      ('1.21.4', '1.21.4'),
                      ('1.21.1', '1.21.1'),
                      ('1.20.1', '1.20.1'),
                      ('1.19.2', '1.19.2'),
                      ('1.18.2', '1.18.2'),
                      ('1.16.5', '1.16.5'),
                      ('1.12.2', '1.12.2'),
                      ('1.8.9', '1.8.9'),
                    ],
                    onPick: (v) {
                      setState(() => _gameVersion = v);
                      _search();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterMenu(
                    icon: Icons.handyman_outlined,
                    label: _loader.isEmpty ? s['filterLoader'] : _loader,
                    items: const [
                      ('', ''),
                      ('fabric', 'Fabric'),
                      ('forge', 'Forge'),
                      ('neoforge', 'NeoForge'),
                      ('quilt', 'Quilt'),
                    ],
                    onPick: (v) {
                      setState(() => _loader = v);
                      _search();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterMenu(
                    icon: Icons.sort,
                    label: s['sortBy'],
                    items: [
                      ('relevance', s['sortRelevance']),
                      ('downloads', s['sortDownloads']),
                      ('follows', s['sortFollows']),
                      ('newest', s['sortNewest']),
                      ('updated', s['sortUpdated']),
                    ],
                    onPick: (v) {
                      setState(() => _sort = v);
                      _search();
                    },
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          // Results
          Expanded(
            child: _favorites
                ? _buildFavorites(context, st, s)
                : _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 10),
                            Text(
                              _source == 'all'
                                  ? s['searchingBoth']
                                  : s['loading'],
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : _error != null
                        ? ListView(children: [
                            const SizedBox(height: 80),
                            const Icon(Icons.cloud_off, size: 64),
                            const SizedBox(height: 8),
                            Text('${s['error']}: $_error',
                                textAlign: TextAlign.center),
                            TextButton(
                                onPressed: _search,
                                child: Text(s['retry'])),
                          ])
                        : _results.isEmpty
                            ? ListView(children: [
                                const SizedBox(height: 80),
                                const Icon(Icons.search_off, size: 64),
                                const SizedBox(height: 8),
                                Text(s['noResults'],
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge),
                                Text(s['tryOther'],
                                    textAlign: TextAlign.center),
                              ])
                            : ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(
                                    12, 0, 12, 20),
                                itemCount: _results.length + 1,
                                itemBuilder: (context, i) {
                                  if (i == _results.length) {
                                    return _loadingMore
                                        ? const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Center(
                                                child:
                                                    CircularProgressIndicator()),
                                          )
                                        : const SizedBox(height: 40);
                                  }
                                  final p = _results[i];
                                  return _ProjectTile(project: p);
                                },
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavorites(BuildContext context, AppState st, S s) {
    if (st.favorites.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.favorite_border, size: 64),
          const SizedBox(height: 8),
          Text(s['favoritesEmpty'],
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      itemCount: st.favorites.length,
      itemBuilder: (context, i) =>
          _ProjectTile(project: st.favorites[i].toCatalog()),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool selected;
  final VoidCallback onTap;
  const _SourceChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: icon,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

class _FilterMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<(String, String)> items;
  final void Function(String) onPick;
  const _FilterMenu({
    required this.icon,
    required this.label,
    required this.items,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onPick,
      itemBuilder: (ctx) => items
          .map((it) => PopupMenuItem(
                value: it.$1,
                child: Text(it.$2.isEmpty
                    ? AppScope.of(context).s['any']
                    : it.$2),
              ))
          .toList(),
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final CatalogProject project;
  const _ProjectTile({required this.project});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    final cs = Theme.of(context).colorScheme;
    final fav = st.isFavorite(project.source, project.id);
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: project.iconUrl == null
                  ? Container(
                      width: 48,
                      height: 48,
                      color: cs.primaryContainer,
                      child: Icon(Icons.extension,
                          color: cs.onPrimaryContainer),
                    )
                  : CachedNetworkImage(
                      imageUrl: project.iconUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 48,
                        height: 48,
                        color: cs.surfaceContainerHighest,
                      ),
                    ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: SourceBadge(
                source: project.source,
                size: 17,
              ),
            ),
          ],
        ),
        title: Text(project.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s['byAuthor']} ${project.author} • ${fmtCount(project.downloads)} ${s['downloadsWord']}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(project.description,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: fav
            ? const Icon(Icons.favorite, size: 20)
            : null,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProjectPage(project: project))),
      ),
    );
  }
}
