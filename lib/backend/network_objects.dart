import 'package:flutter/material.dart';

class NetworkList<T extends ObjectProvider<T>> {
  final int itemCount;
  final int _pageSize;
  final List<ObjectProvider<T>> _list;
  final Set<int> _requested = {}; //requested and loeaded pages
  final Future<List<T>> Function(int offset, int size) _fetchPage;

  NetworkList({
    required this.itemCount,
    required int pageSize,
    required List<T> initialPage,
    required Future<List<T>> Function(int, int) fetchPage,
  }) : _fetchPage = fetchPage,
       _pageSize = pageSize,
       _list = [...initialPage] {
    _list.addAll(
      List.generate(
        itemCount - _list.length,
        (i) => NetworkProvider(
          networkList: this,
          index: i + _list.length,
          value: null,
        ),
      ),
    );
  }

  ObjectProvider<T> operator [](int index) {
    assert(index >= 0 && index < itemCount);
    return _list[index];
  }

  Future<void> loadItem(int index) async {
    assert(index >= 0 && index < itemCount);
    final page = index ~/ _pageSize;
    if (_requested.contains(page)) return;
    _requested.add(page);

    final offset = page * _pageSize;
    final items = await _fetchPage(offset, _pageSize);

    for (var i = 0; i < items.length; i++) {
      final itemIndex = offset + i;
      if (itemIndex >= _list.length) break;
      final provider = _list[itemIndex];
      if (provider is NetworkProvider<T>) {
        provider.value = items[i];
      }
    }
  }
}

class ObjectProvider<T> {
  const ObjectProvider();
}

class NetworkProvider<T extends ObjectProvider<T>> extends ValueNotifier<T?>
    implements ObjectProvider<T> {
  final NetworkList<T> networkList;
  final int index;

  NetworkProvider({
    required this.networkList,
    required this.index,
    required T? value,
  }) : super(value);
}

class ObjectProviderBuilder<T extends ObjectProvider<T>>
    extends StatelessWidget {
  final ObjectProvider<T>? provider;
  final Widget Function(BuildContext context, T? value) buildFunction;

  const ObjectProviderBuilder({
    super.key,
    required this.provider,
    required this.buildFunction,
  });

  @override
  Widget build(BuildContext context) {
    if (provider == null) {
      return buildFunction(context, null);
    }

    if (provider is T) {
      return buildFunction(context, provider as T);
    }

    if (provider is NetworkProvider<T>) {
      final networkProvider = provider as NetworkProvider<T>;
      return ValueListenableBuilder<T?>(
        valueListenable: networkProvider,
        builder: (context, value, child) {
          if (value == null) {
            networkProvider.networkList.loadItem(networkProvider.index);
          }
          return buildFunction(context, value);
        },
      );
    }

    throw Exception('Unknown provider type: ${provider.runtimeType}');
  }
}

T? getValue<T extends ObjectProvider<T>>(ObjectProvider<T> provider) {
  if (provider is T) {
    return provider;
  }

  if (provider is NetworkProvider<T>) {
    final NetworkProvider<T> networkProvider = provider;
    final value = networkProvider.value;
    return value;
  }

  throw Exception('Unknown provider type: ${provider.runtimeType}');
}
