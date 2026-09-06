import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/design_tokens.dart';
import '../../services/patient_api_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Telemetry', style: DesignTokens.headingStyle),
      ),
      body: SafeArea(
        child: Padding(
          padding: DesignTokens.defaultPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Active Range of Motion (AROM)', style: DesignTokens.headingStyle.copyWith(color: DesignTokens.primaryColor, fontSize: 20)),
              const SizedBox(height: 8),
              const Text('Weekly progress for index and middle fingers.', style: DesignTokens.bodyStyle),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<Map<String, List<double>>>(
                  future: PatientApiService().getWeeklyAnalytics(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final indexData = snapshot.data?['index'] ?? [];
                    final middleData = snapshot.data?['middle'] ?? [];

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.borderRadiusMedium)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true, drawVerticalLine: false),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                    if (value.toInt() >= 0 && value.toInt() < days.length) {
                                      return Text(days[value.toInt()]);
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(indexData.length, (i) => FlSpot(i.toDouble(), indexData[i])),
                                isCurved: true,
                                color: DesignTokens.primaryColor,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                              ),
                              LineChartBarData(
                                spots: List.generate(middleData.length, (i) => FlSpot(i.toDouble(), middleData[i])),
                                isCurved: true,
                                color: DesignTokens.secondaryColor,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
