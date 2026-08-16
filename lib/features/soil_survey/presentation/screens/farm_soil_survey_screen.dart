import 'package:flutter/material.dart';
import 'package:chaona_app/features/farm_management/domain/entities/farm.dart';
import 'package:chaona_app/features/soil_survey/presentation/screens/plot_survey_screen.dart';

class FarmSoilSurveyScreen extends StatelessWidget {
  final Farm farm;

  const FarmSoilSurveyScreen({super.key, required this.farm});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ตรวจดิน: ${farm.name}')),
      body: farm.plots.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ยังไม่มีแปลงย่อยในฟาร์มนี้\nกรุณาสร้างแปลงย่อยก่อนเริ่มเก็บตัวอย่างดิน',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: farm.plots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final plot = farm.plots[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.grid_on_outlined),
                    title: Text(plot.name),
                    subtitle: Text(
                      '${plot.cropType} | ${plot.areaRai.toStringAsFixed(1)} ไร่',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlotSurveyScreen(farm: farm, plot: plot),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
