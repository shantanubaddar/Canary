part of '../main.dart';

class CanarySidebar extends StatelessWidget {
  const CanarySidebar({
    required this.library,
    required this.route,
    required this.onRouteSelected,
    super.key,
  });

  final LibraryController library;
  final DashboardRoute route;
  final ValueChanged<DashboardRoute> onRouteSelected;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      width: 288,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/canary_logo.png',
                width: 52,
                height: 52,
              ),
              const SizedBox(width: 10),
              const Text(
                'Canary',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: CanaryTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SearchBox(
            initialQuery: route.kind == DashboardViewKind.search
                ? route.query
                : '',
            onSearch: (query) {
              final trimmed = query.trim();
              if (trimmed.isEmpty) {
                onRouteSelected(const DashboardRoute.home());
              } else {
                onRouteSelected(DashboardRoute.search(trimmed));
              }
            },
          ),
          const SizedBox(height: 24),
          NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: route.kind == DashboardViewKind.home,
            onTap: () => onRouteSelected(const DashboardRoute.home()),
          ),
          NavItem(
            icon: Icons.library_music_rounded,
            label: 'Library',
            selected: route.kind == DashboardViewKind.library,
            onTap: () => onRouteSelected(const DashboardRoute.library()),
          ),
          NavItem(
            icon: Icons.album_rounded,
            label: 'Albums',
            selected:
                route.kind == DashboardViewKind.albums ||
                route.kind == DashboardViewKind.album,
            onTap: () => onRouteSelected(const DashboardRoute.albums()),
          ),
          NavItem(
            icon: Icons.person_rounded,
            label: 'Artists',
            selected: route.kind == DashboardViewKind.artists,
            onTap: () => onRouteSelected(const DashboardRoute.artists()),
          ),
          const Spacer(),
          MetadataCacheCard(policyLabel: library.coverPolicy.label),
        ],
      ),
    );
  }
}

class SearchBox extends StatefulWidget {
  const SearchBox({
    required this.initialQuery,
    required this.onSearch,
    super.key,
  });

  final String initialQuery;
  final ValueChanged<String> onSearch;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final TextEditingController controller;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(SearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != controller.text) {
      controller.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void queueSearch(String value) {
    setState(() {});
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 260), () {
      widget.onSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CanaryTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: CanaryTheme.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Search',
                hintStyle: TextStyle(color: CanaryTheme.muted),
              ),
              style: const TextStyle(color: CanaryTheme.text),
              textInputAction: TextInputAction.search,
              onChanged: queueSearch,
              onSubmitted: widget.onSearch,
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              onPressed: () {
                controller.clear();
                widget.onSearch('');
                setState(() {});
              },
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: CanaryTheme.muted,
              ),
            ),
        ],
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  const NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? CanaryTheme.honey.withValues(alpha: .58)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? CanaryTheme.amber : CanaryTheme.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? CanaryTheme.text : CanaryTheme.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
