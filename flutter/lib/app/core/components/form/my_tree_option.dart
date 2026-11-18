import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/app/core/components/flutter_tree-2.0.3/flutter_tree.dart';
import '../../base/enums.dart';
import '../pages/index.dart';


class MyTreeOption extends StatefulWidget {

  final String pageTitle;
  final List<dynamic> options;
  final LoadDataStatus status;
  final List<dynamic>? values;
  final Function onSelect;

  const MyTreeOption({
    super.key,
    required this.pageTitle,
    this.status = LoadDataStatus.initial,
    this.options = const [],
    this.values = const [],
    required this.onSelect,
  });

  @override
  State<MyTreeOption> createState() => _MyTreeOptionState();

}

class _MyTreeOptionState extends State<MyTreeOption> {

  late List<Map<String, dynamic>> newValues;

  @override
  void initState() {
    super.initState();
    newValues = [...(widget.values ?? [])];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onSelect.call(newValues);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(widget.pageTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Get.back();
              },
            ),
          ],
        ),
        body:  () {
          switch (widget.status) {
            case LoadDataStatus.progress:
            case LoadDataStatus.initial:
              return const LoadingPage();
            case LoadDataStatus.success:
              TreeNodeData mapServerDataToTreeData(Map data) {
                return TreeNodeData(
                  extra: data,
                  title: data['label'],
                  expaned: false,
                  checked: newValues.map((e) => e['value']).contains(data['value']),
                  children: List.from(data['children']?.map((x) => mapServerDataToTreeData(x)) ?? []),
                );
              }

              List<TreeNodeData> treeData = List.generate(
                widget.options.length,
                    (index) => mapServerDataToTreeData(widget.options[index]),
              );

              return TreeView(
                data: treeData,
                showFilter: false,
                showCheckBox: true,
                onCheck: (checked, data) {
                  setState(() {
                    if (checked) {
                      _checkWithChildren(data.extra);
                    } else {
                      _uncheckWithChildren(data.extra);
                    }
                  });
                },
              );

            case LoadDataStatus.empty:
              return const EmptyPage();
            case LoadDataStatus.failure:
              return const ErrorPage();
          }
        }(),
      ),
    );
  }

  /// 勾选父级时把子孙一起选上。后端 categoryIds 是等值匹配（MoneyFlowQueryForm 注释里
  /// 约定「前端已把选中的父分类展开为叶子 id 后传值」），只传父级 id 会漏掉挂在子分类下的流水。
  void _checkWithChildren(Map<String, dynamic> node) {
    final dynamic value = node['value'];
    if (!newValues.any((e) => e['value'] == value)) {
      newValues.add(node);
    }
    for (final dynamic child in (node['children'] as List? ?? [])) {
      _checkWithChildren(child);
    }
  }

  /// 取消勾选父级时把整棵子树一起取消
  void _uncheckWithChildren(Map<String, dynamic> node) {
    final Set<dynamic> ids = { };
    void walk(List nodes) {
      for (final dynamic n in nodes) {
        ids.add(n['value']);
        walk(n['children'] as List? ?? []);
      }
    }
    walk([node]);
    newValues.removeWhere((e) => ids.contains(e['value']));
  }

}