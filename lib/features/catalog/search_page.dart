import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/app_store.dart';
import '../../models/models.dart';
import '../../ui/common.dart';
import 'video_list.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.store});
  final AppStore store;
  @override
  State<SearchPage> createState() => _SearchPageState();
}
class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  Timer? debounce;
  String query = '', sort = 'new';
  int? category;
  List<Category> categories = [];
  @override
  void initState() { super.initState(); loadCategories(); }
  Future<void> loadCategories() async {
    try { final rows = await widget.store.api.categories(); if (mounted) setState(() => categories = rows); }
    catch (e) { if (mounted) notice(context, '$e'); }
  }
  void search(String value, {bool immediate = false}) {
    debounce?.cancel();
    void apply() { if (!mounted) return; setState(() => query = value.trim()); if (query.isNotEmpty) widget.store.rememberSearch(query); }
    if (immediate || value.isEmpty) apply(); else debounce = Timer(const Duration(milliseconds: 350), apply);
  }
  @override
  void dispose() { debounce?.cancel(); controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('搜索动画')),
    body: SafeArea(top: false, child: Column(children: [Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: MiuixTextField(controller: controller, label: '名称、简介都可以搜', singleLine: true, autofocus: true,
        leadingIcon: const Icon(Icons.search_rounded), textInputAction: TextInputAction.search,
        trailingIcon: IconButton(tooltip: '清空', onPressed: () { controller.clear(); search(''); }, icon: const Icon(Icons.close_rounded)),
        onChanged: search, onSubmitted: (s) { search(s, immediate: true); FocusScope.of(context).unfocus(); })),
      SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18), children: [
        Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('全部分类'), selected: category == null, onSelected: (_) => setState(() => category = null))),
        ...categories.map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(c.name), selected: category == c.id, onSelected: (_) => setState(() => category = c.id)))),
      ])),
      if (query.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8), child: Row(children: [
        Expanded(child: Text('“$query” 的搜索结果', maxLines: 1, overflow: TextOverflow.ellipsis)),
        PopupMenuButton<String>(tooltip: '排序', initialValue: sort, onSelected: (v) => setState(() => sort = v),
          itemBuilder: (_) => const [PopupMenuItem(value: 'new', child: Text('最新上架')), PopupMenuItem(value: 'popular', child: Text('最多观看'))],
          child: Padding(padding: const EdgeInsets.all(10), child: Text(sort == 'new' ? '最新 ▾' : '最热 ▾'))),
      ])),
      Expanded(child: query.isEmpty ? AnimatedBuilder(animation: widget.store, builder: (_,__) => ListView(padding: const EdgeInsets.all(18), children: [
        SectionTitle('最近搜索', action: IconButton(tooltip: '清空搜索历史', onPressed: () async {
          if (await confirm(context, '清空搜索历史', '只清除本机记录，不影响账户数据。')) await widget.store.clearSearchHistory();
        }, icon: const Icon(Icons.delete_outline))),
        if (widget.store.searchHistory.isEmpty) const StatePanel(title: '从一个关键词开始', message: '输入动画名称或简介关键词。搜索记录只保存在这台设备。', icon: Icons.travel_explore),
        Wrap(spacing: 8, runSpacing: 8, children: widget.store.searchHistory.map((s) => ActionChip(label: Text(s), onPressed: () { controller.text = s; search(s, immediate: true); FocusScope.of(context).unfocus(); })).toList()),
        const SizedBox(height: 28), const Text('搜索提示', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8), const Text('试试标题中的两个字，或简介里出现的主题。选择分类可以缩小结果范围。'),
      ])) : VideoList(store: widget.store, query: query, category: category, sort: sort)),
    ])));
}
