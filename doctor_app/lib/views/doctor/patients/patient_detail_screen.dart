import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/doctor_portal_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/doctor/patient_record.dart';
import 'package:intl/intl.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  int _selectedTab = 0; // 0: History, 1: Trends

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoctorPortalProvider>();
    final patient = provider.selectedPatient;
    
    if (patient == null || patient.id != widget.patientId) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1D),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          patient.fullName,
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
                ? _buildHistoryFeed(provider)
                : _buildTelemetryTrends(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PatientRecord patient) {
    final age = patient.dateOfBirth != null
        ? DateTime.now().difference(patient.dateOfBirth!).inDays ~/ 365
        : 'Unknown';

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
                '${age}yo • ${patient.gender}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0F1D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${patient.affectedSide.toUpperCase()} Hand',
                  style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            patient.notes.isNotEmpty ? patient.notes : 'No clinical notes provided.',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
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
                    'Session History',
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
                    'Progress Metrics',
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

  Widget _buildHistoryFeed(DoctorPortalProvider provider) {
    if (provider.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }
    if (provider.activePatientHistory.isEmpty) {
      return const Center(
        child: Text('No therapy sessions recorded yet.', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: provider.activePatientHistory.length,
      itemBuilder: (context, index) {
        final session = provider.activePatientHistory[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(dynamic session) {
    // Attempt to parse standard fields out of the dynamic map
    final dateStr = session['date'] ?? session['created_at'] ?? session['start_time'] ?? session['timestamp'];
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final gameName = session['game_name'] ?? session['game_id'] ?? 'Game Session';
    final score = session['score'] ?? 0;
    final accuracy = session['accuracy'] ?? 0.0;
    final sessionId = session['id'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F36),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          date != null ? DateFormat('MMM d, yyyy - h:mm a').format(date) : 'Unknown Date',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              gameName.toString(),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Score: $score',
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 16),
                Text(
                  'Accuracy: ${accuracy is double ? accuracy.toStringAsFixed(1) : accuracy}%',
                  style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w600),
                ),
              ],
            )
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        onTap: () {
          if (sessionId != null) {
            _showAiOverviewDialog(sessionId);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session ID is missing.')),
            );
          }
        },
      ),
    );
  }

  void _showAiOverviewDialog(String gameSessionId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161F36),
          title: const Text('AI Overview', style: TextStyle(color: Colors.white)),
          content: FutureBuilder<Map<String, dynamic>>(
            future: context.read<DoctorPortalProvider>().getGameSessionAiOverview(gameSessionId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
                );
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }

              final data = snapshot.data;
              if (data == null) {
                return const Text('No AI overview available.', style: TextStyle(color: Colors.white54));
              }

              final overview = data['overview'] ?? 'No overview available.';
              final focusAreas = (data['focus_areas'] as List<dynamic>?) ?? [];
              final status = data['status'] ?? 'Unknown';

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $status', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Overview:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    MarkdownBody(
                      data: overview,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white70),
                        h1: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        h3: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (focusAreas.isNotEmpty) ...[
                      const Text('Focus Areas:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...focusAreas.map((area) => Text('• $area', style: const TextStyle(color: Colors.white70))),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTelemetryTrends(DoctorPortalProvider provider) {
    if (provider.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }
    
    final history = provider.activePatientHistory;
    if (history.isEmpty) {
      return const Center(
        child: Text('No telemetry data available.', style: TextStyle(color: Colors.white54)),
      );
    }

    final spots = history.asMap().entries.map((e) {
      // parse accuracy, default to 0
      double acc = 0;
      if (e.value['accuracy'] != null) {
        if (e.value['accuracy'] is int) acc = (e.value['accuracy'] as int).toDouble();
        else if (e.value['accuracy'] is double) acc = e.value['accuracy'] as double;
      }
      return FlSpot(e.key.toDouble(), acc);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accuracy Trends',
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
                          '${value.toInt()}%',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (history.length > 1 ? history.length - 1 : 1).toDouble(),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF00E5FF),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
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
