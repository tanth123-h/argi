import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/sampling_point.dart';
import '../../domain/entities/soil_plot_summary.dart';
import '../../domain/entities/soil_sample.dart';
import '../../domain/services/sampling_point_generator.dart';
import '../../domain/services/soil_survey_calculator.dart';
import '../../../farm_management/domain/entities/plot.dart';

class SoilSurveyState {
  final Plot? plot;
  final List<SamplingPoint> points;
  final List<SoilSample> samples;
  final SoilPlotSummary? summary;
  final String? error;

  const SoilSurveyState({
    this.plot,
    this.points = const [],
    this.samples = const [],
    this.summary,
    this.error,
  });
}

class SoilSurveyNotifier extends Notifier<SoilSurveyState> {
  final _generator = SamplingPointGenerator();
  final _calculator = SoilSurveyCalculator();

  @override
  SoilSurveyState build() => const SoilSurveyState();

  void start(Plot plot) {
    final boundary = plot.boundary.isEmpty
        ? const [LatLng(14, 100), LatLng(14, 100.01), LatLng(14.01, 100.01), LatLng(14.01, 100)]
        : plot.boundary;
    state = SoilSurveyState(
      plot: plot,
      points: _generator.generate(
        plotId: plot.id,
        boundary: boundary,
        count: SamplingPointGenerator.recommendedCount(plot.areaRai),
      ),
    );
  }

  void recordSample(SoilSample sample) {
    final samples = [...state.samples.where((item) => item.samplingPointId != sample.samplingPointId), sample];
    final points = state.points.map((point) => point.id == sample.samplingPointId
        ? point.copyWith(status: SamplingPointStatus.sampled)
        : point).toList();
    state = SoilSurveyState(
      plot: state.plot,
      points: points,
      samples: samples,
      summary: _calculator.summarize(plotId: sample.plotId, samples: samples, now: DateTime.now()),
    );
  }

  void skipPoint(String pointId, String reason) {
    if (reason.trim().isEmpty) return;
    state = SoilSurveyState(
      plot: state.plot,
      points: state.points.map((point) => point.id == pointId
          ? point.copyWith(status: SamplingPointStatus.skipped)
          : point).toList(),
      samples: state.samples,
      summary: state.summary,
    );
  }

  void reset() => state = const SoilSurveyState();
}

final soilSurveyProvider = NotifierProvider<SoilSurveyNotifier, SoilSurveyState>(SoilSurveyNotifier.new);
