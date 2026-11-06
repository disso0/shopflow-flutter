import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(); // Запускаем бесконечный цикл анимации

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Подстраиваем цвета блика под текущую тему приложения
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.3, 0.5, 0.7],
              begin: Alignment(_animation.value - 1, -0.3),
              end: Alignment(_animation.value + 1, 0.3),
            ),
          ),
        );
      },
    );
  }
}

class ShimmerProductCard extends StatelessWidget {
  final bool isMobile;

  const ShimmerProductCard({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Flex(
          direction: isMobile ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: isMobile
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            // Скелет для иконки/картинки
            ShimmerLoading(
              width: isMobile ? 65 : double.infinity,
              height: isMobile ? 65 : 100,
            ),
            SizedBox(width: isMobile ? 12 : 0, height: isMobile ? 0 : 8),
            // Скелет для текстовых полей
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: isMobile
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerLoading(width: 60, height: 10), // Категория
                      const SizedBox(height: 6),
                      const ShimmerLoading(width: 140, height: 16), // Заголовок
                      if (!isMobile) ...[
                        const SizedBox(height: 6),
                        const ShimmerLoading(
                          width: double.infinity,
                          height: 12,
                        ), // Описание строка 1
                        const SizedBox(height: 4),
                        const ShimmerLoading(
                          width: 100,
                          height: 12,
                        ), // Описание строка 2
                      ],
                    ],
                  ),
                  if (!isMobile) const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerLoading(width: 70, height: 16), // Цена
                      ShimmerLoading(
                        width: 24,
                        height: 24,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ), // Кнопка корзины
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerCatalogPlaceholder extends StatelessWidget {
  final bool isMobile;
  final int columns;

  const ShimmerCatalogPlaceholder({
    super.key,
    required this.isMobile,
    this.columns = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveColumns = isMobile ? 1 : columns;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: effectiveColumns * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: effectiveColumns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: effectiveColumns == 1 ? 130 : 300,
          ),
          itemBuilder: (context, index) {
            return ShimmerProductCard(isMobile: effectiveColumns == 1);
          },
        );
      },
    );
  }
}
