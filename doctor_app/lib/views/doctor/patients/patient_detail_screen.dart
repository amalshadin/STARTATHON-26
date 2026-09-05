import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/doctor_state_provider.dart';
import '../../../models/patient.dart';
import 'package:intl/intl.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  int _selectedTab = 0; // 0: SBAR, 1: Telemetry

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorStateProvider>();
    final patient = provider.patients.firstWhere((p) => p.id == widget.patientId);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          patient.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Demographics Header
          _buildHeader(patient),
          const SizedBox(height: 16),
          
          // Custom Tab Bar
          _buildSegmentedControl(),
          const SizedBox(height: 16),
          
          // Tab Content
          Expanded(
            child: _selectedTab == 0
                ? _buildSbarFeed(patient)
                : _buildTelemetryTrends(patient),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Patient patient) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161F36),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${patient.age}yo • ${patient.strokeSubtype} Stroke',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0F1D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${patient.affectedHand} Hand',
                  style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Baseline Calibration',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: patient.baselineCalibration.entries.map((e) {
              return Column(
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    '${e.value}°',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF161F36),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'SBAR Clinical Feed',
                    style: TextStyle(
                      color: _selectedTab == 0 ? const Color(0xFF00E5FF) : Colors.white54,
                      fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Telemetry Trends',
                    style: TextStyle(
                      color: _selectedTab == 1 ? const Color(0xFF00E5FF) : Colors.white54,
                      fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSbarFeed(Patient patient) {
    if (patient.reports.isEmpty) {
      return const Center(
        child: Text('No clinical reports yet.', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: patient.reports.length,
      itemBuilder: (context, index) {
        final report = patient.reports[index];
        return _buildSbarCard(report);
      },
    );
  }

  Widget _buildSbarCard(SBARReport report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F36),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        iconColor: Colors.white,
        collapsedIconColor: Colors.white54,
        title: Text(
          DateFormat('MMM d, yyyy').format(report.date),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          report.situation,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _buildSbarSection('S - Situation', report.situation, const Color(0xFFF59E0B)),
          _buildSbarSection('B - Background', report.background, const Color(0xFF3B82F6)),
          _buildSbarSection('A - Assessment', report.assessment, const Color(0xFF10B981)),
          _buildSbarSection('R - Recommendation', report.recommendation, const Color(0xFF00E5FF)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.share, color: Color(0xFF00E5FF), size: 16),
              label: const Text('Export PDF', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSbarSection(String title, String content, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTrends(Patient patient) {
    if (patient.telemetry.isEmpty) {
      return const Center(
        child: Text('No telemetry data available.', style: TextStyle(color: Colors.white54)),
      );
    }

    final spots = patient.telemetry.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.arom);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Range of Motion (30 Days)',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white12,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}°',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: patient.telemetry.length.toDouble() - 1,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF00E5FF),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00E5FF).withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
