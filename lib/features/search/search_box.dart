import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/app/theme/layer_palette.dart';
import 'package:codegraph/core/utils/formatters.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/search/search_hit.dart';
import 'package:codegraph/features/search/search_graph.dart';

class SearchBox extends StatefulWidget {
  const SearchBox({super.key, this.width = 340});

  final double width;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  List<SearchHit> _hits = const [];
  bool _suppressChange = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted && !_focusNode.hasFocus) {
          _portal.hide();
        }
      });
    } else if (_controller.text.trim().isNotEmpty) {
      _refresh(_controller.text);
    }
  }

  void _refresh(String query) {
    final graph = context.read<GraphController>();
    if (graph.graph == null || graph.analysis == null) {
      setState(() => _hits = const []);
      _portal.hide();
      return;
    }

    final hits = context.read<SearchGraph>()(
      graph: graph.graph!,
      analysis: graph.analysis!,
      query: query,
    );
    setState(() => _hits = hits);

    if (query.trim().isEmpty || !_focusNode.hasFocus) {
      _portal.hide();
    } else {
      _portal.show();
    }
  }

  void _onChanged(String value) {
    if (_suppressChange) return;
    _refresh(value);
  }

  void _select(SearchHit hit) {
    _suppressChange = true;
    _controller.text = hit.file.name;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _suppressChange = false;
    context.read<GraphController>().selectNode(hit.file.id);
    _portal.hide();
    _focusNode.unfocus();
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    setState(() => _hits = const []);
    _portal.hide();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return SizedBox(
      width: widget.width,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(0, 9),
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          child: Material(
            type: MaterialType.transparency,
            child: _SearchResults(
              hits: _hits,
              query: _controller.text,
              onSelected: _select,
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: _link,
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              onTap: () {
                if (_controller.text.trim().isNotEmpty) {
                  _refresh(_controller.text);
                }
              },
              onSubmitted: (_) {
                if (_hits.isNotEmpty) _select(_hits.first);
              },
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Найти файл, слой или проблему…',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                suffixIcon: hasText
                    ? IconButton(
                        onPressed: _clear,
                        icon: const Icon(Icons.close_rounded, size: 15),
                        tooltip: 'Очистить',
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.hits,
    required this.query,
    required this.onSelected,
  });

  final List<SearchHit> hits;
  final String query;
  final ValueChanged<SearchHit> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trimmed = query.trim();

    return Container(
      width: 440,
      constraints: const BoxConstraints(maxHeight: 430),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text(
                  hits.isEmpty ? 'Совпадений нет' : 'Найдено: ${hits.length}',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                const Text(
                  'локальный поиск',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (hits.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 30,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    trimmed.isEmpty
                        ? 'Введите имя файла или запрос'
                        : 'По запросу «$trimmed» ничего не найдено',
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Попробуйте «domain», «repository», «cycle» или часть пути.',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: hits.length,
                itemBuilder: (context, index) {
                  final hit = hits[index];
                  return _ResultTile(hit: hit, onTap: () => onSelected(hit));
                },
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  'по имени, пути, слою и аномалии',
                  style: textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ResultHover(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: hit.file.layer.softColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hit.file.layer.icon,
              size: 15,
              color: hit.file.layer.color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.shortPath(hit.file.relativePath, maxSegments: 3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              hit.reason,
              style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            size: 15,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _ResultHover extends StatefulWidget {
  const _ResultHover({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_ResultHover> createState() => _ResultHoverState();
}

class _ResultHoverState extends State<_ResultHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _hovered
              ? AppColors.primary.withValues(alpha: 0.07)
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}
