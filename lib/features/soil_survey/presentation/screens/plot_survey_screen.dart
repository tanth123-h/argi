import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../farm_management/domain/entities/farm.dart';
import '../../../farm_management/domain/entities/plot.dart';
import '../../domain/entities/sampling_point.dart';
import '../../domain/entities/soil_sample.dart';
import '../providers/soil_survey_provider.dart';

class PlotSurveyScreen extends ConsumerStatefulWidget {
  final Farm farm;
  final Plot plot;

  const PlotSurveyScreen({super.key, required this.farm, required this.plot});

  @override
  ConsumerState<PlotSurveyScreen> createState() => _PlotSurveyScreenState();
}

class _PlotSurveyScreenState extends ConsumerState<PlotSurveyScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(soilSurveyProvider.notifier).start(widget.plot));
  }

  @override
  Widget build(BuildContext context) {
    final survey = ref.watch(soilSurveyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.plot.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('เก็บตัวอย่างดิน', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('เดินตามจุดที่แนะนำ หลีกเลี่ยงขอบแปลง กองปุ๋ย ถนน และแหล่งน้ำ'),
          const SizedBox(height: 16),
          _SummaryCard(state: survey),
          const SizedBox(height: 12),
          Text('จุดเก็บตัวอย่าง', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final point in survey.points) _PointTile(point: point, onRecord: () => _showSampleForm(point)),
        ],
      ),
    );
  }

  Future<void> _showSampleForm(SamplingPoint point) async {
    final formKey = GlobalKey<FormState>();
    final nitrogen = TextEditingController();
    final phosphorus = TextEditingController();
    final potassium = TextEditingController();
    final ph = TextEditingController();
    final moisture = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: Form(
          key: formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('บันทึกผล จุดที่ ${point.sequence}', style: Theme.of(context).textTheme.titleLarge),
              _numberField(nitrogen, 'ไนโตรเจน (N)', true),
              _numberField(phosphorus, 'ฟอสฟอรัส (P)', true),
              _numberField(potassium, 'โพแทสเซียม (K)', true),
              _numberField(ph, 'pH (ไม่บังคับ)', false),
              _numberField(moisture, 'ความชื้น % (ไม่บังคับ)', false),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  ref.read(soilSurveyProvider.notifier).recordSample(SoilSample(
                    id: const Uuid().v4(),
                    plotId: widget.plot.id,
                    samplingPointId: point.id,
                    nitrogen: double.parse(nitrogen.text),
                    phosphorus: double.parse(phosphorus.text),
                    potassium: double.parse(potassium.text),
                    ph: double.tryParse(ph.text),
                    moisture: double.tryParse(moisture.text),
                    sampledAt: DateTime.now(),
                    source: SampleSource.handheld,
                  ));
                  Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('บันทึกผล'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label, bool required) => TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => double.tryParse(value ?? '') == null ? 'กรอกตัวเลข' : null
            : null,
      );
}

class _PointTile extends StatelessWidget {
  final SamplingPoint point;
  final VoidCallback onRecord;

  const _PointTile({required this.point, required this.onRecord});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Text('${point.sequence}')),
          title: Text('จุดที่ ${point.sequence}'),
          subtitle: Text(_label(point.status)),
          trailing: point.status == SamplingPointStatus.sampled
              ? const Icon(Icons.check_circle, color: Colors.green)
              : FilledButton.tonal(onPressed: onRecord, child: const Text('บันทึกผล')),
        ),
      );

  String _label(SamplingPointStatus status) => switch (status) {
        SamplingPointStatus.pending => 'รอเก็บตัวอย่าง',
        SamplingPointStatus.sampled => 'บันทึกแล้ว',
        SamplingPointStatus.skipped => 'ข้ามจุดนี้',
      };
}

class _SummaryCard extends StatelessWidget {
  final SoilSurveyState state;
  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ความคืบหน้า ${state.samples.length}/${state.points.length} จุด'),
          if (summary != null) ...[
            const SizedBox(height: 8),
            Text('N ${summary.medianNitrogen?.toStringAsFixed(0)}  P ${summary.medianPhosphorus?.toStringAsFixed(0)}  K ${summary.medianPotassium?.toStringAsFixed(0)}'),
            Text('ความมั่นใจ: ${summary.confidence.name}'),
          ],
        ]),
      ),
    );
  }
}
