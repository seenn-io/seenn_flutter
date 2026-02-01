import 'package:flutter/material.dart';
import 'package:seenn_flutter/seenn_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Seenn SDK with development config
  await Seenn.init(
    apiKey: 'pk_test_xxx',
    userId: 'test_user',
    config: SeennConfig.development(
      apiUrl: 'http://localhost:3001',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seenn Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const JobListPage(),
    );
  }
}

class JobListPage extends StatelessWidget {
  const JobListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seenn Jobs'),
        actions: [
          // Connection indicator
          StreamBuilder<SeennConnectionState>(
            stream: Seenn.instance.connectionState$,
            builder: (context, snapshot) {
              final state = snapshot.data ?? SeennConnectionState.disconnected;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  state.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: state.isConnected ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<Map<String, SeennJob>>(
        stream: Seenn.instance.jobs.all$,
        builder: (context, snapshot) {
          final jobs = snapshot.data?.values.toList() ?? [];

          return Column(
            children: [
              // Live Activity Test Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: LiveActivityTestWidget(),
              ),
              const Divider(),
              // Jobs List
              Expanded(
                child: jobs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No jobs yet'),
                            SizedBox(height: 8),
                            Text(
                              'Start a job from your backend to see it here',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          return JobCard(job: job);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  final SeennJob job;

  const JobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _buildStatusChip(job.status),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            if (!job.isTerminal) ...[
              LinearProgressIndicator(
                value: job.progress / 100,
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(height: 4),
              Text(
                '${job.progress}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            // Message
            if (job.message != null) ...[
              const SizedBox(height: 8),
              Text(
                job.message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],

            // Stage info
            if (job.stage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Stage ${job.stage!.index + 1}/${job.stage!.total}: ${job.stage!.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            // ETA
            if (job.eta != null && !job.isTerminal) ...[
              const SizedBox(height: 4),
              Text(
                'ETA: ${_formatEta(job.eta!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            // Result
            if (job.status == JobStatus.completed && job.resultUrl != null) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // Open result URL
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Result: ${job.resultUrl}')),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ],

            // Error
            if (job.status == JobStatus.failed && job.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(JobStatus status) {
    Color color;
    String label;

    switch (status) {
      case JobStatus.pending:
        color = Colors.grey;
        label = 'Pending';
        break;
      case JobStatus.queued:
        color = Colors.orange;
        label = 'Queued';
        break;
      case JobStatus.running:
        color = Colors.blue;
        label = 'Running';
        break;
      case JobStatus.completed:
        color = Colors.green;
        label = 'Completed';
        break;
      case JobStatus.failed:
        color = Colors.red;
        label = 'Failed';
        break;
      case JobStatus.cancelled:
        color = Colors.grey;
        label = 'Cancelled';
        break;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatEta(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}

// Live Activity Test Widget
class LiveActivityTestWidget extends StatefulWidget {
  const LiveActivityTestWidget({super.key});

  @override
  State<LiveActivityTestWidget> createState() => _LiveActivityTestWidgetState();
}

class _LiveActivityTestWidgetState extends State<LiveActivityTestWidget> {
  bool _isSupported = false;
  bool _isEnabled = false;
  bool _isRunning = false;
  int _progress = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final supported = await Seenn.instance.liveActivity.isSupported();
    final enabled = await Seenn.instance.liveActivity.areActivitiesEnabled();
    setState(() {
      _isSupported = supported;
      _isEnabled = enabled;
      _status = supported
          ? (enabled ? 'Ready' : 'Disabled in Settings')
          : 'Not supported (iOS 16.2+ required)';
    });
  }

  Future<void> _startDemo() async {
    setState(() {
      _isRunning = true;
      _progress = 0;
      _status = 'Starting...';
    });

    // Start Live Activity
    final result = await Seenn.instance.liveActivity.startActivity(
      jobId: 'demo_job_${DateTime.now().millisecondsSinceEpoch}',
      title: 'AI Video Generation',
      jobType: 'video',
      initialProgress: 0,
      initialMessage: 'Initializing...',
    );

    if (!result.success) {
      setState(() {
        _status = 'Failed: ${result.error}';
        _isRunning = false;
      });
      return;
    }

    setState(() => _status = 'Running - check Dynamic Island!');

    // Simulate progress
    for (int i = 10; i <= 100; i += 10) {
      await Future.delayed(const Duration(seconds: 2));
      if (!_isRunning) break;

      setState(() => _progress = i);

      if (i < 100) {
        await Seenn.instance.liveActivity.updateActivity(
          jobId: result.jobId!,
          progress: i,
          status: 'running',
          message: _getMessageForProgress(i),
          stageName: _getStageForProgress(i),
          stageIndex: (i ~/ 25),
          stageTotal: 4,
          eta: ((100 - i) * 2),
        );
      } else {
        // Complete
        await Seenn.instance.liveActivity.endActivity(
          jobId: result.jobId!,
          finalProgress: 100,
          finalStatus: 'completed',
          message: 'Video ready!',
          resultUrl: 'https://example.com/video.mp4',
        );
      }
    }

    setState(() {
      _isRunning = false;
      _status = 'Completed!';
    });
  }

  String _getMessageForProgress(int progress) {
    if (progress < 25) return 'Analyzing prompt...';
    if (progress < 50) return 'Generating frames...';
    if (progress < 75) return 'Rendering video...';
    return 'Finalizing...';
  }

  String _getStageForProgress(int progress) {
    if (progress < 25) return 'Analysis';
    if (progress < 50) return 'Generation';
    if (progress < 75) return 'Rendering';
    return 'Finalization';
  }

  Future<void> _stopDemo() async {
    setState(() => _isRunning = false);
    await Seenn.instance.liveActivity.cancelAllActivities();
    setState(() => _status = 'Cancelled');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_iphone, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Live Activity Demo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Status: $_status',
              style: TextStyle(
                color: _isEnabled ? Colors.green : Colors.orange,
              ),
            ),
            if (_isRunning) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress / 100),
              Text('$_progress%'),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (_isSupported && _isEnabled && !_isRunning)
                      ? _startDemo
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Demo'),
                ),
                const SizedBox(width: 8),
                if (_isRunning)
                  OutlinedButton.icon(
                    onPressed: _stopDemo,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
