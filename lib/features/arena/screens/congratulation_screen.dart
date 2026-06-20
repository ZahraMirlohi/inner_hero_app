import 'package:flutter/material.dart';

class CongratulationScreen extends StatefulWidget {
  final int todayXP;
  final int totalTasksCompleted;
  final int totalHabitsCompleted;
  final String? avatarImageUrl;

  const CongratulationScreen({
    super.key,
    required this.todayXP,
    required this.totalTasksCompleted,
    required this.totalHabitsCompleted,
    this.avatarImageUrl,
  });

  @override
  State<CongratulationScreen> createState() => _CongratulationScreenState();
}

class _CongratulationScreenState extends State<CongratulationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  String _dailyQuote = '';
  String _quoteAuthor = '';
  bool _isLoading = true;

  final List<Map<String, String>> _quotes = [
    {
      'quote':
          'تنها محدودیتی که دارید، محدودیتی است که خودتان در ذهنتان ایجاد می‌کنید.',
      'author': 'نپلئون هیل',
    },
    {
      'quote': 'موفقیت مجموع تلاش‌های کوچکی است که روز به روز تکرار می‌شوند.',
      'author': 'رابرت کالیر',
    },
    {
      'quote': 'با انجام کارهای کوچک هر روز، می‌توانید به نتایج بزرگ برسید.',
      'author': 'لائوتسه',
    },
    {'quote': 'عادت‌های خوب، کلید موفقیت هستند.', 'author': 'ارسطو'},
    {
      'quote': 'آینده‌ای که می‌خواهید، در کارهایی است که امروز انجام می‌دهید.',
      'author': 'تونی رابینز',
    },
    {
      'quote': 'هیچ چیز غیرممکن نیست، فقط نیاز به تلاش بیشتر دارد.',
      'author': 'توماس ادیسون',
    },
    {'quote': 'هر روز یک فرصت جدید برای بهتر شدن است.', 'author': 'آن فرانک'},
    {'quote': 'پایداری و استمرار، رمز موفقیت است.', 'author': 'کنفوسیوس'},
    {
      'quote':
          'بهترین زمان برای شروع، دیروز بود. دومین بهترین زمان، امروز است.',
      'author': 'ضرب‌المثل چینی',
    },
    {'quote': 'قطره قطره جمع گردد، دریا شود.', 'author': 'سعدی'},
    {'quote': 'سفر هزار فرسنگی با یک قدم آغاز می‌شود.', 'author': 'لائوتسه'},
    {
      'quote': 'هر روز شما صفحه جدیدی از کتاب زندگی‌تان است.',
      'author': 'اپکتتوس',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectDailyQuote();
    _initAnimations();
  }

  void _selectDailyQuote() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final quoteIndex = dayOfYear % _quotes.length;

    setState(() {
      _dailyQuote = _quotes[quoteIndex]['quote']!;
      _quoteAuthor = _quotes[quoteIndex]['author']!;
      _isLoading = false;
    });
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF4A90E2),
        body: SafeArea(
          child: Stack(
            children: [
              _buildBackgroundDecorations(),
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: _buildAvatar(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            const Text(
                              'تبریک! 🎉',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'شما امروز عالی بودید!',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Text(
                                  'دستاورد امروز شما',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(
                                      icon: Icons.fitness_center,
                                      value: widget.totalHabitsCompleted,
                                      label: 'عادت',
                                      color: const Color(0xFF4A90E2),
                                    ),
                                    _buildStatItem(
                                      icon: Icons.assignment,
                                      value: widget.totalTasksCompleted,
                                      label: 'تسک',
                                      color: const Color(0xFFFFA500),
                                    ),
                                    _buildStatItem(
                                      icon: Icons.stars,
                                      value: widget.todayXP,
                                      label: 'امتیاز XP',
                                      color: const Color(0xFF9B59B6),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Card(
                          color: Colors.white.withOpacity(0.95),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.format_quote,
                                      color: const Color(
                                        0xFF4A90E2,
                                      ).withOpacity(0.6),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'پیام روزانه',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.format_quote,
                                      color: const Color(
                                        0xFF4A90E2,
                                      ).withOpacity(0.6),
                                      size: 24,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (!_isLoading) ...[
                                  Text(
                                    '✨ $_dailyQuote ✨',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '— $_quoteAuthor —',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4A90E2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'ادامه ماجراجویی 🚀',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: 30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 150,
            right: 40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: widget.avatarImageUrl != null
          ? ClipOval(
              child: Image.network(
                widget.avatarImageUrl!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.emoji_events,
                    size: 60,
                    color: Color(0xFFFFA500),
                  );
                },
              ),
            )
          : const Icon(Icons.emoji_events, size: 60, color: Color(0xFFFFA500)),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
