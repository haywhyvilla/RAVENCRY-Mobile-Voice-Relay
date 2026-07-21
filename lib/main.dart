import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const VoiceRelayApp());
}

class RelayColors {
  const RelayColors._();

  static const background = Color(0xFF0A0A0A);
  static const card = Color(0xFF1A1A1A);
  static const foreground = Color(0xFFFAFAFA);
  static const muted = Color(0xFFA3A3A3);
  static const border = Color(0xFF262626);
  static const red = Color(0xFFDC2626);
  static const amber = Color(0xFFF59E0B);
  static const green = Color(0xFF22C55E);
}

class VoiceRelayApp extends StatelessWidget {
  const VoiceRelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RelayColors.red,
      brightness: Brightness.dark,
      surface: RelayColors.card,
    );

    return MaterialApp(
      title: 'RAVENCRY Voice Relay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: RelayColors.background,
        useMaterial3: true,
      ),
      home: const SafetyShell(),
    );
  }
}

class SafetyShell extends StatefulWidget {
  const SafetyShell({super.key});

  @override
  State<SafetyShell> createState() => _SafetyShellState();
}

class _SafetyShellState extends State<SafetyShell> {
  _RelayLanguage? _selectedLanguage;
  bool _consentConfirmed = false;

  bool get _canContinue => _selectedLanguage != null && _consentConfirmed;

  void _openOutbox() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const _OutboxPage()));
  }

  void _continueToCapture() {
    if (!_canContinue) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            _CapturePreparationPage(language: _selectedLanguage!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _Header(onOutbox: _openOutbox),
            const SizedBox(height: 32),
            const _OfflineCard(),
            const SizedBox(height: 16),
            const _SafetyCard(),
            const SizedBox(height: 28),
            const Text(
              'Choose your language',
              style: TextStyle(
                color: RelayColors.foreground,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your report can be prepared in any of these languages.',
              style: TextStyle(color: RelayColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _RelayLanguage.values
                  .map(
                    (language) => ChoiceChip(
                      key: Key('language-${language.code}'),
                      label: Text(language.label),
                      selected: _selectedLanguage == language,
                      onSelected: (_) {
                        setState(() {
                          _selectedLanguage = language;
                        });
                      },
                      labelStyle: TextStyle(
                        color: _selectedLanguage == language
                            ? RelayColors.foreground
                            : RelayColors.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedColor: RelayColors.red,
                      backgroundColor: RelayColors.card,
                      side: const BorderSide(color: RelayColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: RelayColors.card,
                border: Border.all(color: RelayColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: CheckboxListTile(
                key: const Key('human-review-consent'),
                value: _consentConfirmed,
                onChanged: (value) {
                  setState(() {
                    _consentConfirmed = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: RelayColors.red,
                checkboxShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                title: const Text(
                  'I understand that a human reviews reports before any action is taken.',
                  style: TextStyle(
                    color: RelayColors.foreground,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('continue-to-capture'),
              onPressed: _canContinue ? _continueToCapture : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: RelayColors.red,
                disabledBackgroundColor: RelayColors.red.withValues(alpha: 0.4),
                disabledForegroundColor: RelayColors.foreground,
              ),
              child: const Text('Continue to voice capture'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Reports stay on this device until they are queued for human review.',
              style: TextStyle(color: RelayColors.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RelayLanguage {
  english('en', 'English'),
  hausa('ha', 'Hausa'),
  yoruba('yo', 'Yoruba'),
  igbo('ig', 'Igbo'),
  pidgin('pcm', 'Pidgin');

  const _RelayLanguage(this.code, this.label);

  final String code;
  final String label;
}

class _CapturePreparationPage extends StatefulWidget {
  const _CapturePreparationPage({required this.language});

  final _RelayLanguage language;

  @override
  State<_CapturePreparationPage> createState() =>
      _CapturePreparationPageState();
}

class _CapturePreparationPageState extends State<_CapturePreparationPage> {
  final AudioRecorder _recorder = AudioRecorder();
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;
  bool _isStarting = false;
  bool _showTextFallback = false;
  bool _textResponseReady = false;
  String? _recordingPath;
  String? _fallbackMessage;

  @override
  void dispose() {
    _textController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isStarting || _isRecording) {
      return;
    }

    setState(() {
      _isStarting = true;
      _fallbackMessage = null;
    });

    try {
      final permissionGranted = await _recorder.hasPermission();
      if (!permissionGranted) {
        _showFallback(
          'Microphone access is unavailable. You can continue with a written report instead.',
        );
        return;
      }

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final recordingsDirectory = Directory(
        '${documentsDirectory.path}/voice_relay_recordings',
      );
      await recordingsDirectory.create(recursive: true);

      final recordingPath =
          '${recordingsDirectory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: recordingPath,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _isStarting = false;
        _recordingPath = null;
      });
    } catch (_) {
      _showFallback(
        'Microphone recording could not start on this device. You can continue with a written report instead.',
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      final recordingPath = await _recorder.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _recordingPath = recordingPath;
      });

      if (recordingPath == null) {
        _showFallback(
          'No recording was saved. You can continue with a written report instead.',
        );
      }
    } catch (_) {
      _showFallback(
        'The recording could not be saved. You can continue with a written report instead.',
      );
    }
  }

  void _showFallback([String? message]) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isStarting = false;
      _isRecording = false;
      _showTextFallback = true;
      _fallbackMessage = message;
    });
  }

  void _prepareTextResponse() {
    if (_textController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _textResponseReady = true;
    });
  }

  void _reviewFixture() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _FixtureReviewPage(
          selectedLanguage: widget.language,
          audioLocalPath: _recordingPath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: RelayColors.background,
        foregroundColor: RelayColors.foreground,
        title: const Text('Voice capture'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _OfflineBadge(),
            const SizedBox(height: 32),
            const Icon(
              Icons.mic_none_rounded,
              size: 56,
              color: RelayColors.foreground,
            ),
            const SizedBox(height: 20),
            const Text(
              'Capture your sighting',
              style: TextStyle(
                color: RelayColors.foreground,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Record locally in ${widget.language.label}, or use the text option. Nothing is sent from this device.',
              style: const TextStyle(
                color: RelayColors.muted,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            _RecordControl(
              isRecording: _isRecording,
              isStarting: _isStarting,
              onPressed: _isRecording ? _stopRecording : _startRecording,
            ),
            if (_isRecording) ...[
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Recording locally — tap to stop and save.',
                  style: TextStyle(color: RelayColors.red, fontSize: 16),
                ),
              ),
            ],
            if (_recordingPath != null) ...[
              const SizedBox(height: 20),
              const _InformationCard(
                icon: Icons.check_circle_outline,
                iconColor: RelayColors.green,
                title: 'Local recording saved',
                message:
                    'This audio is stored on this device. It has not been sent.',
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showFallback,
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Use text instead'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: RelayColors.foreground,
                side: const BorderSide(color: RelayColors.border),
              ),
            ),
            if (_showTextFallback) ...[
              const SizedBox(height: 20),
              _TextFallbackCard(
                controller: _textController,
                message: _fallbackMessage,
                onChanged: () {
                  if (_textResponseReady) {
                    setState(() {
                      _textResponseReady = false;
                    });
                  }
                },
                onContinue: _prepareTextResponse,
              ),
            ],
            if (_textResponseReady) ...[
              const SizedBox(height: 16),
              const _InformationCard(
                icon: Icons.article_outlined,
                iconColor: RelayColors.green,
                title: 'Text response ready',
                message:
                    'Your text response is ready for review. It has not been sent.',
              ),
            ],
            if (_recordingPath != null || _textResponseReady) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('review-fixture'),
                onPressed: _reviewFixture,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: RelayColors.red,
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review report'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordControl extends StatelessWidget {
  const _RecordControl({
    required this.isRecording,
    required this.isStarting,
    required this.onPressed,
  });

  final bool isRecording;
  final bool isStarting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isRecording ? 'Stop and save recording' : 'Start recording';

    return FilledButton.icon(
      key: const Key('record-control'),
      onPressed: isStarting ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        backgroundColor: isRecording ? RelayColors.red : RelayColors.card,
        foregroundColor: RelayColors.foreground,
        side: isRecording ? null : const BorderSide(color: RelayColors.border),
      ),
      icon: isStarting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isRecording ? Icons.stop_circle_outlined : Icons.mic_none),
      label: Text(isStarting ? 'Checking microphone…' : label),
    );
  }
}

class _TextFallbackCard extends StatelessWidget {
  const _TextFallbackCard({
    required this.controller,
    required this.message,
    required this.onChanged,
    required this.onContinue,
  });

  final TextEditingController controller;
  final String? message;
  final VoidCallback onChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RelayColors.card,
        border: Border.all(color: RelayColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Text-only report',
            style: TextStyle(
              color: RelayColors.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: const TextStyle(
                color: RelayColors.amber,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            key: const Key('text-fallback-field'),
            controller: controller,
            onChanged: (_) => onChanged(),
            minLines: 4,
            maxLines: 6,
            style: const TextStyle(color: RelayColors.foreground, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Describe what you saw…',
              hintStyle: TextStyle(color: RelayColors.muted),
              filled: true,
              fillColor: RelayColors.background,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            key: const Key('prepare-text-response'),
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: RelayColors.red,
            ),
            child: const Text('Prepare text response'),
          ),
        ],
      ),
    );
  }
}

class _FixtureReviewPage extends StatefulWidget {
  const _FixtureReviewPage({
    required this.selectedLanguage,
    required this.audioLocalPath,
  });

  final _RelayLanguage selectedLanguage;
  final String? audioLocalPath;

  @override
  State<_FixtureReviewPage> createState() => _FixtureReviewPageState();
}

class _FixtureReviewPageState extends State<_FixtureReviewPage> {
  late final Future<_VoiceSightingFixture> _fixture;
  bool _isQueueing = false;

  @override
  void initState() {
    super.initState();
    _fixture = _VoiceSightingFixture.load();
  }

  Future<void> _queueReport(_VoiceSightingFixture fixture) async {
    if (_isQueueing) {
      return;
    }

    setState(() {
      _isQueueing = true;
    });

    try {
      final report = VoiceRelayReport(
        clientSubmissionId: fixture.clientSubmissionId,
        knownCaseId: fixture.knownCaseId,
        kind: fixture.kind,
        language: widget.selectedLanguage.code,
        transcript: fixture.transcript,
        locationLabel: fixture.locationLabel,
        capturedAt: fixture.capturedAt,
        audioLocalPath: widget.audioLocalPath,
        status: 'queued',
        consentConfirmed: true,
      );
      await LocalOutboxStore().queue(report);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => const _OutboxPage(showQueuedConfirmation: true),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isQueueing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to queue this report locally. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: RelayColors.background,
        foregroundColor: RelayColors.foreground,
        title: const Text('Review report'),
      ),
      body: SafeArea(
        child: FutureBuilder<_VoiceSightingFixture>(
          future: _fixture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: _InformationCard(
                  icon: Icons.error_outline,
                  iconColor: RelayColors.amber,
                  title: 'Review unavailable',
                  message: 'The fictional demo report could not be loaded.',
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final fixture = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _OfflineBadge(),
                const SizedBox(height: 28),
                const Text(
                  'Review before queueing',
                  style: TextStyle(
                    color: RelayColors.foreground,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This fictional report is stored locally for human review. It has not been sent.',
                  style: TextStyle(
                    color: RelayColors.muted,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                const _InformationCard(
                  icon: Icons.schedule_outlined,
                  iconColor: RelayColors.amber,
                  title: 'Not sent yet',
                  message:
                      'Queueing happens locally in the next step and requires human review.',
                ),
                const SizedBox(height: 20),
                _ReviewCard(
                  children: [
                    _ReviewDetail(
                      label: 'Hausa transcript',
                      value: fixture.transcript,
                    ),
                    _ReviewDetail(
                      label: 'English gloss',
                      value: fixture.englishGloss,
                    ),
                    _ReviewDetail(
                      label: 'Location',
                      value: fixture.locationLabel,
                    ),
                    _ReviewDetail(
                      label: 'Captured at',
                      value: _formatCaptureTime(fixture.capturedAt),
                    ),
                    _ReviewDetail(
                      label: 'Selected language',
                      value:
                          '${widget.selectedLanguage.label} (${widget.selectedLanguage.code})',
                    ),
                    _ReviewDetail(
                      label: 'Fixture language',
                      value: _languageLabel(fixture.language),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('queue-report'),
                  onPressed: _isQueueing ? null : () => _queueReport(fixture),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: RelayColors.red,
                  ),
                  icon: const Icon(Icons.inbox_outlined),
                  label: Text(
                    _isQueueing
                        ? 'Queueing locally…'
                        : 'Queue for human review',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatCaptureTime(DateTime capturedAt) {
    final watTime = capturedAt.toUtc().add(const Duration(hours: 1));
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour = watTime.hour.toString().padLeft(2, '0');
    final minute = watTime.minute.toString().padLeft(2, '0');
    return '${watTime.day} ${months[watTime.month - 1]} ${watTime.year}, $hour:$minute WAT';
  }

  String _languageLabel(String code) {
    for (final language in _RelayLanguage.values) {
      if (language.code == code) {
        return '${language.label} (${language.code})';
      }
    }
    return code;
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RelayColors.card,
        border: Border.all(color: RelayColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _ReviewDetail extends StatelessWidget {
  const _ReviewDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: RelayColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: RelayColors.foreground,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceSightingFixture {
  const _VoiceSightingFixture({
    required this.clientSubmissionId,
    required this.knownCaseId,
    required this.kind,
    required this.language,
    required this.transcript,
    required this.englishGloss,
    required this.locationLabel,
    required this.capturedAt,
  });

  final String clientSubmissionId;
  final String knownCaseId;
  final String kind;
  final String language;
  final String transcript;
  final String englishGloss;
  final String locationLabel;
  final DateTime capturedAt;

  static Future<_VoiceSightingFixture> load() async {
    final contents = await rootBundle.loadString(
      'assets/fixtures/voice-relay-sighting.json',
    );
    final json = jsonDecode(contents) as Map<String, dynamic>;
    return _VoiceSightingFixture(
      clientSubmissionId: json['client_submission_id'] as String,
      knownCaseId: json['known_case_id'] as String,
      kind: json['kind'] as String,
      language: json['language'] as String,
      transcript: json['transcript'] as String,
      englishGloss: json['english_gloss'] as String,
      locationLabel: json['location_label'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
    );
  }
}

class VoiceRelayReport {
  const VoiceRelayReport({
    required this.clientSubmissionId,
    required this.knownCaseId,
    required this.kind,
    required this.language,
    required this.transcript,
    required this.locationLabel,
    required this.capturedAt,
    required this.audioLocalPath,
    required this.status,
    required this.consentConfirmed,
  });

  final String clientSubmissionId;
  final String? knownCaseId;
  final String kind;
  final String language;
  final String transcript;
  final String locationLabel;
  final DateTime capturedAt;
  final String? audioLocalPath;
  final String status;
  final bool consentConfirmed;

  Map<String, dynamic> toJson() {
    return {
      'client_submission_id': clientSubmissionId,
      'known_case_id': knownCaseId,
      'kind': kind,
      'language': language,
      'transcript': transcript,
      'location_label': locationLabel,
      'captured_at': capturedAt.toIso8601String(),
      'audio_local_path': audioLocalPath,
      'status': status,
      'consent_confirmed': consentConfirmed,
    };
  }

  factory VoiceRelayReport.fromJson(Map<String, dynamic> json) {
    return VoiceRelayReport(
      clientSubmissionId: json['client_submission_id'] as String,
      knownCaseId: json['known_case_id'] as String?,
      kind: json['kind'] as String,
      language: json['language'] as String,
      transcript: json['transcript'] as String,
      locationLabel: json['location_label'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
      audioLocalPath: json['audio_local_path'] as String?,
      status: json['status'] as String,
      consentConfirmed: json['consent_confirmed'] as bool,
    );
  }
}

class LocalOutboxStore {
  static const _storageKey = 'ravencry_voice_relay_outbox';

  Future<List<VoiceRelayReport>> loadReports() async {
    final preferences = await SharedPreferences.getInstance();
    final storedReports = preferences.getString(_storageKey);
    if (storedReports == null) {
      return [];
    }

    final decodedReports = jsonDecode(storedReports) as List<dynamic>;
    return decodedReports
        .map(
          (report) => VoiceRelayReport.fromJson(report as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> queue(VoiceRelayReport report) async {
    final reports = await loadReports();
    reports.removeWhere(
      (savedReport) =>
          savedReport.clientSubmissionId == report.clientSubmissionId,
    );
    reports.insert(0, report);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(reports.map((savedReport) => savedReport.toJson()).toList()),
    );
  }
}

class SubmissionResult {
  const SubmissionResult({
    required this.status,
    required this.caseReference,
    required this.message,
  });

  final String status;
  final String caseReference;
  final String message;
}

abstract class VoiceRelaySubmissionAdapter {
  Future<SubmissionResult> submit(VoiceRelayReport report);
}

class LocalOnlySubmissionAdapter implements VoiceRelaySubmissionAdapter {
  const LocalOnlySubmissionAdapter();

  @override
  Future<SubmissionResult> submit(VoiceRelayReport report) async {
    return const SubmissionResult(
      status: 'queued_for_human_review',
      caseReference: 'DEMO-VOICE-001',
      message:
          'Saved for human review. This demo has not contacted emergency services.',
    );
  }
}

class _OutboxPage extends StatefulWidget {
  const _OutboxPage({this.showQueuedConfirmation = false});

  final bool showQueuedConfirmation;

  @override
  State<_OutboxPage> createState() => _OutboxPageState();
}

class _OutboxPageState extends State<_OutboxPage> {
  late final Future<List<VoiceRelayReport>> _reports;
  final VoiceRelaySubmissionAdapter _submissionAdapter =
      const LocalOnlySubmissionAdapter();
  SubmissionResult? _submissionResult;
  String? _submittedReportId;
  String? _submittingReportId;

  @override
  void initState() {
    super.initState();
    _reports = LocalOutboxStore().loadReports();
  }

  Future<void> _trySending(VoiceRelayReport report) async {
    if (_submittingReportId != null) {
      return;
    }

    setState(() {
      _submittingReportId = report.clientSubmissionId;
      _submissionResult = null;
      _submittedReportId = null;
    });

    final result = await _submissionAdapter.submit(report);
    if (!mounted) {
      return;
    }
    setState(() {
      _submittingReportId = null;
      _submissionResult = result;
      _submittedReportId = report.clientSubmissionId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: RelayColors.background,
        foregroundColor: RelayColors.foreground,
        title: const Text('Outbox'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<VoiceRelayReport>>(
          future: _reports,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final reports = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _OfflineBadge(),
                const SizedBox(height: 28),
                const Text(
                  'Local outbox',
                  style: TextStyle(
                    color: RelayColors.foreground,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reports remain on this device until they are queued for human review.',
                  style: TextStyle(color: RelayColors.muted, fontSize: 16),
                ),
                if (widget.showQueuedConfirmation) ...[
                  const SizedBox(height: 20),
                  const _InformationCard(
                    icon: Icons.check_circle_outline,
                    iconColor: RelayColors.green,
                    title: 'Queued locally for human review',
                    message: 'This report has not been sent or delivered.',
                  ),
                ],
                const SizedBox(height: 20),
                if (reports.isEmpty)
                  const _InformationCard(
                    icon: Icons.inbox_outlined,
                    title: 'No queued reports',
                    message:
                        'Completed reports will appear here while offline.',
                  )
                else
                  ...reports.map(
                    (report) => _OutboxReportCard(
                      report: report,
                      isSubmitting:
                          _submittingReportId == report.clientSubmissionId,
                      submissionResult:
                          _submittedReportId == report.clientSubmissionId
                          ? _submissionResult
                          : null,
                      onTrySending: () => _trySending(report),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OutboxReportCard extends StatelessWidget {
  const _OutboxReportCard({
    required this.report,
    required this.isSubmitting,
    required this.submissionResult,
    required this.onTrySending,
  });

  final VoiceRelayReport report;
  final bool isSubmitting;
  final SubmissionResult? submissionResult;
  final VoidCallback onTrySending;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RelayColors.card,
        border: Border.all(color: RelayColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_outlined, color: RelayColors.amber),
              SizedBox(width: 8),
              Text(
                'Queued for human review',
                style: TextStyle(
                  color: RelayColors.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            report.locationLabel,
            style: const TextStyle(
              color: RelayColors.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${report.language.toUpperCase()} · ${report.kind} · ${report.audioLocalPath == null ? 'Text response' : 'Local audio'}',
            style: const TextStyle(color: RelayColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            'Case ${report.knownCaseId ?? 'Unlinked'} · ${_formatOutboxTime(report.capturedAt)}',
            style: const TextStyle(color: RelayColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: Key('try-sending-${report.clientSubmissionId}'),
            onPressed: isSubmitting ? null : onTrySending,
            icon: const Icon(Icons.upload_outlined),
            label: Text(
              isSubmitting
                  ? 'Checking local demo…'
                  : 'Try sending (local demo)',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: RelayColors.foreground,
              side: const BorderSide(color: RelayColors.border),
            ),
          ),
          if (submissionResult != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RelayColors.background,
                border: Border.all(color: RelayColors.green),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Queued for human review',
                    style: TextStyle(
                      color: RelayColors.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    submissionResult!.caseReference,
                    style: const TextStyle(
                      color: RelayColors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Status: ${submissionResult!.status}',
                    style: const TextStyle(
                      color: RelayColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    submissionResult!.message,
                    style: const TextStyle(
                      color: RelayColors.muted,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatOutboxTime(DateTime capturedAt) {
  final watTime = capturedAt.toUtc().add(const Duration(hours: 1));
  final hour = watTime.hour.toString().padLeft(2, '0');
  final minute = watTime.minute.toString().padLeft(2, '0');
  return '${watTime.day}/${watTime.month}/${watTime.year} $hour:$minute WAT';
}

class _Header extends StatelessWidget {
  const _Header({this.onOutbox});

  final VoidCallback? onOutbox;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RelayColors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.graphic_eq, color: RelayColors.foreground),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RAVENCRY',
                style: TextStyle(
                  color: RelayColors.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Voice Relay',
                style: TextStyle(color: RelayColors.muted, fontSize: 16),
              ),
            ],
          ),
        ),
        if (onOutbox != null)
          IconButton(
            key: const Key('open-outbox'),
            onPressed: onOutbox,
            icon: const Icon(Icons.inbox_outlined),
            color: RelayColors.foreground,
            tooltip: 'Open outbox',
          ),
        const _OfflineBadge(),
      ],
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: RelayColors.card,
        border: Border.all(color: RelayColors.green),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: RelayColors.green, size: 18),
          SizedBox(width: 6),
          Text(
            'Offline',
            style: TextStyle(
              color: RelayColors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

  @override
  Widget build(BuildContext context) {
    return const _InformationCard(
      icon: Icons.phone_android_outlined,
      title: 'Ready to save a report offline',
      message:
          'You can prepare a report without a connection. It will be queued for human review.',
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return const _InformationCard(
      icon: Icons.warning_amber_rounded,
      iconColor: RelayColors.amber,
      title: 'Immediate danger',
      message: 'If you are in immediate danger, call 112.',
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor = RelayColors.foreground,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RelayColors.card,
        border: Border.all(color: RelayColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RelayColors.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: RelayColors.muted,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
