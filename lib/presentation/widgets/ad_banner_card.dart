import 'package:flutter/material.dart';

class AdBannerCard extends StatelessWidget {
  final bool isMobile;
  // Сделаем данные баннера опциональными, чтобы поддерживать как спонсорский блок, так и слайдер
  final Map<String, dynamic>? bannerData;

  const AdBannerCard({super.key, required this.isMobile, this.bannerData});

  void _openAdLink(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Переход по рекламной ссылке... [Имитация]'),
        backgroundColor: Colors.blueAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Определяем цвета: либо из переданного баннера, либо дефолтный янтарный градиент
    final List<Color> gradientColors = bannerData?['colors'] != null
        ? (bannerData!['colors'] as List<Color>)
        : (isDark
              ? [
                  Colors.amber.shade900.withValues(alpha: 0.15),
                  Colors.grey.shade900,
                ]
              : [Colors.amber.shade50.withValues(alpha: 0.5), Colors.white]);

    // Текстовые данные
    final String label = bannerData != null ? 'АКЦИЯ' : 'РЕКЛАМА';
    final String sectionTitle = bannerData != null
        ? 'СПЕЦПРЕДЛОЖЕНИЕ'
        : 'СПОНСОРСКИЙ БЛОК';
    final String mainTitle =
        bannerData?['title'] ?? 'Курс по Flutter: от Новичка до Фрилансера!';
    final String subtitle =
        bannerData?['subtitle'] ??
        'Освойте разработку под Web, Mobile и Desktop за 3 месяца.';
    final String badgeText = bannerData?['discount'] ?? 'Скидка 50%';

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: bannerData != null
              ? Colors.blue.withValues(alpha: 0.5)
              : Colors.amber,
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Flex(
            direction: isMobile ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: isMobile
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              // Картинка / Иконка
              Stack(
                children: [
                  Container(
                    width: isMobile ? 65 : double.infinity,
                    height: isMobile ? 65 : 90,
                    decoration: BoxDecoration(
                      color: (bannerData != null ? Colors.blue : Colors.amber)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      bannerData != null
                          ? Icons.local_offer_rounded
                          : Icons.star_rounded,
                      size: 35,
                      color: bannerData != null ? Colors.blue : Colors.amber,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: bannerData != null
                            ? Colors.blue.shade700
                            : Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12, height: 8),
              // Текст
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
                        Text(
                          sectionTitle,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: bannerData != null
                                ? Colors.blue.shade400
                                : Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mainTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!isMobile) const SizedBox(height: 8),
                    // Кнопка действия
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          badgeText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openAdLink(context),
                          style: TextButton.styleFrom(
                            backgroundColor: bannerData != null
                                ? Colors.blue.shade700
                                : Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            bannerData != null ? 'Смотреть' : 'Узнать больше',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
