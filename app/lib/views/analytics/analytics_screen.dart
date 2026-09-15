import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/design_tokens.dart';
import '../../services/patient_api_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundLight,
      appBar: AppBar(
        title: const Text('AI Progress Analysis', style: DesignTokens.headingStyle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: DesignTokens.defaultPadding,
          child: FutureBuilder<Map<String, dynamic>?>(
            future: PatientApiService().getProgressSummary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }
              
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return _buildErrorState();
              }

              final data = snapshot.data!;
              final int sessionCount = data['session_count'] ?? 0;
              final int minSessions = data['min_sessions_required'] ?? 3;
              final String status = data['status'] ?? 'pending_sessions';
              final String summary = data['summary'] ?? '';
              final String message = data['message'] ?? '';

              if (status == 'completed' && summary.isNotEmpty) {
                return _buildCompletedState(sessionCount, summary, message);
              } else {
                return _buildPendingState(sessionCount, minSessions, message);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DesignTokens.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: DesignTokens.primaryColor,
              strokeWidth: 3,
            ),
          ).animate(onPlay: (controller) => controller.repeat())
           .shimmer(duration: 1500.ms, color: DesignTokens.primaryColor.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            'AI synthesizing your rehabilitation data...',
            style: DesignTokens.bodyStyle.copyWith(color: DesignTokens.primaryColor, fontStyle: FontStyle.italic),
          ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Unable to fetch AI progress summary.\nPlease try again later.',
            textAlign: TextAlign.center,
            style: DesignTokens.bodyStyle.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState(int current, int required, String message) {
    double progress = required > 0 ? (current / required).clamp(0.0, 1.0) : 0.0;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey[200],
                  color: DesignTokens.secondaryColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$current / $required',
                    style: DesignTokens.headingStyle.copyWith(fontSize: 32, color: DesignTokens.primaryColor),
                  ),
                  Text(
                    'Sessions',
                    style: DesignTokens.bodyStyle.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 48),
          Text(
            'More Data Required',
            style: DesignTokens.headingStyle.copyWith(fontSize: 24),
          ).animate().fadeIn(delay: 400.ms).slideY(),
          const SizedBox(height: 16),
          Text(
            message.isNotEmpty ? message : 'The AI requires more therapy sessions to generate a confident clinical summary of your progress.',
            textAlign: TextAlign.center,
            style: DesignTokens.bodyStyle.copyWith(color: Colors.grey[700], height: 1.5),
          ).animate().fadeIn(delay: 500.ms).slideY(),
        ],
      ),
    );
  }

  Widget _buildCompletedState(int sessions, String summary, String message) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DesignTokens.primaryColor, DesignTokens.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(DesignTokens.borderRadiusLarge),
              boxShadow: [
                BoxShadow(
                  color: DesignTokens.primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Assessment Ready',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on $sessions completed sessions',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),
          
          const SizedBox(height: 32),
          
          // Summary Content
          Text(
            'Clinical Summary',
            style: DesignTokens.headingStyle.copyWith(fontSize: 22, color: DesignTokens.textPrimaryLight),
          ).animate().fadeIn(delay: 200.ms),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DesignTokens.borderRadiusLarge),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              summary,
              style: DesignTokens.bodyStyle.copyWith(
                color: Colors.grey[800],
                height: 1.6,
                fontSize: 16,
              ),
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

          if (message.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: DesignTokens.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(DesignTokens.borderRadiusMedium),
                border: Border.all(color: DesignTokens.secondaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: DesignTokens.secondaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: DesignTokens.secondaryColor, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
