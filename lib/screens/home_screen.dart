import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/feature_card.dart';
import '../main.dart';
import 'text_enhancement_screen.dart';
import 'document_scan_screen.dart';
import 'document_summary_screen.dart';
import '../i18n/app_localizations_extension.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            _buildHeroSection(),
            _buildFeaturesGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: false,
      pinned: true,
      expandedHeight: 0,
      centerTitle: false,
      title: Row(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  context.tr.translate('app_title') ?? 'Study Companion',
                  style: AppTheme.headingSmall,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkTextColor
                : AppTheme.textPrimaryColor,
          ),
          onPressed: () {
            final themeProvider =
                Provider.of<ThemeProvider>(context, listen: false);
            themeProvider.setThemeMode(
              Theme.of(context).brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: EdgeInsets.fromLTRB(16, 16, 16, 24),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [AppTheme.darkCardColor, AppTheme.darkBackgroundColor]
                    : [AppTheme.primaryColor, AppTheme.primaryDarkColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.translate('your_ultimate') ??
                                'Your Ultimate',
                            style: AppTheme.headingMedium.copyWith(
                              color: Colors.white,
                              fontSize: 26,
                            ),
                          ),
                          Text(
                            context.tr.translate('study_companion') ??
                                'Study Companion',
                            style: AppTheme.headingLarge.copyWith(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            context.tr.translate('transform_your_learning') ??
                                'Transform your learning with AI-powered tools for instant answers, essay enhancement, and more.',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.emoji_objects_outlined,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DocumentScanScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt),
                      SizedBox(width: 8),
                      Text(context.tr.translate('scan_a_question') ??
                          'Scan a Question'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    final features = [
      {
        'icon': Icons.document_scanner,
        'title': context.tr.translate('instant_scan_solve') ??
            'Instant Scan & Solve',
        'description': context.tr.translate('instant_scan_description') ??
            'Capture questions with your camera and get step-by-step solutions',
        'color': AppTheme.primaryColor,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DocumentScanScreen()),
            ),
      },
      {
        'icon': Icons.edit_note,
        'title':
            context.tr.translate('essay_enhancement') ?? 'Essay Enhancement',
        'description': context.tr.translate('essay_enhancement_description') ??
            'Improve, paraphrase, or expand your writing with AI assistance',
        'color': Color(0xFF5E60CE),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TextEnhancementScreen()),
            ),
      },
      {
        'icon': Icons.description,
        'title': context.tr.translate('document_summary') ??
            'Document Summarization',
        'description': context.tr.translate('document_summary_description') ??
            'Upload PDFs or text files to get concise summaries',
        'color': Color(0xFF2DC96B),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DocumentSummaryScreen()),
            ),
      },
      {
        'icon': Icons.quiz,
        'title':
            context.tr.translate('knowledge_quizzes') ?? 'Knowledge Quizzes',
        'description': context.tr.translate('knowledge_quizzes_description') ??
            'Test your knowledge with AI-generated quizzes on any topic',
        'color': Color(0xFFFFB800),
        'onTap': () => _showComingSoonDialog(
            context.tr.translate('knowledge_quizzes') ?? 'Knowledge Quizzes'),
      },
      {
        'icon': Icons.language,
        'title': context.tr.translate('language') ?? 'Language Mastery',
        'description': context.tr.translate('language_description') ??
            'Improve your language skills with translation and grammar help',
        'color': Color(0xFF21AAFF),
        'onTap': () => _showComingSoonDialog(
            context.tr.translate('language') ?? 'Language Mastery'),
      },
      {
        'icon': Icons.code,
        'title': context.tr.translate('coding_support') ?? 'Coding Support',
        'description': context.tr.translate('coding_support_description') ??
            'Get explanations, code reviews, and programming assistance',
        'color': Color(0xFFFF5252),
        'onTap': () => _showComingSoonDialog(
            context.tr.translate('coding_support') ?? 'Coding Support'),
      },
    ];

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Add a delay to each item for a staggered animation effect
            final itemDelay = (index + 2) * 100;

            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final animationProgress = _animationController.value * 800;
                final showItem = animationProgress >= itemDelay;

                return AnimatedOpacity(
                  opacity: showItem ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  child: AnimatedSlide(
                    offset: showItem ? Offset.zero : Offset(0, 0.1),
                    duration: Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: child!,
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: FeatureCard(
                  icon: features[index]['icon'] as IconData,
                  title: features[index]['title'] as String,
                  description: features[index]['description'] as String,
                  color: features[index]['color'] as Color,
                  onTap: features[index]['onTap'] as VoidCallback,
                ),
              ),
            );
          },
          childCount: features.length,
        ),
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(context.tr.translate('coming_soon') ?? 'Coming Soon!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppTheme.primaryColor.withOpacity(0.2)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.rocket_launch,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 16),
              Text(
                context.tr
                        .translate('feature_available_soon')
                        ?.replaceAll('{feature}', feature) ??
                    '$feature will be available in the next update!',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium,
              ),
              SizedBox(height: 8),
              Text(
                context.tr.translate('working_hard_feature') ??
                    "We're working hard to bring you this feature soon.",
                textAlign: TextAlign.center,
                style: AppTheme.bodySmall.copyWith(
                  color: isDarkMode
                      ? AppTheme.darkTextColor.withOpacity(0.7)
                      : AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(context.tr.translate('cant_wait') ?? 'Can\'t Wait!'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
